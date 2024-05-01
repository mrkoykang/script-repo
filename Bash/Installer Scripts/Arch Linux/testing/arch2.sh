#!/usr/bin/env bash

GREEN='\033[0;32m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[LOG]${NC} $1"
}

USERNAME=""
USER_PASSWORD=""
ROOT_PASSWORD=""
COMPUTER_NAME=""
TIMEZONE="US/Eastern"
DISK=""

PARTITION_COUNT=3
PARTITION1_SIZE="500M"
PARTITION2_SIZE="2G"
PARTITION_SIZES=()
PARTITION_TYPES=()

help() {
    echo "Arch Linux Installation Script"
    echo "This script automates the installation of Arch Linux."
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -u USERNAME       Set the non-root username"
    echo "  -p USER_PASSWORD  Set the non-root user password"
    echo "  -r ROOT_PASSWORD  Set the root password"
    echo "  -c COMPUTER_NAME  Set the computer name"
    echo "  -t TIMEZONE       Set the timezone (default: US/Eastern)"
    echo "  -d DISK           Set the target disk (e.g., /dev/sdX or /dev/nvmeXn1)"
    echo "  -h                Display this help message"
    echo
    echo "Examples:"
    echo "  $0 -u john -p password123 -r rootpass -c myarch -t Europe/London -d /dev/sda"
    echo "  $0 -u jane -p pass456 -r rootpass789 -c janepc -d /dev/nvme0n1"
    exit 0
}

while getopts ":u:p:r:c:t:d:h" opt; do
    case "$opt" in
        u) USERNAME="$OPTARG" ;;
        p) USER_PASSWORD="$OPTARG" ;;
        r) ROOT_PASSWORD="$OPTARG" ;;
        c) COMPUTER_NAME="$OPTARG" ;;
        t) TIMEZONE="$OPTARG" ;;
        d) DISK="$OPTARG" ;;
        h) help ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1;;
    esac
done

prompt_variable() {
    local prompt var_name var_value
    var_name="$1"
    prompt="$2"
    var_value=$(eval echo \$var_name)
    while [[ -z "$var_value" ]]; do
        read -p "$prompt: " var_value
        eval $var_name="$var_value"
    done
}

prompt_variable USERNAME "Enter the non-root username"
prompt_variable USER_PASSWORD "Enter the non-root user password"
prompt_variable ROOT_PASSWORD "Enter the root password"
prompt_variable COMPUTER_NAME "Enter the computer name"
prompt_variable DISK "Enter the target disk (e.g., /dev/sda or /dev/nvme0n1)"

if [[ "$DISK" == *"nvme"* ]]; then
    DISK1="${DISK}p1"
    DISK2="${DISK}p2"
    DISK3="${DISK}p3"
else
    DISK1="${DISK}1"
    DISK2="${DISK}2"
    DISK3="${DISK}3"
fi

