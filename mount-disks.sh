#!/bin/bash

sudo mkdir -p /mnt/data476 /mnt/data443

if ! mountpoint -q /mnt/data476; then
    sudo mount -t ntfs3 /dev/sda2 /mnt/data476
fi

if ! mountpoint -q /mnt/data443; then
    sudo mount -t ntfs3 /dev/sda5 /mnt/data443
fi

echo "HDD Partitions mounted successfully !!"
