#!/bin/bash

SWAP_PATH="/swapfile"
SWAP_SIZE="32G"

echo "Creating a temporary swap file of $SWAP_SIZE at $SWAP_PATH..."

sudo fallocate -l $SWAP_SIZE $SWAP_PATH

sudo chmod 600 $SWAP_PATH
sudo mkswap $SWAP_PATH
sudo swapon $SWAP_PATH

echo "Swap is now active. :D"
free -h