setup_disk() {
    local disk_parts end SIZE start type
    disk_parts=("$DISK1" "$DISK2" "$DISK3")

    read -p "Enter the number of partitions (minimum 3): " PARTITION_COUNT
    while [[ "$PARTITION_COUNT" -lt 3 ]]; do
        echo "The minimum number of partitions is 3."
        read -p "Enter the number of partitions (minimum 3): " PARTITION_COUNT
    done

    echo "Partition 1 will be set as GPT and EFI."
    read -p "Enter partition 1 SIZE (e.g., 550M): " PARTITION1_SIZE

    echo "Partition 2 will be set as swap."
    read -p "Enter partition 2 SIZE (e.g., 2G): " PARTITION2_SIZE

    for ((i=3; i<PARTITION_COUNT; i++)); do
        read -p "Enter SIZE for partition $i: " SIZE
        PARTITION_SIZES+=("$SIZE")

        echo "Available partition types:"
        echo
        echo "1 EFI System"
        echo "2 MBR Partition Scheme"
        echo "3 Intel Fast Flash"
        echo "4 BIOS Boot"
        echo "5 Sony Boot Partition"
        echo "6 Lenovo Boot Partition"
        echo "7 Microsoft Reserved"
        echo "8 Microsoft Basic Data"
        echo "9 Microsoft LDM Metadata"
        echo "10 Microsoft LDM Data"
        echo "11 Microsoft Recovery"
        echo "12 HP-UX Data"
        echo "13 HP-UX Service"
        echo "14 Linux Filesystem"
        echo "15 Linux Extended"
        echo "16 Linux LVM"
        echo "17 Linux Reserved"
        echo "18 Linux RAID"
        echo "19 Linux Swap"
        echo "20 Linux Filesystem"
        echo "21 Linux Server Data"
        echo "22 Linux Root (x86)"
        echo "23 Linux Root (x86-64)"
        echo "24 Linux Root (ARM)"
        echo "25 Linux Root (ARM-64)"
        echo "26 Linux Root (IA-64)"
        echo "27-81 Linux Reserved"
        echo "82 Linux Swap"
        echo "83 Linux"
        echo "84-85 Linux Extended"
        echo "86 NT FAT16"
        echo "87 NTFS"
        echo "88 Linux Plaintext"
        echo "89 Linux LVM"
        echo "90 Linux RAID"
        echo "91 Linux Extended"
        echo "92 Linux Swap"
        echo "93 Hidden Linux"
        echo "94 Linux Reserved"
        echo "95-97 Linux RAID Autodetect"
        echo "98 Linux Swap"
        echo "99 Linux LVM"
        read -p "Enter the partition type number for partition $i: " type
        PARTITION_TYPES+=("$type")
    done

    echo "The last partition will be set as Linux x86-64 root and use the remaining disk space."

    echo
    log "Partitioning disk $DISK..."
    parted -s "$DISK" mklabel gpt

    parted -s "$DISK" mkpart primary fat32 1 $(echo "$PARTITION1_SIZE" | sed 's/[^0-9]*//g')
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart primary linux-swap $(echo "$PARTITION1_SIZE" | sed 's/[^0-9]*//g') $(echo "$(echo "$PARTITION2_SIZE" | sed 's/[^0-9]*//g') * 1024" | bc)

    start=$(echo "$(echo "$PARTITION2_SIZE" | sed 's/[^0-9]*//g') * 1024" | bc)
    for ((i=0; i<${#PARTITION_SIZES[@]}; i++)); do
        SIZE=$(echo "$(echo "${PARTITION_SIZES[i]}" | sed 's/[^0-9]*//g') * 1024" | bc)
        end=$((start + SIZE))
        parted -s "$DISK" mkpart primary $start $end
        type=${PARTITION_TYPES[i]}
        case $type in
            1) parted -s "$DISK" set $((i+3)) esp on ;;
            2) parted -s "$DISK" set $((i+3)) bios_grub on ;;
            4) parted -s "$DISK" set $((i+3)) boot on ;;
            19) parted -s "$DISK" set $((i+3)) swap on ;;
        esac
        start=$end
    done

    parted -s "$DISK" mkpart primary $start 100%
    parted -s "$DISK" set $PARTITION_COUNT 23

    echo
    log "Creating filesystems..."

    mkfs.fat -F32 "$DISK1"
    mkswap "$DISK2"
    mkfs.ext4 "${DISK}${PARTITION_COUNT}"
}

mount_partitions() {
    log "Enabling swap and mounting partitions..."
    swapon "$DISK2"

    mount "${DISK}${PARTITION_COUNT}" /mnt
    mount --mkdir "$DISK1" /mnt/boot/efi
}

prompt_loadkeys() {
    local loadkeys_value
    while [[ -z "$loadkeys_value" ]]; do
        read -p "Enter the value for loadkeys (press 'l' to list available options): " loadkeys_value
        if [[ "$loadkeys_value" == "l" ]]; then
            echo "Available keymaps:"
            tempfile=$(mktemp)
            localectl list-keymaps > "$tempfile"
            more "$tempfile"
            rm "$tempfile"
            read -p "Enter the value for loadkeys: " loadkeys_value
            if [[ -n "$loadkeys_value" ]]; then
                loadkeys "$loadkeys_value"
            else
                echo "You must enter a value to continue. Press l to get a list of available options."
                echo
                read -p "Press enter to try again."
                prompt_loadkeys
            fi
        elif [[ -n "$loadkeys_value" ]]; then
            loadkeys "$loadkeys_value"
        else
            break
        fi
    done
}

