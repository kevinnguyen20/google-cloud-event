#!/bin/bash

# Get machine type from GCP metadata endpoint to name the result file properly
echo "[+] Getting machine type from GCP metadata endpoint"
machine_type=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/machine-type | sed -nr 's/.*machineTypes\/(.+)-.+-.+/\1/p')

# Create results directory if it does not exist
echo "-> Creating results directory"
results_dir="$HOME/results"
mkdir -p "$results_dir"

# Prepare 4 result files by writing a CSV header if they do not exist
echo "-> Preparing result files"
experiment_types=(native docker kvm qemu)
for experiment_type in ${experiment_types[@]}; do
  file_name=$machine_type-$experiment_type-results.csv
  [[ -f "$results_dir/$file_name" ]] || echo "time,cpu,mem,diskRand,diskSeq" > "$results_dir/$file_name"
done

# Run native benchmarks and append results to the corresponding result file
echo "[+] Running native benchmarks"
benchmark_native=$(./benchmark.sh)
echo $benchmark_native >> "$results_dir/$machine_type-native-results.csv"

# Run docker benchmarks and append results to the corresponding result file
echo "[+] Running docker benchmarks"
benchmark_docker=$(sudo docker run --rm benchmark)
echo $benchmark_docker >> "$results_dir/$machine_type-docker-results.csv"

# Run KVM benchmarks and append results to the corresponding result file
# get IP address of VM, run script over SSH
echo "[+] Running KVM benchmarks"
ip_para=$(sudo virsh domifaddr cc-para | sed -nr '/ipv4/s/.* +(.+)\/24/\1/p')
benchmark_kvm=$(ssh -o StrictHostKeyChecking=no -i id_ed25519 ubuntu@$ip_para ./benchmark.sh)
echo $benchmark_kvm >> "$results_dir/$machine_type-kvm-results.csv"

# Run QEMU benchmarks and append results to the corresponding result file
# get IP address of VM, run script over SSH
echo "[+] Running QEMU benchmarks"
ip_full=$(sudo virsh domifaddr cc-full | sed -nr '/ipv4/s/.* +(.+)\/24/\1/p')
benchmark_full=$(ssh -o StrictHostKeyChecking=no -i id_ed25519 ubuntu@$ip_full ./benchmark.sh)
echo $benchmark_full >> "$results_dir/$machine_type-qemu-results.csv"
