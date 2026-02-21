# -*- mode: org -*-
#+OPTIONS: toc:nil

* Installation
** Partitioning
Note, most of the commands related to partitioning will require root
priveleges.  Prefix them with ~sudo~ or issue them from priviledged user shell.

Some theory and concepts behind btrfs:
https://fedoramagazine.org/working-with-btrfs-general-concepts/

1. Enter environment, where all needed tools are available ~guix shell parted
   cryptsetup btrfs-progs~.
2. List all devices with ~parted -l~. Find appropriate one, save to variable
   ~$DISK~, for example ~DISK=/dev/sda~.
3. Make a partition table, it's very likely you need GPT (aka GUID Partition
   Table) and not MBR: ~parted $DISK~
4.

#+begin_src sh
guix shell parted git make #btrfs-progfs
sudo parted -l
DISK=/dev/sda

# Note: Your user account must be part of the video and lp (sometimes required
# for specific compute tasks) groups to have permission to access the /dev/dri/
# device files. This is already configured for the 'orka' user in base-system.scm.

# or
# DISK=/dev/nvme0n1
sudo parted $DISK
# it will open a parted prompt
mklabel gpt
# 1GiB is a safe size for EFI partition, but you probably will be fine
# with much smaller, do your research on this topic
mkpart "EFI system partition" fat32 0% 1024MiB
set 1 esp on
mkpart primary 1024MiB 100%

sudo -s
mkfs.fat -F32 /dev/sda1

#cryptsetup luksFormat --type luks1 /dev/sda2
# Need to explore and probably fix luks2 support
sudo cryptsetup luksFormat --type luks2 --pbkdf argon2id /dev/sda2
# Note the UUID shown above, it will be needed in configuration.scm
sudo cryptsetup luksOpen /dev/sda2 enc
# UUID: 6243841f-4171-43dd-8e0b-93bddd56daaa

sudo mkfs.btrfs -L guixroot /dev/mapper/enc
# Note the UUID shown above, it will be needed in configuration.scm

# Mount the top-level Btrfs volume
sudo mount /dev/mapper/enc /mnt
cd /mnt

# Create all the desired subvolumes
sudo btrfs subvolume create @
sudo btrfs subvolume create @boot
sudo btrfs subvolume create @home
sudo btrfs subvolume create @gnu
sudo btrfs subvolume create @data
sudo btrfs subvolume create @var-log
sudo btrfs subvolume create @swap

# Create the swapfile
sudo btrfs filesystem mkswapfile --size 64g --uuid clear @swap/swapfile

# Unmount the top-level volume
cd /
sudo umount /mnt

# Mount the subvolumes with compression
BTRFS_OPTS="rw,noatime,compress=zstd,discard=async,space_cache=v2"
sudo mount -o $BTRFS_OPTS,subvol=@ /dev/mapper/enc /mnt
sudo mkdir -p /mnt/{boot,home,gnu,data,swap}
sudo mount -o $BTRFS_OPTS,subvol=@boot /dev/mapper/enc /mnt/boot
sudo mount -o $BTRFS_OPTS,subvol=@home /dev/mapper/enc /mnt/home
sudo mount -o $BTRFS_OPTS,subvol=@gnu /dev/mapper/enc /mnt/gnu
sudo mount -o $BTRFS_OPTS,subvol=@data /dev/mapper/enc /mnt/data

# Persist all system data to data partition via bind mount
sudo mkdir -p /mnt/data/system/var/lib
sudo mkdir -p /mnt/var/lib
sudo mount --bind /mnt/data/system/var/lib /mnt/var/lib

sudo mkdir -p /mnt/var/log
sudo mount -o $BTRFS_OPTS,subvol=@var-log /dev/mapper/enc /mnt/var/log
sudo mount -o nodatacow,compress=none,subvol=@swap /dev/mapper/enc /mnt/swap

# Mount the EFI partition
sudo mkdir -p /mnt/boot/efi
sudo mount /dev/sda1 /mnt/boot/efi

# Activate the swapfile
sudo swapon /mnt/swap/swapfile

# Get the UUID of the LUKS partition for configuration.scm
echo "LUKS partition UUID:"
sudo blkid -s UUID -o value /dev/sda2

# Get the UUID of the BTRFS filesystem for configuration.scm
echo "BTRFS filesystem UUID:"
sudo blkid -s UUID -o value /dev/mapper/enc

# The user wants to keep the following commands as part of the guide
# Note: The 'mkdir' command below is redundant as the directories are
# already created by 'mkdir -p' above.
# mkdir {boot,boot/efi,home,gnu,data,var,var/log,opt,swap}

# IMPORTANT: Remove existing Guix EFI directory if it exists on the EFI partition
# to avoid conflicts during installation.
# rm -rf /mnt/boot/efi/EFI/Guix

make cow-store

# to write intermediate build results to actual drive
# instead of r/o or in-memory fs
export TMPDIR=/mnt/data/raynet-guix/tmp
mkdir -p $TMPDIR

make init
make install-system
#+end_src