install_packages() {
    local PACKAGES
    PACKAGES="base efibootmgr linux linux-firmware linux-headers nano networkmanager os-prober reflector sudo"
    echo
    log "Installing essential packages..."
    echo "Current package list: $PACKAGES"
    echo
    read -p "Enter to continue or, add additional packages to install (spaced separated) with the ability to remove a package by prefixing it with a minus sign '-': " add_pkgs
    for pkgs in $add_pkgs; do
        if [[ "$package" == -* ]]; then
            PACKAGES=$(echo "$PACKAGES" | sed "s/${pkgs#-}//g")
        else
            PACKAGES+=" $package"
        fi
    done
    pacstrap -K /mnt $PACKAGES
}

# After disk and partitions are configured, fetch the PARTUUID
PARTUUID=$(blkid -s PARTUUID -o value "${DISK3}") # Adjust as needed to target the correct root partition
export PARTUUID

configure_chroot() {
    log "Entering chroot to configure system..."
    arch-chroot /mnt /bin/bash -c "
ln -sf '/usr/share/zoneinfo/$TIMEZONE' /etc/localtime;
hwclock --systohc;
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen;
locale-gen;
echo 'LANG=en_US.UTF-8' > /etc/locale.conf;
echo '$COMPUTER_NAME' > /etc/hostname;
mkinitcpio -P;
echo '127.0.1.1 myarch.localdomain $COMPUTER_NAME' >> /etc/hosts;
echo root:'$ROOT_PASSWORD' | chpasswd;
useradd -m -G wheel -s /bin/bash $USERNAME;
echo '$USERNAME:$USER_PASSWORD' | chpasswd;
echo '' >> /etc/sudoers;
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers;
bootctl --path=/boot/efi install;
echo 'default arch.conf' > /boot/efi/loader/loader.conf;
echo 'timeout 4' >> /boot/efi/loader/loader.conf;
echo 'console-mode max' >> /boot/efi/loader/loader.conf;
echo 'editor no' >> /boot/efi/loader/loader.conf;
echo 'title Arch Linux' > /boot/efi/loader/entries/arch.conf;
echo 'linux /vmlinuz-linux' >> /boot/efi/loader/entries/arch.conf;
echo 'initrd /initramfs-linux.img' >> /boot/efi/loader/entries/arch.conf;
echo 'options root=PARTUUID=$PARTUUID rw' >> /boot/efi/loader/entries/arch.conf;
systemctl enable NetworkManager.service;
systemctl start NetworkManager.service;
"
}

prompt_umount() {
    local choice
    clear
    read -p "Installation complete. Do you want to unmount all partitions? (y/n): " choice
    case "$choice" in
        [yY]*|[yY][eE][sS]*)
            log "Unmounting all partitions..."
            umount -R /mnt
            swapoff -a
            break
            ;;
        [nN]*|[nN][oO]*)
            break
            ;;
        *)  unset choice
            prompt_umount
            ;;
    esac
}

prompt_reboot() {
    local choice
    clear
    read -p "Do you want to reboot now? (y/n): " choice
    case "$choice" in
        [yY]*|[yY][eE][sS]*)
            reboot
            break
            ;;
        [nN]*|[nN][oO]*)
            break
            exit
            ;;
        *)  unset choice
            prompt_reboot
            ;;
    esac
}

main() {
    log "Starting installation..."
    prompt_loadkeys
    timedatectl set-ntp true
    log "System clock synchronized."

    setup_disk
    mount_partitions
    install_packages

    echo
    log "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab

    configure_chroot
    prompt_umount
    prompt_reboot
}

main
