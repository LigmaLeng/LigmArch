#!/usr/bin/env bash


setup_partitions() {
  local -n opt
  local -a flags
  opt=setopt_pairs
  flags=(-v -t ext4 -O casefold,fast_commit)
  umount -q ${opt[BLOCK_DEVICE]}
  wipefs -af ${opt[BLOCK_DEVICE]}
  sgdisk -Zo ${opt[BLOCK_DEVICE]}
  sgdisk -I -n 1:0:+${opt[ESP_SIZE]%iB} -t 1:EF00 ${opt[BLOCK_DEVICE]}
  sgdisk -I -n 2:0:0 -t 2:8E00 ${opt[BLOCK_DEVICE]}
  partprobe ${opt[BLOCK_DEVICE]}
  mkfs.fat -F 32 "${opt[BLOCK_DEVICE]}p1"
  [[ "${opt[EXT4_BLOCK_SIZE]}" == 'default' ]] && {
    : "${opt[BLOCK_DEVICE]}p2"
  } || : "--dataalignment ${opt[EXT4_BLOCK_SIZE]%B} ${opt[BLOCK_DEVICE]}p2"
  pvcreate $_
  vgcreate vg0 "${opt[BLOCK_DEVICE]}p2"
  lvcreate -y -L "${opt[ROOT_VOLUME_SIZE]}%iB" vg0 -n lv0
  lvcreate -y -L "${opt[HOME_VOLUME_SIZE]}%iB" vg0 -n lv1
  modprobe dm_mod
  vgscan
  vgchange -ay
  [[ "${opt[EXT4_BLOCK_SIZE]}" == 'default' ]] && {
    mke2fs ${flags[@]} /dev/vg0/lv0
  } || mke2fs ${flags[@]} -b ${opt[EXT4_BLOCK_SIZE]%B} /dev/vg0/lv0
  flags+=(-m 0 -T largefile)
  [[ "${opt[EXT4_BLOCK_SIZE]}" == 'default' ]] ||
    flags+=(-b ${opt[EXT4_BLOCK_SIZE]%B})
  mke2fs ${flags[@]} /dev/vg0/lv1
  [[ "${opt[MOUNT_OPTIONS]}" == 'unset' ]] || {
    tune2fs -E mount_opts="${opt[MOUNT_OPTIONS]//  / }" /dev/vg0/lv0
    tune2fs -E mount_opts="${opt[MOUNT_OPTIONS]//  / }" /dev/vg0/lv1
  }
  mount /dev/vg0/lv0 /mnt
  mount --mkdir ${opt[BLOCK_DEVICE]}p1 /mnt/efi
  mount --mkdir /dev/vg0/lv1 /mnt/home
}

setup_mirrors() {
  local i
  pacman -S pacman-contrib --noconfirm --needed
  [[ -a "/etc/pacman.d/mirrorlist.bak" ]] ||
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
  exec {fd_mirror}>${CACHE_DIR}/mirrors
  while read; do
    [[ "$REPLY" == '##'* ]] || continue
    [[ "${setopt_pairs[MIRRORS]}" =~ "${REPLY#* }" ]] && {
      while read; do
        [[ -z $REPLY ]] && break
        printf '%s\n' "${REPLY#\#}" >&$fd_mirror
      done
    }
  done < "${CACHE_DIR}/mirrorlist"
  exec {fd_mirror}>&-
  rankmirrors ${CACHE_DIR}/mirrors > /etc/pacman.d/mirrorlist
}

edit_pacconf() {
  local stream
  read -d '' -r stream < /etc/pacman.conf
  exec {fd_stream}>/etc/pacman.conf
  while read; do
    case $REPLY in
      '#[multilib]') printf '[multilib]\n' >&$fd_stream; read;&
      '#ParallelDownloads'*) : "${REPLY#\#}";;
      *) : "$REPLY";;
    esac
    printf '%s\n' "$_" >&$fd_stream
  done <<< "$stream"
  exec {fd_stream}>&-
}

strapon() {
  local -a pkg_base
  pkg_base=(base base-devel dosfstools e2fsprogs lvm2 pacman-contrib)
  edit_pacconf
  while read; do
    [[ $REPLY == vendor_id* ]] && {
      [[ $REPLY =~ AMD ]] && : 'amd-ucode' || : 'intel-ucode'
      pkg_base+=("$_")
      break
    } || continue
  done < /proc/cpuinfo
  pkg_base+=(${setopt_pairs[KERNEL]} "${setopt_pairs[KERNEL]}-headers")
  pacstrap -KP /mnt ${pkg_base[@]}
}

