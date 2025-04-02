## Basic Verification & Fairness Tests (`iperf3`)

In addition to the `flent` tests which assess performance under mixed load, simpler tests using `iperf3` were performed to directly observe the module's basic queuing behavior and fairness characteristics with simple TCP flows.

**Purpose:**

1.  **Basic Verification:** Confirm that the `fqcodel+` module is correctly intercepting packets (enqueue/dequeue functions are called) and observe if the queue limit (`MAX_QUEUE_LEN`) is reached under simple, single-flow load. This involves monitoring kernel messages (`dmesg`) and queue statistics (`tc -s qdisc`) during an `iperf3 -P 1` test.
2.  **Fairness Test:** Observe how the module distributes bandwidth between multiple concurrent flows (`iperf3 -P 5`) compared to kernel `fq_codel`. This helps characterize the (lack of) Fair Queuing in the current implementation.

**Findings from `iperf3` tests:**

*   **Basic Verification:** The `dmesg` output confirmed that the `enqueue` and `dequeue` functions were called. However, with a single `iperf3` flow, the queue length (`qlen`) reported by `dmesg` remained very low (0 or 1), and `tc -s qdisc show` showed no significant backlog or drops. This indicated the queue limit was **not reached** under single-flow conditions, likely because the system could dequeue packets faster than the single flow could enqueue them.
*   **Fairness Test:** The `iperf3 -P 5` test showed **uneven bandwidth distribution** between the 5 flows when using the `fqcodel+` module (as expected from FIFO). In the specific comparative run against kernel `fq_codel`, the `fqcodel+` module coincidentally showed *less* variation than kernel `fq_codel` in that short test, but kernel `fq_codel` is designed for better long-term fairness.

**How to Run Basic & Fairness Tests:**

A script (`run_basic_fairness_tests.sh`) is provided to assist with these tests. **Note:** This script sets up the environment but requires **manual observation** of monitoring tools (`dmesg`, `watch tc`) on the Server/DUT during the tests.

**Prerequisites:**

*   Same prerequisites as for the `flent` tests (Client setup with bash/ssh/iperf3, Server/DUT setup with Linux/headers/module/SSH/passwordless sudo).
*   `iperf3` installed on **both** Client and Server/DUT.

**Running the Script:**

1.  Edit configuration variables in `run_basic_fairness_tests.sh`.
2.  Make it executable: `chmod +x run_basic_fairness_tests.sh`.
3.  Run from the Client: `./run_basic_fairness_tests.sh`.
4.  **Crucially:** Follow the script's prompts. When instructed, **manually open separate SSH sessions** to the Server/DUT and run `sudo dmesg -w` in one and `watch -n 0.1 sudo tc -s qdisc show dev <IFACE>` in another. Observe their output *during* the `iperf3` runs as guided by the script.