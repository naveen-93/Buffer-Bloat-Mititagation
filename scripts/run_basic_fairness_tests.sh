#!/usr/bin/env bash

# This script helps run basic iperf3 tests (single and parallel flows)
# against the custom kernel module on a remote Linux Server/DUT.
# It requires MANUAL observation of monitoring tools on the Server/DUT.
# Run this script from the CLIENT machine (macOS, Linux, or Windows via WSL/Git Bash).

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
TEST_DURATION="30"              # iperf3 test duration in seconds (-t)
P_FAIRNESS="5"                  # Number of parallel streams for fairness test (-P)

# --- Global Vars ---
IPERF_SERVER_PID="" # Stores PID of remote iperf3 server

# --- Helper Functions ---

# Function to execute a synchronous command remotely on the Server/DUT via SSH
run_remote_sync() {
    local cmd_to_run=$1
    local error_msg=$2
    echo "REMOTE SYNC CMD: ${cmd_to_run}"
    # Use -t for sudo if needed, remove if passwordless sudo is fully set up
    if ssh -t "${VM_USER}@${VM_IP}" "${cmd_to_run}"; then
        echo "REMOTE SYNC OK: Command successful."
        return 0
    else
        local exit_code=$?
        echo "ERROR: Remote SYNC command failed with exit code ${exit_code}."
        echo "ERROR: ${error_msg}"
        exit ${exit_code}
    fi
}

