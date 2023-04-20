#!/bin/bash
#
# After running this script is is advised to run as a crontab: arch-auto-upgrade.sh
#

# Check if systemd-cron is installed and enable/start the service
if ! pacman -Qi systemd-cron >/dev/null 2>&1; then
    echo "systemd-cron is not installed. Installing..."
    sudo pacman -S systemd-cron
    echo "Enabling and starting systemd-cron service..."
    sudo systemctl enable systemd-cron.service
    sudo systemctl start systemd-cron.service
else
    echo "systemd-cron is already installed."
    if ! systemctl is-enabled --quiet systemd-cron.service; then
        echo "Enabling systemd-cron service..."
        sudo systemctl enable systemd-cron.service
    fi
    if ! systemctl is-active --quiet systemd-cron.service; then
        echo "Starting systemd-cron service..."
        sudo systemctl start systemd-cron.service
    fi
fi

# Check if update-script.service file exists with correct content and create it if missing
UPDATE_SCRIPT_SERVICE="/etc/systemd/system/update-script.service"
UPDATE_SCRIPT_CONTENT="[Unit]\nDescription=Auto-update script\n\n[Service]\nType=oneshot\nExecStart=/path/to/update-script\nRemainAfterExit=true\n\n[Install]\nWantedBy=multi-user.target\n"
if [[ ! -f "$UPDATE_SCRIPT_SERVICE" ]] || ! grep -q "$UPDATE_SCRIPT_CONTENT" "$UPDATE_SCRIPT_SERVICE"; then
    echo "Creating $UPDATE_SCRIPT_SERVICE file..."
    echo -e "$UPDATE_SCRIPT_CONTENT" | sudo tee "$UPDATE_SCRIPT_SERVICE" >/dev/null
else
    echo "$UPDATE_SCRIPT_SERVICE file already exists with correct content."
fi
