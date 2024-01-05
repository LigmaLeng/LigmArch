#!/usr/bin/env bash

pacman-key --init
pacman-key --populate archlinux
pacman -Sy archlinux-keyring
echo "-----------------------------------------------------"
echo "               Listing available disks               "
echo "-----------------------------------------------------"
lsblk
echo -e "\nEnter disk selection to format: ( e.g. [ /dev/sda | /dev/nvme0n1 ] )"
read TGT_DISK
umount ${TGT_DISK}
dd if=/dev/zero of=${TGT_DISK} bs=64K status=progress
echo "-----------------------------------------------------"
echo "              Generating partition table             "
echo "-----------------------------------------------------"
sgdisk -a 2048 -o ${TGT_DISK} # Create new GPT disklabel
sgdisk -n 1:0:+500M ${TGT_DISK} # Create first partition up to from with last sector offset by 512MB
sgdisk -n 2:0:0 ${TGT_DISK} # Create second partition with remaining storage space
sgdisk -t 1:ef00 ${TGT_DISK} # Set partition 1 with EFI System type
sgdisk -t 2:8e00 ${TGT_DISK} # Set partition 2 with LVM type
echo "-----------------------------------------------------"
echo "              Formatting EFI partition               "
echo "-----------------------------------------------------"
mkfs.fat -F 32 "${TGT_DISK}p1" # Build fat32 format file system on partition 1
echo -e "\n"
echo "-----------------------------------------------------"
echo "         Setting up volumes for LVM partition        "
echo "-----------------------------------------------------"
pvcreate --dataalignment 1m "${TGT_DISK}p2" # Create physical volume container to separate into logical volumes
vgcreate volgroup0 "${TGT_DISK}p2" # Declare logical volume group
lvcreate -L 64GB volgroup0 -n lv_root # Create logical volume for root file system
lvcreate -l 100%FREE volgroup0 -n lv_home # Create logical volume for non-root file system
modprobe dm_mod # Load device mapper module into the kernel for to be utilised by lvm2
vgscan # Have kernel scan for volume group
vgchange -ay # Activate volume group
echo "-----------------------------------------------------"
echo "             Activating logical volumes              "
echo "-----------------------------------------------------"
modprobe dm_mod
vgscan
vgchange -ay
echo "-----------------------------------------------------"
echo "             Formatting logical volumes              "
echo "-----------------------------------------------------"
mkfs.ext4 -F /dev/volgroup0/lv_root
mount /dev/volgroup0/lv_root /mnt
mkfs.ext4 -F /dev/volgroup0/lv_home
mkdir /mnt/home
mount /dev/volgroup0/lv_home /mnt/home
mkdir /mnt/etc
echo "-----------------------------------------------------"
echo "       Installing base packages for Arch Linux       "
echo "-----------------------------------------------------"
vendor_id=$(grep vendor_id /proc/cpuinfo)
[[ $vendor_id == *"AuthenticAMD"* ]] && ucode="amd-ucode" || ucode="intel-ucode"
pacstrap -K /mnt base base-devel linux-lts linux-lts-headers linux-firmware lvm2 neovim openssh networkmanager grub efibootmgr dosfstools os-prober mtools "$ucode" --noconfirm --needed
echo "-----------------------------------------------------"
echo "                Generating fstab file                "
echo "       --------------------------------------        "
echo "       Ensure no errors in fstab output below        "
echo "-----------------------------------------------------"
genfstab -U -p /mnt >> /mnt/etc/fstab
echo "-----------------------------------------------------"
echo "         Pre-installation complete. Execute          "
echo "                 >arch-chroot /mnt                   "
echo "    if no errors found, before running miseEnScene   "
echo "-----------------------------------------------------"
