#!/bin/bash




# VM_NAME="Ubuntu_Test"
# VM_DIR="$HOME/VirtualBox VMs/$VM_NAME"
# ISO_DIR="$HOME/Downloads"
# ISO_FILE="$ISO_DIR/ubuntu-26.04-desktop-amd64.iso"
# ISO_URL="https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
# VBOX_DIR="C:/Program Files/Oracle/VirtualBox"

# # VM Hardware allocations
# RAM_MB=4096       # 4 GB RAM (Minimum requirement)
# CPU_CORES=2       # 2 CPU Cores
# VRAM_MB=128       # Video Memory
# DISK_GB=40        # 40 GB Hard Drive space

# # Unattended Installation parameters (VirtualBox 7+)
# GUEST_USER="vboxuser"
# GUEST_PASS="VBoxPassword2026!"
# GUEST_HOSTNAME="ubuntu-vm"

# # ==========================================
# # 2. DOWNLOAD UBUNTU ISO
# # ==========================================
# if [ ! -f "$ISO_FILE" ]; then
#     echo "Downloading Ubuntu ISO to $ISO_FILE..."
#     mkdir -p "$ISO_DIR"
#     curl -L -o "$ISO_FILE" "$ISO_URL"
# else
#     echo "Ubuntu ISO already exists. Skipping download."
# fi

# # ==========================================
# # 3. CREATE & REGISTER VIRTUAL MACHINE
# # ==========================================
# echo "Creating Virtual Machine: $VM_NAME..."

# "$VBOX_DIR/VBoxManage.exe" createvm --name "$VM_NAME" --ostype "Ubuntu_64" --register

# # ==========================================
# # 4. CONFIGURE VM HARDWARE
# # ==========================================
# echo "Configuring CPU, Memory, and Graphics..."

# "$VBOX_DIR/VBoxManage.exe" modifyvm "$VM_NAME" \
#     --cpus $CPU_CORES \
#     --memory $RAM_MB \
#     --vram $VRAM_MB \
#     --graphicscontroller vmsvga \
#     --boot1 dvd --boot2 disk --boot3 none --boot4 none \
#     --nic1 nat

# # ==========================================
# # 5. CREATE VIRTUAL STORAGE & ATTACH ISO
# # ==========================================
# echo "Creating 40GB virtual storage disk..."

# "$VBOX_DIR/VBoxManage.exe" storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci

# "$VBOX_DIR/VBoxManage.exe" storagectl "$VM_NAME" --name "IDE Controller" --add ide

# # Create the virtual hard disk (VDI)

# "$VBOX_DIR/VBoxManage.exe" createmedium disk \
#     --filename "$VM_DIR/$VM_NAME.vdi" \
#     --size $((DISK_GB * 1024)) \
#     --format VDI

# # Attach hard disk to SATA controller

# "$VBOX_DIR/VBoxManage.exe" storageattach "$VM_NAME" \
#     --storagectl "SATA Controller" \
#     --port 0 --device 0 \
#     --type hdd \
#     --medium "$VM_DIR/$VM_NAME.vdi"

# # Attach Ubuntu installation ISO to IDE controller

# "$VBOX_DIR/VBoxManage.exe" storageattach "$VM_NAME" \
#     --storagectl "IDE Controller" \
#     --port 0 --device 0 \
#     --type dvddrive \
#     --medium "$ISO_FILE"

# # ==========================================
# # 6. SETUP UNATTENDED INSTALLATION
# # ==========================================
# echo "Setting up unattended installation parameters..."

# "$VBOX_DIR/VBoxManage.exe" guestcontrol "$VM_NAME" unattended install \
#     --iso="$ISO_FILE" \
#     --user="$GUEST_USER" \
#     --password="$GUEST_PASS" \
#     --hostname="$GUEST_HOSTNAME" \
#     --country="US" \
#     --time-zone="UTC" \
#     --install-guest-additions

# # ==========================================
# # 7. START THE VIRTUAL MACHINE
# # ==========================================
# echo "Configuration complete!"
# echo "Starting VM in headless background mode..."

# "$VBOX_DIR/VBoxManage.exe" startvm "$VM_NAME" --type headless

# echo "--------------------------------------------------------"
# echo "VM '$VM_NAME' is now running and installing Ubuntu!"
# echo "Username: $GUEST_USER"
# echo "Password: $GUEST_PASS"
# echo "--------------------------------------------------------"
# echo "To view your VM GUI, run: VBoxManage startvm \"$VM_NAME\""
# echo "To check status, run: VBoxManage list runningvms"

# ==========================================
# 8. ADDITIONAL CONFIGURATION
# ==========================================

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

if (( EUID != 0 )); then
    echo "Error: This script must be run as root or with sudo." >&2
    exit 1
fi

echo "########################################"
echo "Installing packages."
echo "########################################"
apt update && apt upgrade -y
apt install git curl ufw fail2ban unattended-upgrades -y
echo

echo "########################################"
echo "Adding user"
echo "########################################"

NEW_USER="devops"
PASSWORD=$(openssl rand -base64 12)

# Check if the user already exists using the id command
# TRACK USER CREATION
user_created=false

if id "$NEW_USER" &>/dev/null; then
    echo "Notice: User '$NEW_USER' already exists. Skipping creation."
else
    echo "Creating user '$NEW_USER'..."

    useradd -m -s /bin/bash "$NEW_USER"
    echo "$NEW_USER:$PASSWORD" | chpasswd

    user_created=true

    echo "User: $NEW_USER | Password: $PASSWORD"
fi
adduser "$NEW_USER" sudo


ufw allow ssh && ufw allow http && ufw allow https
ufw_active=false
if ufw status | grep -qw active; then
    ufw_active=true
else 
    ufw enable
    ufw_active=true
fi

#==========================================
#SUMMARY
#==========================================
declare -A package_status

PACKAGES=("git" "curl" "ufw" "fail2ban" "unattended-upgrades")

for package in "${PACKAGES[@]}"; do
    if dpkg -s "$package" >/dev/null 2>&1; then
        package_status["$package"]=true
    else
        package_status["$package"]=false
    fi
done

echo
echo "===== Installed Packages ====="

for package in "${PACKAGES[@]}"; do
    if ${package_status[$package]}; then
        echo "✓ $package"
    else
        echo "✗ $package"
    fi
done

echo "===== System Summary ====="

if $user_created; then
    echo "✓ User '$NEW_USER' was created"
else
    echo "ℹ User '$NEW_USER' already existed"
fi

if $ufw_active; then
    echo "✓ Firewall is active"
else
    echo "✗ Firewall is NOT active"
fi

echo
echo "Done provisioning system."