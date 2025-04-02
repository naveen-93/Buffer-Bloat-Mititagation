#!/usr/bin/env bash

# This script orchestrates comparative network tests using Flent.
# It should be run on the CLIENT machine (macOS, Linux, or Windows via WSL/Git Bash).
# The SERVER/DUT machine must be Linux.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Server/DUT (Device Under Test) Details - THIS MUST BE LINUX
VM_IP="192.168.64.3"             # IP address of the Linux Server/DUT
VM_USER="rovinsingh"              # Username for SSH login to Server/DUT
IFACE="enp0s1"                  # Network interface on Server/DUT to apply qdisc

# Custom Module Details
MODULE_NAME="fqcodel+"          # Name ID of your custom qdisc module
MODULE_PATH="./${MODULE_NAME}.ko" # Path to your .ko file ON THE SERVER/DUT relative to VM_USER's home, or absolute path.
                                # Ensure the .ko file is already present on the Server/DUT at this location.

# Test Parameters
TEST_DURATION="60"              # Flent test duration in seconds (-l)
PFIFO_LIMIT="100"               # The packet limit for pfifo comparison

# Output Configuration (on Client)
OUTPUT_DIR="."                  # Directory on CLIENT to save plots and data files

# --- Helper Functions ---

# Function to execute a command remotely on the Server/DUT via SSH
# Supports checking for specific errors like module not found
# Usage: run_remote "command with sudo" "Error message if fails"
run_remote() {
    local cmd_to_run=$1
    local error_msg=$2
    echo "REMOTE CMD: ${cmd_to_run}"
    # Execute via SSH. Use -t to force pseudo-terminal allocation if sudo requires it without NOPASSWD
    # Remove -t if you have passwordless sudo fully configured.
    if ssh -t "${VM_USER}@${VM_IP}" "${cmd_to_run}"; then
        echo "REMOTE OK: Command successful."
        return 0
    else
        local exit_code=$?
        echo "ERROR: Remote command failed with exit code ${exit_code}."
        echo "ERROR: ${error_msg}"
        # Add more specific error checks if needed
        # ssh "${VM_USER}@${VM_IP}" "ls -l ${MODULE_PATH}" || echo "CHECK: Module file existence check failed."
        exit ${exit_code}
    fi
}

# Function to set Qdisc on the remote VM via SSH
# $1: Qdisc type ('fqcodel+', 'fq_codel', 'pfifo', 'default')
# $2: Optional limit for pfifo
set_qdisc() {
    local qdisc_type=$1
    local limit=$2
    local tc_cmd_del="sudo tc qdisc del dev ${IFACE} root"
    local tc_cmd_add

    echo "-----------------------------------------------------"
    echo "INFO: Setting qdisc to '$qdisc_type' on ${VM_IP}:${IFACE}..."

    # Delete existing root qdisc first (ignore errors if it doesn't exist)
    run_remote "${tc_cmd_del}" "Failed to delete existing qdisc (might be okay if none exists)." || true

    # Construct tc add command based on type
    if [[ "$qdisc_type" == "default" ]]; then
        echo "INFO: Qdisc set to default (by deleting root)."
        return 0 # Nothing more to do for default
    elif [[ "$qdisc_type" == "pfifo" ]]; then
        if [[ -z "$limit" ]]; then
            echo "ERROR: Limit must be provided for pfifo."
            exit 1
        fi
        tc_cmd_add="sudo tc qdisc add dev ${IFACE} root pfifo limit ${limit}"
    elif [[ "$qdisc_type" == "fq_codel" ]]; then
        tc_cmd_add="sudo tc qdisc add dev ${IFACE} root fq_codel"
     elif [[ "$qdisc_type" == "$MODULE_NAME" ]]; then
        # Ensure module is loaded
        run_remote "sudo insmod ${MODULE_PATH}" "Failed to load module ${MODULE_NAME}. Ensure ${MODULE_PATH} exists on server and user ${VM_USER} has sudo rights for insmod/rmmod."
        tc_cmd_add="sudo tc qdisc add dev ${IFACE} root ${MODULE_NAME}"
    else
        echo "ERROR: Unknown qdisc type '$qdisc_type'"
        exit 1
    fi

    # Execute the add command
    run_remote "${tc_cmd_add}" "Failed to add qdisc '$qdisc_type'."

    # Verify (optional but recommended)
    run_remote "tc qdisc show dev ${IFACE}" "Failed to verify qdisc after setting."
    echo "INFO: Successfully set qdisc to '$qdisc_type'."
}

