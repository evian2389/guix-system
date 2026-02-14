#!/bin/bash
set -e

# This script prepares a disk for Guix installation with LUKS and Btrfs.
# It is based on the instructions in INIT.md.
#
# IMPORTANT:
# - Run this script from within a 'guix shell' with the necessary tools:
#   guix shell parted cryptsetup btrfs-progs git
#   git clone https://codeberg.org/orka/guix_system.git
# - This script will DESTROY all data on the selected disk.
# - The script assumes the disk has two partitions:
#   - Partition 1: EFI System Partition (fat32)
#   - Partition 2: LUKS-encrypted Btrfs partition

# Prompt for the disk device
read -p "Enter the disk device to partition (e.g., /dev/sda, /dev/nvme0n1): " DISK

if [ -z "$DISK" ]; then
    echo "No disk device entered. Aborting."
    exit 1
fi

echo "WARNING: This will destroy all data on $DISK. Press Enter to continue, or Ctrl+C to abort."
read

# Partition the disk
sudo parted -s "$DISK" -- mklabel gpt
sudo parted -s "$DISK" -- mkpart "EFI system partition" fat32 1MiB 1025MiB
sudo parted -s "$DISK" -- set 1 esp on
sudo parted -s "$DISK" -- mkpart primary 1025MiB 100%

# Get the partition names
EFI_PARTITION="${DISK}1"
LUKS_PARTITION="${DISK}2"
if [ ! -b "$EFI_PARTITION" ]; then
    EFI_PARTITION="${DISK}p1"
    LUKS_PARTITION="${DISK}p2"
fi

# Format the EFI partition
sudo mkfs.fat -F32 "$EFI_PARTITION"

# Create the LUKS container
sudo cryptsetup luksFormat --type luks2 --pbkdf argon2id "$LUKS_PARTITION"
sudo cryptsetup luksOpen "$LUKS_PARTITION" enc

# Create the Btrfs filesystem
sudo mkfs.btrfs -L guixroot /dev/mapper/enc

# Mount the top-level Btrfs volume
sudo mount /dev/mapper/enc /mnt
cd /mnt

# Create all the desired subvolumes
sudo btrfs subvolume create @
sudo btrfs subvolume create @boot
sudo btrfs subvolume create @home
sudo btrfs subvolume create @gnu
sudo btrfs subvolume create @data
sudo btrfs subvolume create @var
sudo btrfs subvolume create @var_log
sudo btrfs subvolume create @opt
sudo btrfs subvolume create @swap

# Create the swapfile
sudo btrfs filesystem mkswapfile --size 64g --uuid clear @swap/swapfile

# Unmount the top-level volume
cd /
sudo umount /mnt

# Mount the subvolumes with compression
BTRFS_OPTS="rw,noatime,compress=zstd,discard=async,space_cache=v2"
sudo mount -o $BTRFS_OPTS,subvol=@ /dev/mapper/enc /mnt
sudo mkdir -p /mnt/{boot,home,gnu,data,var,var/log,opt,swap}
sudo mount -o $BTRFS_OPTS,subvol=@boot /dev/mapper/enc /mnt/boot
sudo mount -o $BTRFS_OPTS,subvol=@home /dev/mapper/enc /mnt/home
sudo mount -o $BTRFS_OPTS,subvol=@gnu /dev/mapper/enc /mnt/gnu
sudo mount -o $BTRFS_OPTS,subvol=@data /dev/mapper/enc /mnt/data
sudo mount -o $BTRFS_OPTS,subvol=@var /dev/mapper/enc /mnt/var
sudo mount -o $BTRFS_OPTS,subvol=@var_log /dev/mapper/enc /mnt/var/log
sudo mount -o $BTRFS_OPTS,subvol=@opt /dev/mapper/enc /mnt/opt
sudo mount -o $BTRFS_OPTS,subvol=@swap /dev/mapper/enc /mnt/swap

# Mount the EFI partition
sudo mkdir -p /mnt/boot/efi
sudo mount "$EFI_PARTITION" /mnt/boot/efi

# Activate the swapfile
sudo swapon /mnt/swap/swapfile

# Get the UUIDs for configuration.scm
echo "========================================================================"
echo "Done. The following UUIDs will be needed for your configuration.scm:"
echo ""
echo "LUKS partition UUID:"
sudo blkid -s UUID -o value "$LUKS_PARTITION"
echo ""
echo "BTRFS filesystem UUID:"
sudo blkid -s UUID -o value /dev/mapper/enc
echo "========================================================================"
# ========================================================================
# NEXT STEPS:
# 1. GENERATE PASSWORD HASH:
#    Before building your system, you need to generate a password hash for the 'orka' user.
#    Run this command in your terminal (replace "YOUR_PASSWORD_HERE"):
#    guile -c '(use-modules (gnu home user)) (display (crypt "YOUR_PASSWORD_HERE" (make-salt)))'
#
# 2. UPDATE CONFIGURATION.SCM:
#    Edit 'config/systems/ser8/configuration.scm'.
#    - Replace "YOUR_LUKS_PARTITION_UUID_HERE" with the LUKS UUID printed above.
#    - Replace "YOUR_EFI_PARTITION_UUID_HERE" with the UUID of your EFI partition (e.g., from 'sudo blkid /dev/sda1').
#    - Replace "YOUR_PASSWORD_HASH_HERE" with the hash you generated in step 1.
#
# 3. BUILD YOUR SYSTEM:
#    Once configuration.scm is updated, run:
#    sudo make install-system
# ========================================================================
