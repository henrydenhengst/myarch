#!/bin/bash
#
# >>> THIS SCRIPT IS DEPENDING UPON: install_systemd_cron.sh <<<
#
# This script MUST be located here 
### /usr/local/bin/arch-auto-upgrade.sh
# in order to work properly with 
### install_systemd_cron.sh
#
# Prepare before running this script
#
# Make the script exacutable:
### chmod +x arch-auto-upgrade.sh
# Run this script:
### ./arch-auto-upgrade.sh
#
# Set variables
PACMAN_LOG="/var/log/pacman.log"
FLATPAK_LOG="/var/log/flatpak.log"
SNAP_LOG="/var/log/snap.log"
APPIMAGE_LOG="/var/log/appimage.log"
UPDATE_LOG="/var/log/update-script.log"

# Run updates
echo "Updating pacman packages..." >> "$UPDATE_LOG"
sudo pacman -Syu --noconfirm >> "$PACMAN_LOG" 2>&1

echo "Updating Flatpak packages..." >> "$UPDATE_LOG"
flatpak update -y >> "$FLATPAK_LOG" 2>&1

echo "Updating Snap packages..." >> "$UPDATE_LOG"
sudo snap refresh >> "$SNAP_LOG" 2>&1

echo "Updating AppImage packages..." >> "$UPDATE_LOG"
sudo /path/to/appimageupdatetool -ai >> "$APPIMAGE_LOG" 2>&1

# Log completion message
echo "Auto-update script completed successfully at $(date)" >> "$UPDATE_LOG"

#!/bin/bash

# Make sure Flatpak and Snap are installed
if ! command -v flatpak &> /dev/null
then
    echo "$(date +"%Y-%m-%d %T"): Flatpak is not installed. Installing..." >> $FLATPAK_LOG
    sudo pacman -S flatpak --noconfirm >> $FLATPAK_LOG
    flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> $FLATPAK_LOG
else
    echo "$(date +"%Y-%m-%d %T"): Flatpak is already installed." >> $FLATPAK_LOG
fi

if ! command -v snap &> /dev/null
then
    echo "$(date +"%Y-%m-%d %T"): Snap is not installed. Installing..." >> $SNAP_LOG
    sudo pacman -S snapd --noconfirm >> $SNAP_LOG
    sudo systemctl enable --now snapd.socket >> $SNAP_LOG
else
    echo "$(date +"%Y-%m-%d %T"): Snap is already installed." >> $SNAP_LOG
fi

# Make sure appimageupdatetool is installed
if ! command -v appimageupdatetool &> /dev/null
then
    echo "$(date +"%Y-%m-%d %T"): appimageupdatetool is not installed. Installing..." >> $APPIMAGE_LOG
    sudo pacman -S appimagetool --noconfirm >> $APPIMAGE_LOG
else
    echo "$(date +"%Y-%m-%d %T"): appimageupdatetool is already installed." >> $APPIMAGE_LOG
fi

# Refresh pacman keys and upgrade the system
echo "Refreshing pacman keys and upgrading the system..."
sudo pacman-key --refresh-keys
sudo pacman -Syyu --noconfirm

# Check for invalid signatures in pacman packages
echo "Checking for invalid signatures in pacman packages..."
if ! pacman-key --check-sig || ! pacman-key --check-trust; then
  echo "Some package signatures are invalid. Fixing..."
  sudo pacman-key --populate archlinux
fi

# Check for upgrades to the Arch Linux package base and base-devel group
echo "Checking for upgrades to the Arch Linux package base and base-devel group..."
if sudo pacman -Syyu --noconfirm base base-devel; then
  echo "Upgrades to the Arch Linux package base and base-devel group installed successfully."
else
  echo "Failed to install upgrades to the Arch Linux package base and base-devel group."
fi

# Check for orphaned packages and remove them
echo "Checking for orphaned packages and removing them..."
if sudo pacman -Qdtq | sudo pacman -Rs - --noconfirm; then
  echo "Orphaned packages removed successfully."
else
  echo "Failed to remove orphaned packages."
fi

# Remove leftover files from previous installations/upgrades
echo "Removing leftover files from previous installations/upgrades..."
if sudo pacman -Sc --noconfirm; then
  echo "Leftover files removed successfully."
else
  echo "Failed to remove leftover files."
fi

# Update and upgrade flatpak packages
echo "Updating flatpak packages..."
flatpak update -y --user

# Check for invalid signatures in flatpak packages
echo "Checking for invalid signatures in flatpak packages..."
if ! flatpak repair --user; then
  echo "Some package signatures are invalid. Fixing..."
  flatpak repair -y --user
fi

# Update and upgrade snap packages
echo "Updating snap packages..."
sudo snap refresh

# Update and upgrade appimage packages
echo "Updating appimage packages..."
cd ~/Applications/
find . -name '*.AppImage' -exec sh -c '{}' --update \;

echo "All updates complete!"
