#!/bin/bash

# Check if sysbench is installed, if not install it
if ! command -v sysbench &> /dev/null
then
    echo "[+] Sysbench is not installed. Installing..." >&2
    sudo apt update > /dev/null && sudo apt install -y sysbench > /dev/null
fi

# Prepare the timestamp
TIMESTAMP=$(date +%s)

# CPU benchmark
>&2 echo "[+] Running CPU benchmark..."
CPU_RESULT=$(sysbench cpu --time=60 run | grep "events per second:" | awk '{print $4}')
>&2 echo "$CPU_RESULT events/s"

# Memory benchmark, block size 4K, total size 1TB
>&2 echo "[+] Running memory benchmark..."
MEMORY_RESULT=$(sysbench memory --memory-block-size=4K --memory-total-size=100TB --time=60 run | grep "transferred" | awk '{sub(/\(/, "", $4); print $4}')
>&2 echo "$MEMORY_RESULT MiB/s"

# Random-access disk read speed benchmark, 1 file with size 1GB, no caching
>&2 echo "[+] Running random-access disk read speed benchmark..."
PARAMS="--file-total-size=1G --file-test-mode=rndrd --file-extra-flags=direct --file-num=1"
sysbench fileio $PARAMS prepare > /dev/null
RANDOM_ACCESS_RESULT=$(sysbench fileio $PARAMS --time=60 run | grep "read, MiB/s" | awk '{print $3}')
sysbench fileio $PARAMS cleanup > /dev/null
<&2 echo "$RANDOM_ACCESS_RESULT MiB/s"

# Sequential disk read speed benchmark, 1 file with size 1GB, no caching
>&2 echo "[+] Running sequential disk read speed benchmark..."
PARAMS="--file-total-size=1G --file-test-mode=seqrd --file-extra-flags=direct --file-num=1"
sysbench fileio $PARAMS prepare > /dev/null
SEQUENTIAL_ACCESS_RESULT=$(sysbench fileio $PARAMS --time=60 run | grep "read, MiB/s" | awk '{print $3}')
sysbench fileio $PARAMS cleanup > /dev/null
>&2 echo "$SEQUENTIAL_ACCESS_RESULT MiB/s"

echo "$TIMESTAMP, $CPU_RESULT, $MEMORY_RESULT, $RANDOM_ACCESS_RESULT, $SEQUENTIAL_ACCESS_RESULT"
