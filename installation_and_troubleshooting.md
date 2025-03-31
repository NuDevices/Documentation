# BARQ DevKit Installation Guide

This guide provides step-by-step instructions for installing your accelerator card.

## System Requirements

- Linux operating system (Ubuntu 20.04 LTS or newer recommended)
- PCIe slot (Gen3 x8 or better recommended)
- At least 2GB of free RAM
- Kernel headers installed for your current kernel version

## Hardware Installation

1. Power off your system completely and unplug the power cable.

2. Open your computer case following the manufacturer's instructions.

3. Locate an available PCIe slot (x8 or x16) on your motherboard.
   - For optimal performance, use a PCIe Gen3 x8 or x16 slot directly connected to the CPU (not through a chipset)
   - Avoid using slots that share bandwidth with other devices when possible

4. Remove the PCIe slot cover from the back of your computer case.

5. Carefully align the BARQ accelerator card with the PCIe slot and firmly press it down until it clicks into place.
   - Ensure the card is fully seated in the slot
   - The metal bracket should align perfectly with the case

6. Secure the card to the case with the screw that previously held the slot cover.

7. The card does NOT require any external power source.

8. Close your computer case and reconnect the power cable.

9. Power on your system.

10. Verify the card is detected by your system:

    ```bash
    sudo lspci -v | grep -A 5 "Xilinx"
    ```

    You should see output similar to:
    ```
    01:00.0 Processing accelerators: Xilinx Corporation Device 903f
            Subsystem: Xilinx Corporation Device 903f
            Flags: fast devsel, IRQ 16, NUMA node 0
            Memory at fc000000 (64-bit, prefetchable) [size=32M]
            Memory at fe000000 (64-bit, prefetchable) [size=128K]
            Capabilities: [40] Power Management version 3
    ```

    If you can't find a Xilinx device in the lspci output, you may proceed with
    the driver installation and reboot again. If your OS still can't enumerate, please
    see the troubleshooting section below.

## Pre-Installation Steps

1. Ensure you have the necessary dependencies:

    ```bash
    sudo apt update
    sudo apt install build-essential linux-headers-$(uname -r) git
    ```

2. Clone our driver repository:

    ```bash
    git clone https://github.com/Xilinx/dma_ip_drivers.git
    cd dma_ip_drivers
    ```

## Driver Installation

1. Navigate to the XDMA driver directory:

    ```bash
    cd XDMA/linux_kernel/xdma
    ```

2. Compile and install the kernel module driver:

    ```bash
    make clean
    make
    sudo make install
    ```

3. Navigate to the tools directory:

    ```bash
    cd ../tools
    ```

4. Compile the provided example test tools:

    ```bash
    make
    ```

5. Load the kernel module driver using one of the following methods:

    a. Using the provided script (recommended):
    ```bash
    cd ../tests
    sudo ./load_driver.sh
    ```

    b. Using modprobe:
    ```bash
    sudo modprobe xdma
    ```

    __Note: Each time you restart your computer, you will need to manually reload the driver. Therefore, we recommend configuring your operating system to automatically load it during the boot process.__

6. Verify the driver was loaded correctly:

    ```bash
    lsmod | grep xdma
    ```

7. Check driver version:

    ```bash
    modinfo xdma
    ```

8. After successful installation, you should find device nodes in the `/dev` directory (e.g., `/dev/xdma0_h2c_0`, `/dev/xdma0_c2h_0`). If these nodes are not created automatically despite successful driver loading, you can create them manually using:

    ```bash
    sudo ./tests/mknod.sh
    ```

9. To allow non-root users to access the device nodes:

    ```bash
    sudo chmod 666 /dev/xdma*
    ```
    For a more permanent solution, create a udev rule:
    ```bash
    echo 'KERNEL=="xdma*", MODE="0666"' | sudo tee /etc/udev/rules.d/60-xdma.rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    ```

## Post Installation

