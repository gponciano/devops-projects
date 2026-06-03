#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail


VM_NAME="Ubuntu_26_04_LTS"
VM_DIR="$HOME/VirtualBox VMs/$VM_NAME"
ISO_DIR="$HOME/Downloads"
ISO_FILE="$ISO_DIR/ubuntu-26.04-desktop-amd64.iso"
ISO_URL="https://ubuntu.com"

# VM Hardware allocations
RAM_MB=4096       # 4 GB RAM (Minimum requirement)
CPU_CORES=2       # 2 CPU Cores
VRAM_MB=128       # Video Memory
DISK_GB=40        # 40 GB Hard Drive space

# Unattended Installation parameters (VirtualBox 7+)
GUEST_USER="vboxuser"
GUEST_PASS="VBoxPassword2026!"
GUEST_HOSTNAME="ubuntu-vm"

# ==========================================
# 2. DOWNLOAD UBUNTU ISO
# ==========================================
if [ ! -f "$ISO_FILE" ]; then
    echo "Downloading Ubuntu ISO to $ISO_FILE..."
    mkdir -p "$ISO_DIR"
    curl -L -o "$ISO_FILE" "$ISO_URL"
else
    echo "Ubuntu ISO already exists. Skipping download."
fi

# ==========================================
# 3. CREATE & REGISTER VIRTUAL MACHINE
# ==========================================
echo "Creating Virtual Machine: $VM_NAME..."
VBoxManage createvm --name "$VM_NAME" --ostype "Ubuntu_64" --register

# ==========================================
# 4. CONFIGURE VM HARDWARE
# ==========================================
echo "Configuring CPU, Memory, and Graphics..."
VBoxManage modifyvm "$VM_NAME" \
    --cpus $CPU_CORES \
    --memory $RAM_MB \
    --vram $VRAM_MB \
    --graphicscontroller vmsvga \
    --biostype legacy \
    --boot1 dvd --boot2 disk --boot3 none --boot4 none \
    --nic1 nat

# ==========================================
# 5. CREATE VIRTUAL STORAGE & ATTACH ISO
# ==========================================
echo "Creating 40GB virtual storage disk..."
VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci
VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide

# Create the virtual hard disk (VDI)
VBoxManage createmedium disk \
    --filename "$VM_DIR/$VM_NAME.vdi" \
    --size $((DISK_GB * 1024)) \
    --format VDI

# Attach hard disk to SATA controller
VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA Controller" \
    --port 0 --device 0 \
    --type hdd \
    --medium "$VM_DIR/$VM_NAME.vdi"

# Attach Ubuntu installation ISO to IDE controller
VBoxManage storageattach "$VM_NAME" \
    --storagectl "IDE Controller" \
    --port 0 --device 0 \
    --type dvddrive \
    --medium "$ISO_FILE"

# ==========================================
# 6. SETUP UNATTENDED INSTALLATION
# ==========================================
echo "Setting up unattended installation parameters..."
VBoxManage guestcontrol "$VM_NAME" unattended install \
    --iso="$ISO_FILE" \
    --user="$GUEST_USER" \
    --password="$GUEST_PASS" \
    --hostname="$GUEST_HOSTNAME" \
    --country="US" \
    --time-zone="UTC" \
    --install-guest-additions

# ==========================================
# 7. START THE VIRTUAL MACHINE
# ==========================================
echo "Configuration complete!"
echo "Starting VM in headless background mode..."
VBoxManage startvm "$VM_NAME" --type headless

echo "--------------------------------------------------------"
echo "VM '$VM_NAME' is now running and installing Ubuntu!"
echo "Username: $GUEST_USER"
echo "Password: $GUEST_PASS"
echo "--------------------------------------------------------"
echo "To view your VM GUI, run: VBoxManage startvm \"$VM_NAME\""
echo "To check status, run: VBoxManage list runningvms"

# ==========================================
# 8. ADDITIONAL CONFIGURATION
# ==========================================
echo "########################################"
echo "Installing packages."
echo "########################################"
sudo apt update && sudo apt upgrade -y > /dev/null
sudo apt install git curl ufw fail2ban unattended-upgrades -y > /dev/null
echo

echo "########################################"
echo "Adding user"
echo "########################################"
sudo useradd -m -s /bin/bash devops
echo "devops:YourSecurePassword123" | sudo chpasswd > /dev/null
sudo adduser devops sudo
sudo ufw allow ssh && sudo ufw allow http && sudo ufw allow https && sudo ufw enable
