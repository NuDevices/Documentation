#!/bin/bash
set -e

echo 'KERNEL=="xdma*", MODE="0666"' | sudo tee /etc/udev/rules.d/60-xdma.rules
sudo udevadm control --reload-rules
sudo udevadm trigger