1. Verify that the PCIe endpoint is enabled for memory transactions:

    a. First identify the board bdf address
    ```bash
    lspci | grep Xilinx
    ```
    it'll be the string with format `00:00.0`

    b. Then check if memory transactions are enabled
    ```bash
    lspci -vvs 00:00.0
    ```
    look for `Mem+` in the output

    c. If memory transactions are disabled (you'll see `Mem-`), enable them with
    ```bash
    setpci -s 00:00.0 4.w=0x0006
    ```
    then run `lspci` again to verify that memory transactions are now enabled.

2. If you find out that memory transaction are disabled after reboot, you may want to
 run setpci at each boot with a system startup script. Here we provide an example, beware
 that it might need adjustments to work on you host machine.

    a. create a systemd unit:
    ```bash
    sudo nano /etc/systemd/system/setpci-pcie-config.service
    ```

    b. Add the following content (modify the ExecStart line with the correct PCIe address):
    ```
    [Unit]
    Description=Configure PCIe settings at startup
    After=network.target

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/setpci -s 00:00.0 4.w=0x0006
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
    ```

3. Check link status and speed:

    ```bash
    lspci -vv -s 00:00.0 | grep -i 'LnkSta:'
    ```
    You should see:
    ```
    LnkSta: Speed 8GT/s, Width x8
    ```

4. Run a full tests using our pcie_healtcheck.sh script.

    ```bash
    sudo ./brq_pcie_run_hc.sh
    ```
    It will perform a series of data transfer and check for integrity upon receival.
    If the test completes without errors, your card is properly installed and functioning.

## Troubleshooting

### Card not detected by `lspci`

If you can't find the board in the output of lspci, you should follow these steps:

1. Check the indicator LEDs on the board:

    * Locate the 4 LEDs near the power LED on the board
    * The leftmost LED should be red, indicating successful PCIe link training
    * If this LED is not lit, there's likely a hardware connectivity issue

2. If the leftmost LED is not red:

    * Ensure the board is properly seated in the PCIe slot
    * Power off the system, remove and reinsert the card
    * Go into your system BIOS/UEFI and check PCIe slot settings
    * Set the PCIe configuration to "Auto" or explicitly to "x8+x8" mode if available
    * If the LED still doesn't light up after these steps, contact our support team

3. If the LED is red but the card still doesn't appear in lspci:

    * Check that the driver is loaded
    ```bash
    ls /dev/xdma0*
    ```
    * If no devices are listed, reload the driver
    ```bash
    cd /path/to/dma_ip_drivers/XDMA/linux-kernel/tests
    sudo ./load_driver.sh
    ```
    * Check for errors in the system log
    ```bash
    dmesg | grep -i xdma
    ```
    * If the issue persist, reinstall the driver from scratch:
    ```bash
    cd /path/to/dma_ip_drivers/XDMA/linux-kernel/xdma
    make clean
    make
    sudo make install
    cd ../tests
    sudo ./load_driver.sh
    ```
    * Test first with root privileges before enabling access for non-root users
    * If problems persist after these steps, contact our support team

### Issue: Card Detected But Read/Write Operations Fail

If the board is correctly enumerated and listed in lspci output, but you're facing problem reading and or writing from/to it:

1. Check if memory transactions are enabled:

    ```bash
    sudo lspci -vvs 00:00.0
    ```

2. If memory transactions are not enabled, run:

    ```bash
    sudo setpci -s 00:00.0 4.w=0x0006
    ```

3. If the issue persists, check descriptors permissions:

    ```bash
    ls -la /dev/xdma*
    ```

4. Make sure you're running with sufficient privileges:

    a. either as root (e.g. sudo)
    b. or make sure that non-root user execution permissions have been set (refer to driver installation for that).

5. If issues persist after these steps, contact our support team

## Support

If you experience issues after following this guide, please contact our support team at t.isoppi@barqtech.ae with the following information:

1. Output of `lspci -vv`
2. Output of `dmesg | grep -i xdma`
3. Your Linux distribution and kernel version (`uname -a`)
4. A description of the issue you're experiencing
