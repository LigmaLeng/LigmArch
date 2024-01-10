#!/usr/bin/env bash
source ./utils.sh

FTB="\e[1m" # Format Text Bold
FCR="\e[91m" # Format Colour Red
FCG="\e[92m" # Format Colour Green
FCB="\e[34m" # Format Colour Blue
FCY="\e[93m" # Format Colour Yellow
FNUL="\e[0m" # Format NULL

SPLASH='
___________                   _______             ______
___  /___(_)______ _______ ______    |_______________  /_
__  / __  /__  __ `/_  __ `__ \_  /| |_  ___/  ___/_  __ \
_  /___  / _  /_/ /_  / / / / /  ___ |  /   / /__ _  / / /
/_____/_/  _\__, / /_/ /_/ /_//_/  |_/_/    \___/ /_/ /_/
           /____/'
greet() {
    printf "${FCY}${SPLASH}${FNUL}\n"
}

# Output and Error handling function
silence () {
    # Redirect stdout to the abyss while capturing stderr in variable
    ERR=$($1 2>&1 > /dev/null/)
    # If return code of last command is not 0
    if [ "$?" -ne 0 ]; then
        printf "${FTB}${FTR}Warning! Error executing command:${FNUL} $1\n"
    printf "Printing e\n"
    fi
}

pprint() {
    local n=${#1}
    echo "$(repeat $n "-")"
    echo "${1}"
    echo "$(repeat $n "-")"
}

silence "pacman-key --init"
silence "pacman-key --populate archlinux"
silence "pacman -Sy archlinux-keyring --noconfirm"

pprint "Listing available disks"
lsblk

printf "\nEnter disk selection to format: ( e.g. [ /dev/sda | /dev/nvme0n1 ] )\n>\n"
read DISK
silence "umount ${DISK}"
dd if=/dev/zero of=${DISK} bs=64K status=progress
echo "-----------------------------------------------------"
echo "              Generating partition table             "
echo "-----------------------------------------------------"
sgdisk -a 2048 -o ${DISK} # Create new GPT disklabel
silence "sgdisk -n 1:0:+500M ${DISK}" # Create first partition up to from with last sector offset by 512MB
silence "sgdisk -n 2:0:0 ${DISK}" # Create second partition with remaining storage space
silence "sgdisk -t 1:ef00 ${DISK}" # Set partition 1 with EFI System type
silence "sgdisk -t 2:8e00 ${DISK}" # Set partition 2 with LVM type
partprobe ${DISK}
echo "-----------------------------------------------------"
echo "              Formatting EFI partition               "
echo "-----------------------------------------------------"
mkfs.fat -F 32 "${DISK}p1" # Build fat32 format file system on partition 1
printf "\n\n"
echo "-----------------------------------------------------"
echo "         Setting up volumes for LVM partition        "
echo "-----------------------------------------------------"
silence "pvcreate --dataalignment 1m "${DISK}p2"" # Create physical volume container to separate into logical volumes
silence "vgcreate volgroup0 "${DISK}p2"" # Declare logical volume group
silence "lvcreate -L 64GB volgroup0 -n lv_root" # Create logical volume for root file system
silence "lvcreate -l 100%FREE volgroup0 -n lv_home" # Create logical volume for non-root file system
modprobe dm_mod # Load device mapper module into the kernel for to be utilised by lvm2
vgscan # Have kernel scan for volume group
vgchange -ay # Activate volume group
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
[[ ${vendor_id} == *"AuthenticAMD"* ]] && ucode="amd-ucode" || ucode="intel-ucode"
silent "pacstrap -K /mnt base base-devel linux-lts linux-lts-headers linux-firmware lvm2 neovim openssh networkmanager grub efibootmgr dosfstools os-prober mtools man-db man-pages ${ucode} --noconfirm --needed"
echo "-----------------------------------------------------"
echo "                Generating fstab file                "
echo "       --------------------------------------        "
echo "       Ensure no errors in fstab output below        "
echo "-----------------------------------------------------"
genfstab -U -p /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
echo "-----------------------------------------------------"
echo "         Pre-installation complete. Execute          "
echo "                 >arch-chroot /mnt                   "
echo "    if no errors found, before running miseEnScene   "
echo "-----------------------------------------------------"
