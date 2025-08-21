# myarch
Arch Linux Turnkey Installer

⚠️ Belangrijk

Dit script wist je hele doelschijf en installeert Arch volledig automatisch.

Controleer DISK variabele in het script (/dev/sda standaard).

Script is bedoeld om vanuit de Arch ISO live omgeving te draaien.

---

📦 Inhoud

Volledige disk encryptie (LUKS2).

Detectie hardware: CPU, GPU, laptop vs desktop.

Installatie van Cinnamon + SDDM.

Standaard apps: Firefox, Terminator, Kitty, Pipewire, Bluez, Timeshift, neofetch, en meer.

Laptop-specifieke services (TLP, ACPI).

Desktop-specifieke services (Libvirt, QEMU).

Root-account gelocked, gebruiker henry met sudo.

---

🖥️ Voorbereiding

1. Download de Arch ISO en boot de computer.


2. Open een terminal in de live omgeving.


3. Zorg dat de computer internet heeft (ping archlinux.org testen).


4. Kopieer het script naar de live omgeving, bijvoorbeeld:

curl -O https://mijnserver/arch-install.sh
chmod +x arch-install.sh

---

🚀 Script uitvoeren

sudo ./arch-install.sh

Het script detecteert hardware, partitioneert de schijf, zet encryptie op, installeert het systeem en configureert services.

Hostname, gebruiker en wachtwoord zijn automatisch ingesteld:

Laptop → laptop.netwerk.lan

Desktop → desktop.netwerk.lan

Gebruiker: henry

Wachtwoord: henry12345

---

🔧 Na installatie

1. Herstart de computer:

reboot


2. Verwijder de ISO/USB media.


3. Bij de eerste boot wordt gevraagd om de LUKS-passphrase (henry12345).


4. Cinnamon + SDDM start automatisch.


5. Alle services (NetworkManager, UFW, Pipewire, Bluetooth, TLP/acpid/libvirtd) zijn geactiveerd.

---

📌 Tips

Controleer na installatie de GPU-driver en display manager.

Pas eventuele extra apps aan via pacman.

Voor snapshots gebruik timeshift.

---



