#!/bin/bash
set -e

echo "===> BARQ Driver Installation Script"

# 1. Install dependencies
echo "===> Installing dependencies..."
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git

# 2. Clone the Xilinx XDMA driver repo
echo "===> Cloning XDMA driver repo..."
git clone https://github.com/Xilinx/dma_ip_drivers.git
cd dma_ip_drivers/XDMA/linux-kernel/xdma

# 3. Build and install the kernel module
echo "===> Building XDMA kernel module..."
make clean
make
echo "===> Installing XDMA kernel module..."
sudo make install

# 4. Load the driver
echo "===> Loading XDMA kernel module..."
sudo modprobe xdma
sudo ../tests/load_driver.sh

# 5. Check driver loaded
echo "===> Verifying driver load..."
lsmod | grep xdma || { echo "XDMA driver not loaded. Aborting."; exit 1; }

# 6. Check for device nodes
echo "===> Checking for XDMA device nodes..."
ls /dev/xdma* || echo "Device nodes not found. You may need to run mknod later."

# 7. Check for Xilinx PCIe device
echo "===> Checking for BARQ PCIe device..."
lspci | grep -i xilinx || echo "Warning: No Xilinx PCIe device found. Check installation."

echo "===> BARQ driver installed and loaded successfully."
