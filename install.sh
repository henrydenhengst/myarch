#!/bin/bash
#  _____       _____           _       ____   _____ 
# |  __ \     / ____|         | |     / __ \ / ____|
# | |__) |___| |    _   _  ___| | ___| |  | | (___  
# |  _  // _ \ |   | | | |/ __| |/ _ \ |  | |\___ \ 
# | | \ \  __/ |___| |_| | (__| |  __/ |__| |____) |
# |_|  \_\___|\_____\__, |\___|_|\___|\____/|_____/ 
#                    __/ |                          
#                   |___/                           
# 
#========================================================================================
#
#          FILE:  install.sh
#
#         USAGE:  curl -s https://raw.githubusercontent.com/henrydenhengst/myarch/main/install.sh | bash
#
#   DESCRIPTION:  Arch Linux Unattended Install
#
#       OPTIONS:  Edit the script to your needs.
#  REQUIREMENTS:  An intel / amd 64 computer - >4 GB Memory - >20 GB HDD - Arch-linux ISO
#          BUGS:  ---
#         NOTES:  Boot latest Arch-Linux ISO and run script, done!
#        AUTHOR:  Henry den Hengst , henrydenhengst@gmail.com
#       COMPANY:  QualityReloaded
#       VERSION:  0.01
#       CREATED:  20-04-2023
#      REVISION:  ---
#========================================================================================
set -e

# CHECK !!!

# Check for internet connectivity
if ! ping -q -c 1 -W 1 google.com > /dev/null; then
    echo "Error: No internet connection detected. Please connect to a network and try again."
    exit 1
fi

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root." 
   exit 1
fi

# DISK !!!

# Retrieve the name of the installation disk
INSTALL_DISK=$(lsblk -dpno NAME $(mount | awk '$3 == "/" {print $1}') | head -n1)

# List available disks and retrieve the names of all disks except the installation disk
ALL_DISKS=$(lsblk -dpno NAME | grep -v "^${INSTALL_DISK}$")

# Partition and format all disks except the installation disk
for DISK in $ALL_DISKS
do
  parted -s /dev/$DISK mklabel gpt
  parted -s /dev/$DISK mkpart primary btrfs 0% 100%
  mkfs.btrfs /dev/${DISK}1
done

# Mount all BTRFS partitions
mkdir /mnt/btrfs
mount -t btrfs $(lsblk -dpno NAME | grep -v "^${INSTALL_DISK}$" | awk '{print "/dev/"$1"1"}') /mnt/btrfs

# CHROOT BASE !!!

# Install the base system
pacstrap /mnt base base-devel linux linux-firmware

# Generate an fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the newly installed system
arch-chroot /mnt <<EOF

# Set the hostname
echo "myhostname" > /etc/hostname

# Set the timezone
ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime

# Set the locale
echo "nl_NL.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=nl_NL.UTF-8" > /etc/locale.conf

# Set the network configuration
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 myhostname.localdomain myhostname" >> /etc/hosts
systemctl enable dhcpcd.service

# Set up basic system configuration
echo "myhostname" > /etc/hostname
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
sed -i '/en_US.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "FONT=Lat2-Terminus16" >> /etc/vconsole.conf

# INSTALL !!!

# Install Additional tools
pacman -S --noconfirm vim wget curl reflector xorg networkmanager efibootmgr dosfstools os-prober mtools linux-lts linux-lts-headers p7zip p7zip-plugins unrar tar rsync pacman-contrib xdg-user-dirs ufw

# Install Codecs and plugins
pacman -S --noconfirm a52dec faac faad2 flac jasper lame libdca libdv libmad libmpeg2 libtheora libvorbis libxv wavpack x264 xvidcore gstreamer0.10-plugins exfat-utils fuse-exfat gst-libav libmad libmpeg2 libdvdcss libdvdread libdvdnav gecko-mediaplayer dvd+rw-tools dvdauthor dvgrab

# Installing Productive software
pacman -S --noconfirm libreoffice-fresh thunderbird firefox geany vlc

# Installing fonts, spell-checking dictionaries, java, and others...
pacman -S --noconfirm enchant mythes-en ttf-liberation hunspell-en_US ttf-bitstream-vera pkgstats adobe-source-sans-pro-fonts gst-plugins-good ttf-droid ttf-dejavu aspell-en icedtea-web gst-libav ttf-ubuntu-font-family ttf-anonymous-pro jre8-openjdk languagetool libmythes 

# Install CUPS and related packages
pacman -S cups cups-filters ghostscript gutenprint foomatic-db foomatic-db-ppds

# Enable and start the CUPS service
systemctl enable cups.service
systemctl start cups.service

# Add user to the lpadmin group to allow administration of printers
usermod -aG lpadmin $(whoami)

# Install printer drivers for HP, Brother, Canon and Epson printers
pacman -S hplip brother-printer-driver laserjet cpd220cnc

# Install CUPS-PDF printer driver for printing to PDF
pacman -S cups-pdf

# Restart the CUPS service to apply changes
systemctl restart cups.service

# Enable NetworkManager
systemctl enable NetworkManager.service
systemctl start NetworkManager.service

# Enable Network Time Protocols 
timedatectl set-ntp true
hwclock --systohc

# Install and configure GRUB bootloader
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Install and configure additional packages, such as display manager and desktop environment
pacman -S gnome
systemctl enable gdm.service