setup_localisation() {
  local stream
  printf '%s\n' "${setopt_pairs[HOSTNAME]}" > /mnt/etc/hostname
  read -d '' -r stream < /mnt/etc/locale.gen
  exec {fd_stream}>/mnt/etc/locale.gen
  while read; do
    : "$REPLY"
    [[ "$_" == "#${setopt_pairs[LOCALE]} "* ]] && : "${_#\#}"
    printf '%s\n' "$_" >&$fd_stream
  done <<< "$stream"
  exec {fd_stream}>&-
  printf 'LANG=%s\n' "${setopt_pairs[LOCALE]}" > /mnt/etc/locale.conf
  printf 'KEYMAP=%s\n' "${setopt_pairs[KEYMAP]}" > /mnt/etc/vconsole.conf
  #[[ "${setopt_pairs[PACKAGES_TERMINAL]}" =~ terminus-font ]] &&
    #printf 'FONT=ter-i32b\n' >> /mnt/etc/vconsole.conf
  printf '127.0.0.1 localhost\n::1 localhost\n' > /mnt/etc/hosts
  printf '127.0.1.1 %s.localdomain %s\n' $HOSTNAME $HOSTNAME >> /mnt/etc/hosts
}

setup_chroot() {
  local stream
  genfstab -U /mnt >> /mnt/etc/fstab
  : "ln -sf /usr/share/zoneinfo/${setopt_pairs[TIMEZONE]} /etc/localtime"
  arch-chroot /mnt /bin/bash -c "${_}; hwclock --systohc; locale-gen"
  printf '%s\n' "${setopt_pairs[HOSTNAME]}" > /mnt/etc/hostname
  read -d '' -r stream < /mnt/etc/mkinitcpio.conf
  exec {fd_stream}>/mnt/etc/mkinitcpio.conf
  while read; do
    : "$REPLY"
    [[ "$_" == HOOKS* ]] && {
      : "HOOKS=(systemd autodetect microcode modconf keyboard"
      : "$_ sd-vconsole block lvm2 filesystems fsck)"
    }
    printf '%s\n' "$_" >&$fd_stream
  done <<< "$stream"
  exec {fd_stream}>&-
  arch-chroot /mnt mkinitcpio -p ${setopt_pairs[KERNEL]}
  arch-chroot /mnt bootctl --esp-path=/efi install
  printf 'root:%s\n' "${setopt_pairs[ROOTPASS]}" > >(arch-chroot /mnt chpasswd)
  arch-chroot /mnt useradd -m -g users -G wheel ${setopt_pairs[USERNAME]}
  : "${setopt_pairs[USERNAME]}:${setopt_pairs[USERPASS]}"
  printf '%s\n' "$_" > >(arch-chroot /mnt chpasswd)
}

setup_zram() {
  local size
  while read; do
    [[ "$REPLY" == MemTotal* ]] && {
      : "${REPLY% kB}"; size=${_##* }; size=$(((size>>20)/2))
      break
    }
  done < /proc/meminfo
  printf 'zram\n' > /mnt/etc/modules-load.d/zram.conf
  printf 'ACTION=="add", KERNEL=="zram0"' > /mnt/etc/udev/rules.d/99-zram.rules
  printf ', ATTR{comp_algorithm}="zstd"' >> /mnt/etc/udev/rules.d/99-zram.rules
  : ", ATTR{disksize}=\"${size}Gib\", RUN=\"/usr/bin/mkswap -U clear /dev/%k\""
  printf '%s, TAG+="systemd"' "$_" >> /mnt/etc/udev/rules.d/99-zram.rules
  printf '/dev/zram0 none swap defaults,pri=100 0 0' >> /mnt/etc/fstab
# TODO: disable zswap
# add zswap.enabled=0 to kernel params
#
}

install_extra_packages() {
  :
}

generate_scripts() {
  local key i
  local -n opt
  opt=setopt_pairs
  exec {fd_log}>"${CACHE_DIR}/setup.log"
  # Check options
  for key in {MIRRORS,BLOCK_DEVICE};{
    [[ ${opt[$key]} == 'unset' ]] && { exit_prompt 'config'; return;}
  }
  for key in {ROOTPASS,USERNAME,USERPASS,HOSTNAME};{
    [[ -z "${opt[$key]}" ]] && { exit_prompt 'config'; return;}
  }
  for ((i=0;i<${#BLOCK_DEVICE[@]};i++)){
    key="${BLOCK_DEVICE[$i]}"
    [[ "$key" == "${opt[BLOCK_DEVICE]}"* ]] && {
      ((i=${opt[ROOT_VOLUME_SIZE]%GiB})); ((i+=${opt[HOME_VOLUME_SIZE]%GiB}))
      : "${key##* }"; : "${_%.*}"
      (($_<i)) && { exit_prompt 'config'; return;} || break
    }
  }
  setup_partitions >&$fd_log 2>&1
  setup_mirrors >&$fd_log 2>&1
  strapon
  setup_localisation
  setup_chroot
  exec {fd_log}>&-
  exit 0
}

