#!/bin/bash

# Check if QEMU is installed, if not install it
if ! command -v qemu-kvm &> /dev/null
then
    echo '[+] Installing QEMU...'
    sudo apt update > /dev/null && sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq qemu-kvm libvirt-daemon-system qemu-utils virtinst genisoimage > /dev/null
else
    echo '[+] QEMU is already installed.'
fi

# Pull QEMU and QEMU with KVM images
echo '[+] Downloading images...'
wget http://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-disk-kvm.img

# Create directory for base images
sudo mkdir /var/lib/libvirt/images/base

# Change file extensions
echo '[+] Changing file extensions...'
sudo mv jammy-server-cloudimg-amd64.img /var/lib/libvirt/images/base/ubuntu-2204.qcow2
sudo mv jammy-server-cloudimg-amd64-disk-kvm.img /var/lib/libvirt/images/base/ubuntu-2204-kvm.qcow2

# Create directory for instance images
sudo mkdir /var/lib/libvirt/images/instance

# Create disk images based on Ubuntu images
echo '[+] Creating disk images from Ubuntu images...'
sudo qemu-img create -f qcow2 -F qcow2 -o backing_file=/var/lib/libvirt/images/base/ubuntu-2204.qcow2 /var/lib/libvirt/images/instance/ubuntu-disk-image.qcow2
sudo qemu-img create -f qcow2 -F qcow2 -o backing_file=/var/lib/libvirt/images/base/ubuntu-2204-kvm.qcow2 /var/lib/libvirt/images/instance/ubuntu-kvm-disk-image.qcow2

# Resize virtual size
echo '[+] Resizing virtual size...'
sudo qemu-img resize /var/lib/libvirt/images/instance/ubuntu-disk-image.qcow2 20G
sudo qemu-img resize /var/lib/libvirt/images/instance/ubuntu-kvm-disk-image.qcow2 20G

# Create SSH key for QEMU VM instances
echo '[+] Generating SSH key...'
ssh-keygen -t rsa -f "$HOME/.ssh/id_rsa" -C ubuntu -b 4096 -q -N ""

PUBLIC_KEY=$(cat "$HOME/.ssh/id_rsa.pub")

# Create user-data for cloud-init
cat >user-data <<EOF
#cloud-config
users:
  - name: ubuntu
    ssh-authorized-keys:
      - $PUBLIC_KEY
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
runcmd:
  - echo 'AllowUsers ubuntu' >> /etc/ssh/sshd_config
  - restart ssh
EOF

# Create a sources.list for docker image to avoid slowdowns in the container using default apt sources
echo "[+] Creating sources.list for docker image"
cat > sources.list <<EOF
deb http://de.archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://de.archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://de.archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb http://de.archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
EOF

# Create QEMU VM instances
sudo virt-install \
  --connect qemu:///system \
  --virt-type qemu \
  --name vm-user \
  --memory 4096 \
  --vcpus $(nproc --all) \
  --os-variant ubuntu22.04 \
  --disk path=/var/lib/libvirt/images/instance/ubuntu-disk-image.qcow2,format=qcow2,device=disk,bus=virtio \
  --cloud-init user-data=user-data \
  --import \
  --network default \
  --noautoconsole

sudo virt-install \
  --connect qemu:///system \
  --virt-type kvm \
  --name vm-user-kvm \
  --memory 4096 \
  --vcpus $(nproc --all) \
  --os-variant ubuntu22.04 \
  --disk path=/var/lib/libvirt/images/instance/ubuntu-kvm-disk-image.qcow2,format=qcow2,device=disk,bus=virtio \
  --cloud-init user-data=user-data \
  --import \
  --network default \
  --noautoconsole

# Copy benchmark script to VMs after they are up
# wait for the VM's IP being available through libvirt and then retry until SCP succeeds
# (SSHd availability takes longer than IP availability)
echo "[+] Waiting for KVM VM to be online and copying benchmark script to VM"
while [[ -z $(sudo virsh domifaddr cc-para | sed -nr '/ipv4/s/.* +(.+)\/24/\1/p') ]]; do
  sleep 2
done
ip_para=$(sudo virsh domifaddr cc-para | sed -nr '/ipv4/s/.* +(.+)\/24/\1/p')
while ! scp -o StrictHostKeyChecking=no -i id_ed25519 benchmark.sh ubuntu@$ip_para: 2> /dev/null; do echo -n "."; sleep 5; done && echo "-> ok"

echo "[+] Waiting for QEMU VM to be online and copying benchmark script to VM"
while [[ -z $(sudo virsh domifaddr cc-full | sed -nr '/ipv4/s/.* +(.+)\/24/\1/p') ]]; do
  sleep 2
done
ip_full=$(sudo virsh domifaddr cc-full | sed -nr '/ipv4/s/.* +(.+)\/24/\1/p')
while ! scp -o StrictHostKeyChecking=no -i id_ed25519 benchmark.sh ubuntu@$ip_full: 2> /dev/null; do echo -n "."; sleep 5; done && echo "-> ok"

# Add the experiment execution script to the user's crontab and restart cron service for safe measure
echo "-> Adding experiment execution script to crontab"
(crontab -l || true; echo "*/30 * * * * ./execute-experiments.sh") | crontab -
sudo systemctl restart cron.service
