#!/bin/bash

if ! pacman -Qi systemd-cron >/dev/null 2>&1; then
    echo "systemd-cron is not installed. Installing..."
    sudo pacman -S systemd-cron
else
    echo "systemd-cron is already installed."
fi
