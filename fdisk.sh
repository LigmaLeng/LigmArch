#!/usr/bin/env bash

echo "-----------------------------------------------------"
echo "               Listing available disks               "
echo "-----------------------------------------------------"
fdisk -l
echo -e "\nEnter disk selection to format: ( e.g. [ /dev/sda | /dev/nvme0n1 ] )"
read TGT_DISK
echo "-----------------------------------------------------"
echo "              Generating partition table             "
echo "-----------------------------------------------------"
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${TGT_DISK}
	o # Clears in-memory partition table
	g # Create new GPT disklabel
	n # Create new partition
	1 # Partition 1
	  # First sector for partition 1 - defaults at byte 2048
   + 500M # Last sector for partition 1 - incremented by 500Mb from first sector
   	t # Change partition type for partition 1
	1 # Select EFI System partition type
	n # Create new partition
	2 # Partition 2
	  # First sector for partition 2 - default to following byte after partition 1
	  # Last sector for partition 2 - default to end of disk
	t # Change partition type for following partition
	2 # Partition 2
       44 # Select Linux LVM partition type
       	p # Print partition table
	w # Write partition table
	q # Quit
EOF
echo -e "\n"
echo "-----------------------------------------------------"
echo "              Formatting EFI partition               "
echo "-----------------------------------------------------"
mkfs.fat -F32 "${TGT_DISK}p1"
echo -e "\n"
echo "-----------------------------------------------------"
echo "         Setting up volumes for LVM partition        "
echo "-----------------------------------------------------"
pvcreate --dataalignment 1m "${TGT_DISK}p2"
vgcreate volgroup0 "${TGT_DISK}p2"
lvcreate -L 64GB volgroup0 -n lv_root
lvcreate -l 100%FREE volgroup0 -n lv_home
echo "-----------------------------------------------------"
echo "             Activating logical volumes              "
echo "-----------------------------------------------------"
modprobe dm_mod
vgscan
vgchange -ay
echo "-----------------------------------------------------"
echo "             Formatting root file system             "
echo "-----------------------------------------------------"
mkfs.ext4 /dev/volgroup0/lv_root
mount /dev/volgroup0/lv_root /mnt
mkfs.ext4 /dev/volgroup0/lv_home
mkdir /mnt/home
mount /dev/volgroup0/lv_home /mnt/home
echo "-----------------------------------------------------"
echo "                Generating fstab file                "
echo "       --------------------------------------        "
echo "       Ensure no errors in fstab output below        "
echo "-----------------------------------------------------"
mkdir /mnt/etc
genfstab -U -p /mnt >> /mnt/etc/fstab
echo "-----------------------------------------------------"
echo "              End of formatting script               "
echo "-----------------------------------------------------"
