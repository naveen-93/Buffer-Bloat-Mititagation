# Linux Kernel Queue Discipline Tester: fqcodel+ Analysis

## Introduction

This project involves the development and testing of a custom Linux kernel network queue discipline (qdisc) module named `fqcodel+`. The initial goal was to create an enhanced version of FQ-CoDel.

Testing was performed using the `flent` network benchmarking tool, specifically the `rrul` (Realtime Response Under Load) test suite, to compare the performance of `fqcodel+` against standard kernel qdiscs (`fq_codel`, `pfifo`, and the system default) under simulated network load.

## The `fqcodel+` Module (Current Implementation)

Based on code analysis and performance testing, the current version of the `fqcodel+` module (as provided in `fq_codel_plus.c`) **implements a simple FIFO (First-In, First-Out) queue with tail drop**.

*   It utilizes a single queue for all traffic.
*   It drops packets only when the queue reaches a hardcoded packet limit (`MAX_QUEUE_LEN`, determined to be 100 based on comparative tests with `pfifo limit 100`).
*   It **does not** currently implement Fair Queuing (flow separation/scheduling) or CoDel (Controlled Delay - active latency management based on packet sojourn time) algorithms.

Therefore, despite its name, its behavior is functionally equivalent to `pfifo limit 100`.

## Testing Methodology

Comparative performance tests were conducted using `flent rrul`.

*   **Client (Test Controller):** The machine running the `flent` command and the test script (`run_flent_tests.sh`). Can be macOS, Linux, or Windows (with prerequisites met).
*   **Server/DUT (Device Under Test):** **Must be a Linux machine** (e.g., Ubuntu Virtual Machine, physical Linux box) with IP: `192.168.64.3` (configurable). This machine runs the custom `fqcodel+` module and standard kernel qdiscs applied to its network interface (`enp0s1` - configurable).
*   **Test Command:** `flent rrul -p all_scaled -l 60 -H <VM_IP> -t <Test_Title> -o <output_plot.png>`
*   **Qdiscs Compared on Server/DUT:**
    1.  `fqcodel+` (Custom Module)
    2.  `fq_codel` (Kernel's standard FQ-CoDel)
    3.  `pfifo limit 100` (Kernel's Packet FIFO with a limit matching the custom module's apparent limit)
    4.  `Default` (The system's default qdisc on the Server/DUT, likely `pfifo_fast`)
*   **Key Metrics:** TCP download/upload throughput and Ping latency (UDP and ICMP) under load, measured by the client connecting to the server.

## Key Findings

The comparative `flent` plots revealed distinct performance characteristics:

1.  **Kernel `fq_codel`:** Demonstrated superior Active Queue Management (AQM). It maintained the lowest average and peak latencies under load while achieving high throughput, effectively mitigating bufferbloat thanks to its CoDel and Fair Queuing mechanisms.
2.  **`fqcodel+` (Custom Module):** Showed moderately controlled latency, significantly better than an unmanaged queue *but clearly worse* than kernel `fq_codel`. Its performance profile (latency, throughput variation) was **almost identical** to `pfifo limit 100`. The latency control observed is solely due to tail-dropping packets when the fixed queue limit (100 packets) is reached. Download throughput was noticeably lower than kernel `fq_codel` or `pfifo`.
3.  **`pfifo limit 100`:** Performed virtually identically to the `fqcodel+` module, confirming the custom module's current behavior as a simple length-limited FIFO queue.
4.  **Default Qdisc:** Also performed almost identically to `pfifo limit 100` and `fqcodel+`, indicating the system default on the Server/DUT likely behaves as a buffer-limited FIFO under this type of load.

**Conclusion:** The tests successfully validated the methodology and demonstrated that the custom `fqcodel+` module, in its current state, acts as a basic FIFO queue with a packet limit, not as an implementation of FQ-CoDel algorithms.

## How to Run Tests

A script (`run_flent_tests.sh`) is provided to automate these comparative tests. It is designed to be run from the **Client** machine.

**Prerequisites:**

1.  **Server/DUT (Linux Machine):**
    *   Linux kernel headers and build tools (`build-essential`, `linux-headers-$(uname -r)`).
    *   `iproute2` package (for `tc`).
    *   Compiled custom `fqcodel+.ko` module transferred to the machine (e.g., to the home directory of `VM_USER`).
    *   SSH server running (`openssh-server`).
    *   User account (`VM_USER` in script) configured for **passwordless sudo** for `tc` and `insmod`/`rmmod` commands. (Editing `/etc/sudoers` or adding a file in `/etc/sudoers.d/` is the standard way. **Use with caution.** Example for `tc` only: `<VM_USER> ALL=(ALL) NOPASSWD: /sbin/tc, /sbin/insmod, /sbin/rmmod`)
2.  **Client (macOS, Linux, Windows):**
    *   **Bash-compatible Shell:**
        *   macOS: Terminal (default bash or zsh).
        *   Linux: Any standard terminal (bash, zsh, etc.).
        *   Windows: **WSL (Windows Subsystem for Linux)** with a Linux distribution installed (e.g., Ubuntu) OR **Git Bash** (comes with Git for Windows).
    *   **SSH Client:**
        *   macOS/Linux: Usually built-in (`ssh`). Ensure `openssh-client` is installed if needed.
        *   Windows: Available within WSL or Git Bash. Can also install OpenSSH client for Windows separately.
    *   **Python 3 & Pip:** Required for Flent. Install from official sources or package managers.
    *   **Flent:** Install within a Python virtual environment (recommended):
        ```bash
        python3 -m venv venv
        source venv/bin/activate  # On Linux/macOS/WSL/Git Bash
        # or .\venv\Scripts\activate on Windows cmd/powershell IF running flent manually
        pip install flent matplotlib
        # Deactivate when done: deactivate
        ```
    *   **SSH Key Authentication (Highly Recommended):** Configure SSH keys to connect from the Client to the Server/DUT as `VM_USER` without a password. This is crucial for script automation. (Search for "ssh-keygen" and "ssh-copy-id" tutorials for your client OS).

**Running the Script:**

1.  Ensure all prerequisites are met on both Client and Server/DUT.
2.  Edit the configuration variables at the top of `run_flent_tests.sh` (VM IP, User, Interface, etc.).
3.  Make the script executable: `chmod +x run_flent_tests.sh` (Run this command in your bash-compatible shell).
4.  Run the script from your **bash-compatible shell** on the Client machine: `./run_flent_tests.sh`
5.  The script will:
    *   Connect to the Server/DUT via SSH.
    *   Sequentially apply each qdisc (`fqcodel+`, `fq_codel`, `pfifo limit 100`, default) using `sudo tc`.
    *   Run the `flent rrul` test from the Client for each qdisc configuration on the server.
    *   Save the plot PNGs and `.flent.gz` data files in the directory where the script is run on the Client.
    *   Attempt to reset the qdisc to default on the Server/DUT at the end.

