#!/bin/bash
# Script to remove the fq_codel_plus qdisc and unload the module

echo "=== Removing fqcodel+ qdisc from enp2s0 ==="
sudo tc qdisc del dev enp2s0 root
if [ $? -ne 0 ]; then
    echo "WARNING: Failed to remove qdisc from interface!"
    echo "Continuing with module removal..."
else
    echo "Successfully removed qdisc."
fi

echo "=== Unloading fq_codel_plus kernel module ==="
sudo rmmod fq_codel_plus
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to unload kernel module!"
    exit 1
fi
echo "Module unloaded successfully."

