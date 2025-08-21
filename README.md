# Arch Linux Turnkey Installer

Een volledig geautomatiseerd Arch Linux installatie script met Cinnamon desktop, SDDM, volledige disk encryptie en extra apps. Geschikt voor laptops en desktops. Het script detecteert automatisch hardware, configureert drivers en services, en vraagt alleen om minimale input (doelschijf, gebruikersnaam, wachtwoord en hostname).

---

# Kenmerken

Detecteert hardware (CPU, GPU, laptop/desktop)

Volledige disk encryptie met LUKS2 en Btrfs root

Partitionering met EFI bootpartitie

Cinnamon Desktop Environment + SDDM

Gebruiker met sudo, root-account gelocked

Laptop-specifieke services (TLP, ACPI, powertop)

Desktop-specifieke services (QEMU, libvirt)

Extra apps: Firefox, Terminator, Kitty, Neofetch, Btop, Timeshift, Pipewire, Bluetooth, printing

Firewall ingeschakeld met UFW

Automatische locale en tijdzone configuratie

Hostname automatisch ingesteld afhankelijk van type systeem

---

# Vereisten

Arch Linux ISO, opgestart in live omgeving

Internetverbinding

Minimaal één interne schijf voor installatie

root toegang in live omgeving

---

# Gebruik

1. Boot de computer vanaf de Arch Linux ISO.


2. Zorg dat het systeem verbonden is met het internet.


3. Mount het script op de live omgeving (bijv. via USB of wget/curl).

4. Start het script:

chmod +x arch_installer.sh

sudo ./arch_installer.sh

5. Volg de prompts:

Doelschijf (default: eerste interne schijf)

Gebruikersnaam (default: gebruiker)

Wachtwoord (default: gebruiker12345)

Hostname (default: laptop/netwerk afhankelijk)


6. Het script voert automatisch de rest uit: partitioneren, encryptie, base install, desktop environment, drivers, extra apps, firewall, en systeemdiensten.


7. Na voltooiing, unmount en reboot:


[+] Installatie voltooid! Herstart nu je computer.

---

# Tips

Zorg dat je een back-up hebt van alle gegevens op de doelschijf, omdat deze volledig wordt gewist.

De installatie vereist internet, zorg dat NetworkManager actief is in de live omgeving.

Het script detecteert hardware automatisch en installeert relevante drivers voor Intel, AMD en NVIDIA GPU’s.

Voor laptops worden extra power- en batterijtools geïnstalleerd.

---

# Aanpassen

Default username en wachtwoord kun je wijzigen door de variabelen bovenaan het script aan te passen.

Extra applicaties kunnen worden toegevoegd in het gedeelte # Extra apps in het script.

Tijdzone en locale zijn momenteel ingesteld op Europe/Amsterdam en en_US.UTF-8, deze kunnen aangepast worden in het script.

