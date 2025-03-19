#!/bin/bash

# Enable error handling and logging
set -e
exec > >(tee -a /var/log/windows_install.log) 2>&1

# Update system and install required packages
echo "Updating system and installing required packages..."
export DEBIAN_FRONTEND=noninteractive
apt update -y && apt upgrade -y
apt install -y grub2 wimtools ntfs-3g parted rsync wget

# Verify disk name (use /dev/vda for some VPS providers)
disk=$(lsblk -d -o NAME | grep -E '^(s|v)d[a-z]$' | head -n 1)
if [[ -z "$disk" ]]; then
    echo "No physical disk found. Exiting."
    exit 1
fi
echo "Using disk: /dev/$disk"

# Get the disk size in GB and convert to MB
disk_size_gb=$(parted /dev/$disk --script print | awk '/^Disk \/dev\/'"$disk"':/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))

# Ensure disk is large enough for Windows (minimum 32 GB)
min_size_gb=32
if [[ $disk_size_gb -lt $min_size_gb ]]; then
    echo "Disk size is too small. Minimum required: $min_size_gb GB."
    exit 1
fi

# Calculate partition size (25% of total size)
part_size_mb=$((disk_size_mb / 4))

# Create GPT partition table
echo "Creating GPT partition table on /dev/$disk..."
parted /dev/$disk --script mklabel gpt

# Unmount any existing partitions on the disk
echo "Unmounting existing partitions on /dev/$disk..."
for partition in $(lsblk -o NAME -n /dev/$disk | grep -E '^'"$disk"'[0-9]+'); do
    umount -l /dev/$partition || true
done

# Create two partitions:
#  - Partition 1: from 1MB to 25% of the disk (for Windows installation files)
#  - Partition 2: from 25% to 50% of the disk (used as working area)
echo "Creating partitions..."
parted /dev/$disk --script mkpart primary ntfs 1MB ${part_size_mb}MB
parted /dev/$disk --script mkpart primary ntfs ${part_size_mb}MB $((2 * part_size_mb))MB

# Inform kernel of partition table changes
echo "Updating kernel partition table..."
partprobe /dev/$disk
sleep 5

# Format the partitions as NTFS
echo "Formatting partitions as NTFS..."
mkfs.ntfs -f /dev/${disk}1
mkfs.ntfs -f /dev/${disk}2

echo "NTFS partitions created."

# Mount partitions:
#  - /dev/sda1 will host the Windows installation files
#  - /dev/sda2 will be used as a working directory
echo "Mounting partitions..."
mount /dev/${disk}1 /mnt
mkdir -p /root/windisk
mount /dev/${disk}2 /root/windisk

# Install GRUB bootloader
echo "Installing GRUB bootloader..."
grub-install --target=i386-pc --root-directory=/mnt /dev/$disk

# Edit GRUB configuration to chainload Windows boot manager
echo "Configuring GRUB..."
mkdir -p /mnt/boot/grub
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "Windows Installer" {
    insmod part_gpt
    insmod ntfs
    set root='hd0,gpt1'
    chainloader +1
}
EOF

# Download the Windows ISO
echo "Downloading Windows ISO..."
cd /root/windisk
mkdir -p winfile
wget -O /root/windisk/Windows_SERVER_2022_NTLite.iso "https://www.dropbox.com/scl/fi/kjvjlmhbt8fbwa9zxmke2/Windows_SERVER_2022_NTLite.iso?rlkey=2qrb3egcnec7wnt3wqrrk50rl&st=t69g63uc&dl=1"
if [[ $? -ne 0 ]]; then
    echo "Failed to download Windows ISO. Please check the URL."
    exit 1
fi

# Mount the Windows ISO and copy its contents to /mnt
echo "Copying Windows installation files..."
mount -o loop /root/windisk/Windows_SERVER_2022_NTLite.iso winfile
rsync -avz --progress winfile/* /mnt
umount winfile

# Download Virtio drivers ISO
echo "Downloading Virtio drivers..."
wget -O /root/windisk/virtio.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
if [[ $? -ne 0 ]]; then
    echo "Failed to download Virtio drivers."
    exit 1
fi

# Mount Virtio drivers ISO and copy its contents
echo "Copying Virtio drivers..."
mount -o loop /root/windisk/virtio.iso winfile
mkdir -p /mnt/sources/virtio
rsync -avz --progress winfile/* /mnt/sources/virtio
umount winfile

# Update boot.wim with Virtio drivers
echo "Updating boot.wim with Virtio drivers..."
cd /mnt/sources
touch cmd.txt
echo 'add virtio /virtio_drivers' >> cmd.txt
wimlib-imagex update boot.wim 2 < cmd.txt

# Reboot to load GRUB and start Windows installer
echo "Setup complete. Rebooting..."
reboot
