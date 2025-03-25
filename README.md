# FQ-CoDel+ Qdisc Module

A Linux kernel module implementing an enhanced version of the FQ-CoDel (Flow Queue Controlled Delay) queueing discipline for traffic control.

## Overview

FQ-CoDel+ is designed as an improvement over the standard FQ-CoDel algorithm, providing better queue management for modern networking environments. This implementation is built as a loadable kernel module that integrates with the Linux TC (Traffic Control) subsystem.

## Features

- Simple queue management system
- Maximum queue length control
- Basic packet scheduling
- Integration with Linux TC (Traffic Control)
- Easy to install and use

## Requirements

- Linux kernel 6.8.0-56-generic or compatible version
- Linux kernel headers (matching your running kernel)
- Build tools: make, gcc
- iproute2 package (for tc command)
- Root/sudo privileges (for loading the module and applying qdisc)
- Git (for cloning the repository)

To install dependencies on Ubuntu/Debian:
```
sudo apt update
sudo apt install build-essential linux-headers-$(uname -r) iproute2 git make gcc
```

## Directory Structure

```
fq_codel_plus/
├── include/         # Header files
├── scripts/         # Helper scripts for loading/unloading
└── src/             # Source code and Makefile
```

## Getting Started

### Clone the Repository

```
git clone https://github.com/naveen-93/CS-615--Project.git
cd CS-615--Project
```

## Installation

### Manual Installation

1. Build the module:
   ```
   cd src
   make clean
   make
   ```

2. Load the module:
   ```
   sudo insmod fq_codel_plus.ko
   ```

3. Apply the qdisc to an interface:
   ```
   sudo tc qdisc add dev <interface> root fqcodel+
   ```

### Using Scripts

1. Load module and apply qdisc:
   ```
   sudo bash scripts/load_module.sh
   ```

2. Unload module and remove qdisc:
   ```
   sudo bash scripts/unload_module.sh
   ```

## Usage

### Check if qdisc is applied

```
tc qdisc show dev <interface>
```

### View statistics

```
tc -s qdisc show dev <interface>
```

## Debugging

The module outputs debug information to the kernel log, which can be viewed with:

```
dmesg | grep fq_codel_plus
```