# Install a consistent dark theme for GRUB, GDM, and GNOME

# Set variables
THEME_NAME="Sweet-Dark"
THEME_URL="https://github.com/EliverLara/Sweet/releases/download/v2.0.0/Sweet-Dark.tar.xz"
THEME_DIR="/usr/share/themes"

# Install dependencies
pacman -S --noconfirm wget tar

# Download and extract theme files
cd /tmp
wget $THEME_URL
tar -xf Sweet-Dark.tar.xz -C $THEME_DIR

# Configure GRUB theme
mkdir -p /boot/grub/themes/$THEME_NAME
cp -r $THEME_DIR/$THEME_NAME/grub/* /boot/grub/themes/$THEME_NAME/
sed -i "s/GRUB_THEME=.*/GRUB_THEME=\"\/boot\/grub\/themes\/$THEME_NAME\/theme.txt\"/g" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Configure GDM theme
cp -r $THEME_DIR/$THEME_NAME/gnome-shell/* /usr/share/gnome-shell/theme/
sed -i "s/^icon-theme-name.*/icon-theme-name=$THEME_NAME/g" /usr/share/gnome-shell/theme/gdm3.css

# Configure GNOME theme
gsettings set org.gnome.desktop.interface gtk-theme $THEME_NAME
gsettings set org.gnome.desktop.wm.preferences theme $THEME_NAME
gsettings set org.gnome.desktop.interface icon-theme $THEME_NAME

echo "Done!"

# Install An AUR Helper
pacman -S base-devel git --needed 
cd paru
makepkg -si
cd ~

# User account creation
read -p "Enter the username for the new user: " username
useradd -m -s /bin/bash "$username"
passwd "$username"
usermod -aG sudo,lpadmin,wheel,storage,power,adm,cdrom,video,audio "$username"
echo "User account created successfully"

# Define a list of packages that contain drivers
driver_packages=("linux" "linux-firmware" "nvidia" "amd-ucode")

# Loop through each package and check if it is installed
for package in "${driver_packages[@]}"
do
  if ! pacman -Qs $package > /dev/null ; then
    echo "Package $package is not installed, installing now..."
    pacman -S $package --noconfirm
  fi
done
echo "All required drivers are installed."

# Check if systemd-cron is installed and enable/start the service
if ! pacman -Qi systemd-cron >/dev/null 2>&1; then
    echo "systemd-cron is not installed. Installing..."
    pacman -S systemd-cron
    echo "Enabling and starting systemd-cron service..."
    systemctl enable systemd-cron.service
    systemctl start systemd-cron.service
else
    echo "systemd-cron is already installed."
    if ! systemctl is-enabled --quiet systemd-cron.service; then
        echo "Enabling systemd-cron service..."
        systemctl enable systemd-cron.service
    fi
    if ! systemctl is-active --quiet systemd-cron.service; then
        echo "Starting systemd-cron service..."
        systemctl start systemd-cron.service
    fi
fi

wget -c https://raw.githubusercontent.com/henrydenhengst/myarch/main/arch-auto-upgrade.sh
mv arch-auto-upgrade.sh /usr/local/bin/arch-auto-upgrade.sh
chmod +x /usr/local/bin/arch-auto-upgrade.sh

# Check if update-script.service file exists with correct content and create it if missing
UPDATE_SCRIPT_SERVICE="/etc/systemd/system/update-script.service"
UPDATE_SCRIPT_CONTENT="[Unit]\nDescription=Auto-update script\n\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/arch-auto-upgrade.sh\nRemainAfterExit=true\n\n[Install]\nWantedBy=multi-user.target\n"
if [[ ! -f "$UPDATE_SCRIPT_SERVICE" ]] || ! grep -q "$UPDATE_SCRIPT_CONTENT" "$UPDATE_SCRIPT_SERVICE"; then
    echo "Creating $UPDATE_SCRIPT_SERVICE file..."
    echo -e "$UPDATE_SCRIPT_CONTENT" | tee "$UPDATE_SCRIPT_SERVICE" >/dev/null
    chmod +x /usr/local/bin/arch-auto-upgrade.sh
else
    echo "$UPDATE_SCRIPT_SERVICE file already exists with correct content."
fi

# Backup existing mirror list
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

# Use reflector to select the 10 most recently updated mirrors, sorted by download speed
reflector --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist \
--country Netherlands --country Belgium --country Germany --country UK

# Configure reflector to update mirrorlist weekly
tee /etc/systemd/system/mirrorlist-update.timer <<EOF
[Unit]
Description=Weekly update of pacman mirrorlist

[Timer]
OnCalendar=weekly
AccuracySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

tee /etc/systemd/system/mirrorlist-update.service <<EOF
[Unit]
Description=Update pacman mirrorlist

[Service]
Type=oneshot
ExecStart=/bin/bash -c "reflector --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist --country Netherlands --country Belgium --country Germany --country UK"
EOF

systemctl daemon-reload
systemctl enable --now mirrorlist-update.timer

echo "Mirror selection complete."

# Automatic cleaning the package cache by activating the paccache timer
systemctl enable paccache.timer
systemctl start paccache.timer

# Create user directory folders
xdg-user-dirs-update

# Enable Firewall
ufw enable

EOF

# Reboot the system
umount -R /mnt
reboot
