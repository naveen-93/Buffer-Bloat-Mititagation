#!/bin/bash
# Script to build and load the fq_codel_plus kernel module

echo "=== Building fq_codel_plus module ==="
cd src
make clean
echo "Cleaned previous build files."

echo "Compiling module..."
make
if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed!"
    exit 1
fi
echo "Module compiled successfully."

echo "=== Loading fq_codel_plus module ==="
sudo insmod fq_codel_plus.ko
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to load kernel module!"
    exit 1
fi
echo "Module loaded successfully."

echo "=== Applying fqcodel+ qdisc to enp2s0 ==="
sudo tc qdisc add dev enp2s0 root fqcodel+
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to apply qdisc to interface!"
    echo "Removing module..."
    sudo rmmod fq_codel_plus
    exit 1
fi
echo "Successfully applied fqcodel+ qdisc to enp2s0."

cd ..

