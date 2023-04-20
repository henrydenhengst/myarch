#!/bin/bash

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Define a list of packages that contain drivers
driver_packages=("linux" "linux-firmware" "nvidia" "amd-ucode")

# Loop through each package and check if it is installed
for package in "${driver_packages[@]}"
do
  if ! pacman -Qs $package > /dev/null ; then
    echo "Package $package is not installed, installing now..."
    sudo pacman -S $package --noconfirm
  fi
done

echo "All required drivers are installed."