# Function to run a single flent test (runs on Client)
# $1: Test label/title
# $2: Output filename base (without extension)
run_flent_test() {
    local test_title=$1
    local output_base=$2
    local output_png="${OUTPUT_DIR}/${output_base}.png"
    # Flent adds .flent.gz automatically to the name given to -o if .png is specified
    local output_data_expected="${OUTPUT_DIR}/${output_base}.flent.gz"

    echo "-----------------------------------------------------"
    echo "INFO: Running Flent RRUL test from Client: ${test_title}"
    echo "INFO: Target Server/DUT: ${VM_IP}"
    echo "INFO: Output plot (on Client): ${output_png}"
    echo "-----------------------------------------------------"

    # Activate venv if needed (assuming user activates before running script, or adjust here)
    # source ./venv/bin/activate

    flent rrul -p all_scaled -l "$TEST_DURATION" -H "$VM_IP" -t "$test_title" -o "$output_png"

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Flent test failed for '${test_title}'."
        # Optionally exit, or continue with other tests
        # exit 1
    else
        echo "INFO: Flent test '${test_title}' completed."
        # Check if data file was created
        if [[ -f "$output_data_expected" ]]; then
             echo "INFO: Data file saved: ${output_data_expected}"
        else
             echo "WARN: Expected data file ${output_data_expected} not found."
        fi
    fi
    echo "INFO: Pausing for 5 seconds before next test..."
    sleep 5
}

# --- Main Script Logic ---

echo "Starting Comparative Flent Tests..."
echo "Client OS: $(uname -a)" # Basic client info
echo "Server/DUT Host: ${VM_IP}"
echo "Server/DUT Interface: ${IFACE}"
echo "Test Duration: ${TEST_DURATION}s"
echo "Make sure prerequisites are met (see README.md):"
echo "  - Bash, SSH Client, Python3, Flent installed on this Client machine."
echo "  - SSH keys configured for passwordless access to ${VM_USER}@${VM_IP}."
echo "  - ${VM_USER} has passwordless sudo for 'tc', 'insmod', 'rmmod' on ${VM_IP}."
echo "  - Module ${MODULE_PATH} exists on ${VM_IP}."
echo "Output directory (on Client): ${OUTPUT_DIR}"
echo "-----------------------------------------------------"
read -p "Press Enter to continue..." -r

# Create output dir if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# 1. Test Custom Module
set_qdisc "$MODULE_NAME"
run_flent_test "My_${MODULE_NAME}" "rrul_${MODULE_NAME}"

# 2. Test Kernel FQ-CoDel
set_qdisc "fq_codel"
run_flent_test "Kernel_FQ_CoDel" "rrul_kernel_fq_codel"

# 3. Test PFIFO with Limit
set_qdisc "pfifo" "$PFIFO_LIMIT"
run_flent_test "PFIFO_Limit_${PFIFO_LIMIT}" "rrul_pfifo_${PFIFO_LIMIT}"

# 4. Test Default Qdisc
set_qdisc "default"
run_flent_test "Default_Qdisc" "rrul_default"

# --- Cleanup ---
echo "-----------------------------------------------------"
echo "INFO: Attempting to reset qdisc on Server/DUT interface to default..."
set_qdisc "default" # This just deletes the root qdisc
echo "INFO: Unloading custom module (ignore errors if not loaded)..."
run_remote "sudo rmmod ${MODULE_NAME}.ko" "Failed to unload module (might be okay if not loaded or in use)." || true
echo "INFO: Testing complete."
echo "Plots and data saved in (on Client): ${OUTPUT_DIR}"
echo "-----------------------------------------------------"

exit 0