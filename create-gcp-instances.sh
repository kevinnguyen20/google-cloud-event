#!/bin/bash

# SSH key, output file id_rsa, username as comment
SSH_KEY_FILE="$HOME/.ssh/id_rsa"
SSH_USER="gcp-user"

echo "[+] Generating SSH key..."
if [ ! -f "$SSH_KEY_FILE" ]; then
  ssh-keygen -t rsa -f "$SSH_KEY_FILE" -C "$SSH_USER" -b 4096 -q -N ""
fi

# Prepare the public key as per GCP requirements
PUBLIC_KEY=$(cat "${SSH_KEY_FILE}.pub")
MODIFIED_KEY="$SSH_USER:$PUBLIC_KEY"

# Upload new modified public key (project-wide)
echo "[+] Uploading modified SSH key..."
gcloud compute project-info add-metadata --metadata ssh-keys="$MODIFIED_KEY"

# Create a firewall rule for incoming ICMP and SSH traffic
echo "[+] Creating firewall rule for incoming ICMP and SSH..."
gcloud compute firewall-rules create "cc-firewall" \
  --direction=IN \
  --action=ALLOW \
  --rules=icmp,tcp:22 \
  --target-tags=cc

# List of machine types
MACHINE_TYPES=("n1-standard-4" "n2-standard-4" "c3-standard-4")

# Create VM instances, 10GB disk size, tag cc, nested virtualization enabled, 
for i in ${!MACHINE_TYPES[@]}; do
  echo "[+] Creating VM instance $i: ${MACHINE_TYPES[$i]}"
  gcloud compute instances create vm-$i \
    --machine-type ${MACHINE_TYPES[$i]} \
    --zone europe-west4-a \
    --image-family ubuntu-2204-lts \
    --image-project ubuntu-os-cloud \
    --boot-disk-size 10GB \
    --tags cc \
    --enable-nested-virtualization
done

echo "[+] All VMs have been created and configured."
