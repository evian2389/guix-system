#!/bin/bash
set -e

# This script prepares a disk for Guix installation with LUKS and Btrfs.
# It is based on the instructions in INIT.md.
#
# IMPORTANT:
# - Run this script from within a 'guix shell' with the necessary tools:
#   guix shell parted cryptsetup btrfs-progs git make
#   git clone https://github.com/evian2389/guix_system.git ;;; https://codeberg.org/orka/guix_system.git
# - This script will DESTROY all data on the selected disk.
# - The script assumes the disk has two partitions:
#   - Partition 1: EFI System Partition (fat32)
#   - Partition 2: LUKS-encrypted Btrfs partition

# Prompt for the disk device
#read -p "Enter the disk device to partition (e.g., /dev/sda, /dev/nvme0n1): " DISK
#
#
#if [ -z "$DISK" ]; then
#    echo "No disk device entered. Aborting."
#    exit 1
#fi
#
#echo "WARNING: This will destroy all data on $DISK. Press Enter to continue, or Ctrl+C to abort."
#read
#
# Partition the disk
#parted -s "$DISK" -- mklabel gpt
#parted -s "$DISK" -- mkpart "EFI system partition" fat32 1MiB 1025MiB
#parted -s "$DISK" -- set 1 esp on
#parted -s "$DISK" -- mkpart primary 1025MiB 100%
#
# Get the partition names
#EFI_PARTITION="${DISK}1"
#LUKS_PARTITION="${DISK}2"
#if [ ! -b "$EFI_PARTITION" ]; then
#    EFI_PARTITION="${DISK}p1"
#    LUKS_PARTITION="${DISK}p2"
#fi
#
# Format the EFI partition
#mkfs.fat -F32 "$EFI_PARTITION"

# Create the LUKS container
#cryptsetup luksFormat --type luks2 --pbkdf pbkdf2 "$LUKS_PARTITION"
#cryptsetup luksOpen "$LUKS_PARTITION" enc

# Create the Btrfs filesystem
#mkfs.btrfs -L guixroot /dev/mapper/enc
EFI_PARTITION_DEVICE="/dev/nvme0n1p1"
GUIX_ROOT_DEVICE="/dev/nvme0n1p2" # Update this if your LUKS partition is named differently"
mkfs.btrfs -L guixroot "$GUIX_ROOT_DEVICE"

# Mount the top-level Btrfs volume
#mount /dev/mapper/enc /mnt
mount "$GUIX_ROOT_DEVICE" /mnt
cd /mnt

# Create all the desired subvolumes
btrfs subvolume create @
btrfs subvolume create @boot
btrfs subvolume create @home
btrfs subvolume create @gnu
btrfs subvolume create @data
btrfs subvolume create @var-log
btrfs subvolume create @swap



# Unmount the top-level volume
cd /
umount /mnt

# Mount the subvolumes with compression
BTRFS_OPTS="rw,noatime,compress=zstd,discard=async,space_cache=v2"
mount -o $BTRFS_OPTS,subvol=@ $GUIX_ROOT_DEVICE /mnt
mkdir -p /mnt/{boot,home,gnu,data,swap}
mount -o $BTRFS_OPTS,subvol=@boot $GUIX_ROOT_DEVICE /mnt/boot
mount -o $BTRFS_OPTS,subvol=@home $GUIX_ROOT_DEVICE /mnt/home
mount -o $BTRFS_OPTS,subvol=@gnu $GUIX_ROOT_DEVICE /mnt/gnu
mount -o $BTRFS_OPTS,subvol=@data $GUIX_ROOT_DEVICE /mnt/data

mkdir -p /mnt/data/system/var/lib
mkdir -p /mnt/var/lib
mount --bind /mnt/data/system/var/lib /mnt/var/lib

mkdir -p /mnt/var/log

mount -o $BTRFS_OPTS,subvol=@var-log $GUIX_ROOT_DEVICE /mnt/var/log
mount -o nodatacow,compress=none,subvol=@swap $GUIX_ROOT_DEVICE /mnt/swap

# Mount the EFI partition
mkdir -p /mnt/boot/efi
mount $EFI_PARTITION_DEVICE /mnt/boot/efi



# Create the swapfile
btrfs filesystem mkswapfile --size 64g --uuid clear /mnt/swap/swapfile

# Activate the swapfile
swapon /mnt/swap/swapfile
export TMPDIR=/mnt/data/raynet-guix/tmp
mkdir -p $TMPDIR



# Get the UUIDs for configuration.scm
echo "========================================================================"
echo "Done. The following UUIDs will be needed for your configuration.scm:"
echo ""
echo "LUKS partition UUID:"
blkid -s UUID -o value "$LUKS_PARTITION"
echo ""
echo "BTRFS filesystem UUID:"
blkid -s UUID -o value /dev/mapper/enc
echo "========================================================================"
cat <<'NEXT_STEPS'
========================================================================
NEXT STEPS:
1. GENERATE PASSWORD HASH:
	Before building your system, you need to generate a password hash for the 'orka' user.
	Run this command in your terminal (replace "YOUR_PASSWORD_HERE"):
	guile -c '(use-modules (gnu home user)) (display (crypt "YOUR_PASSWORD_HERE" (make-salt)))'

2. UPDATE CONFIGURATION.SCM:
	Edit 'config/systems/ser8/configuration.scm'.
	- Replace "YOUR_LUKS_PARTITION_UUID_HERE" with the LUKS UUID printed above.
	- Replace "YOUR_EFI_PARTITION_UUID_HERE" with the UUID of your EFI partition (e.g., from 'blkid /dev/sda1').
	- Replace "YOUR_PASSWORD_HASH_HERE" with the hash you generated in step 1.

3. BUILD YOUR SYSTEM:
    ### remove guix EFI directory!!!
	Once configuration.scm is updated, run:
	make cow-store
	make init
	make install-system
========================================================================
NEXT_STEPS