# Function to start a background command remotely and store its PID
start_remote_bg() {
    local cmd_to_run=$1
    local error_msg=$2
    local pid_var_name=$3 # Name of the global variable to store the PID

    echo "REMOTE BG CMD: nohup ${cmd_to_run} > /dev/null 2>&1 & echo \$!"
    # Execute, capture PID. Redirect output to avoid clutter/hangs.
    local pid
    pid=$(ssh "${VM_USER}@${VM_IP}" "nohup ${cmd_to_run} > /dev/null 2>&1 & echo \$!")
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Failed to start remote BG command (SSH error)."
        echo "ERROR: ${error_msg}"
        exit $exit_code
    fi

    if [[ -z "$pid" || ! "$pid" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Failed to get valid PID for remote BG command."
        echo "ERROR: ${error_msg}"
        # Check if iperf3 server is installed?
        ssh "${VM_USER}@${VM_IP}" "command -v iperf3" || echo "CHECK: iperf3 might not be installed on server."
        exit 1
    fi

    # Store PID in the specified global variable
    printf -v "$pid_var_name" "%s" "$pid"
    echo "REMOTE BG OK: Started '${cmd_to_run}' with PID ${!pid_var_name}"
}

# Function to kill a remote process by PID
kill_remote_pid() {
    local pid_to_kill=$1
    if [[ -z "$pid_to_kill" ]]; then
        echo "WARN: No PID provided to kill_remote_pid."
        return 0
    fi

    echo "REMOTE KILL CMD: kill ${pid_to_kill}"
    # Try graceful kill first, ignore errors (process might already be dead)
    ssh "${VM_USER}@${VM_IP}" "kill ${pid_to_kill}" || true
    sleep 1 # Give it a moment
    # Check if it's still running, force kill if needed
    if ssh "${VM_USER}@${VM_IP}" "ps -p ${pid_to_kill} > /dev/null"; then
       echo "REMOTE KILL CMD: Process ${pid_to_kill} still running, trying kill -9"
       ssh "${VM_USER}@${VM_IP}" "kill -9 ${pid_to_kill}" || true
    fi
     echo "REMOTE KILL OK: Attempted to kill PID ${pid_to_kill}."
}

# Function to apply the custom Qdisc
apply_custom_qdisc() {
     echo "-----------------------------------------------------"
     echo "INFO: Applying custom qdisc '${MODULE_NAME}' on ${VM_IP}:${IFACE}..."
     run_remote_sync "sudo tc qdisc del dev ${IFACE} root" "Failed to delete existing qdisc (might be okay)." || true
     run_remote_sync "sudo insmod ${MODULE_PATH}" "Failed to load module ${MODULE_NAME}. Ensure ${MODULE_PATH} exists on server and user ${VM_USER} has sudo rights."
     run_remote_sync "sudo tc qdisc add dev ${IFACE} root ${MODULE_NAME}" "Failed to add custom qdisc '${MODULE_NAME}'."
     run_remote_sync "tc qdisc show dev ${IFACE}" "Failed to verify qdisc after setting."
     echo "INFO: Custom qdisc applied."
}

# Function to perform cleanup on the Server/DUT
cleanup_server() {
    echo "-----------------------------------------------------"
    echo "INFO: Cleaning up on Server/DUT (${VM_IP})..."
    if [[ -n "$IPERF_SERVER_PID" ]]; then
        kill_remote_pid "$IPERF_SERVER_PID"
        IPERF_SERVER_PID="" # Clear PID after attempting kill
    else
        echo "INFO: No iperf3 server PID to kill."
    fi
    echo "INFO: Removing root qdisc..."
    run_remote_sync "sudo tc qdisc del dev ${IFACE} root" "Failed to delete qdisc during cleanup (might be okay)." || true
    echo "INFO: Unloading custom module..."
    run_remote_sync "sudo rmmod ${MODULE_NAME}.ko" "Failed to unload module (might be okay if not loaded/in use)." || true
    echo "INFO: Cleanup complete."
    echo "-----------------------------------------------------"
}

# --- Main Script Logic ---

# Setup trap to ensure cleanup runs even if script is interrupted (e.g., Ctrl+C)
trap cleanup_server EXIT SIGINT SIGTERM

echo "Starting Basic Verification & Fairness Tests..."
echo "Client OS: $(uname -a)"
echo "Server/DUT Host: ${VM_IP}"
echo "Server/DUT Interface: ${IFACE}"
echo "Test Duration: ${TEST_DURATION}s"
echo "Make sure prerequisites are met (see README.md):"
echo "  - Bash, SSH Client, iperf3 installed on this Client machine."
echo "  - SSH keys configured for passwordless access to ${VM_USER}@${VM_IP}."
echo "  - ${VM_USER} has passwordless sudo for 'tc', 'insmod', 'rmmod' on ${VM_IP}."
echo "  - Module ${MODULE_PATH} exists on ${VM_IP}."
echo "  - iperf3 installed on ${VM_IP}."
echo "-----------------------------------------------------"
read -p "Press Enter to continue..." -r

# 1. Setup Server Environment
apply_custom_qdisc
echo "INFO: Starting iperf3 server in background on ${VM_IP}..."
start_remote_bg "iperf3 -s" "Failed to start iperf3 server." "IPERF_SERVER_PID"
echo "INFO: iperf3 server started with PID $IPERF_SERVER_PID on ${VM_IP}."
sleep 2 # Give server a moment to fully start

# 2. Basic Verification Test (Single Flow)
echo "-----------------------------------------------------"
echo "--- Basic Verification Test (Single Flow) ---"
echo "ACTION REQUIRED:"
echo "1. Open a NEW terminal/SSH session to ${VM_IP}."
echo "2. Run: sudo dmesg -w"
echo "   (Look for 'Packet enqueued/dequeued/dropped' messages from '${MODULE_NAME}')"
echo "3. Open ANOTHER new terminal/SSH session to ${VM_IP}."
echo "4. Run: watch -n 0.1 sudo tc -s qdisc show dev ${IFACE}"
echo "   (Look for changes in 'backlog', 'qlen', and 'drops' counters)"
echo "-----------------------------------------------------"
read -p "Press Enter WHEN YOU ARE MONITORING to start the iperf3 client..." -r

echo "INFO: Running iperf3 client (1 stream) for ${TEST_DURATION}s..."
iperf3 -c "$VM_IP" -t "$TEST_DURATION" -P 1

echo "-----------------------------------------------------"
echo "INFO: iperf3 client finished."
echo "ACTION REQUIRED: Observe the final state in your monitoring terminals."
echo "  - Did 'qlen' in 'tc' output increase significantly or hit a limit?"
echo "  - Did the 'drops' counter in 'tc' output increase?"
echo "  - Did you see 'Packet dropped' messages in 'dmesg'?"
read -p "Press Enter to continue to the Fairness Test..." -r

# 3. Fairness Test (Multiple Flows)
echo "-----------------------------------------------------"
echo "--- Fairness Test (${P_FAIRNESS} Flows) ---"
echo "ACTION REQUIRED: Continue monitoring 'dmesg' and 'watch tc' outputs."
echo "  (These tools should still be running in your other terminals)"
echo "-----------------------------------------------------"
read -p "Press Enter WHEN READY to start the iperf3 client (${P_FAIRNESS} streams)..." -r

echo "INFO: Running iperf3 client (${P_FAIRNESS} streams) for ${TEST_DURATION}s..."
iperf3 -c "$VM_IP" -t "$TEST_DURATION" -P "$P_FAIRNESS"

echo "-----------------------------------------------------"
echo "INFO: iperf3 client finished."
echo "ACTION REQUIRED: Observe the final state and the iperf3 summary."
echo "  - Compare the final 'Bitrate' for each individual stream ID in the iperf3 output above."
echo "  - Did the queue behavior change in 'tc' or 'dmesg' with more flows?"
read -p "Press Enter to finish and clean up..." -r

# 4. Cleanup is handled by the trap function upon exit

echo "Script finished."
exit 0