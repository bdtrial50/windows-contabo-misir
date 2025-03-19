#!/bin/bash

# Update system and install required packages
apt update -y && apt upgrade -y
apt install grub2 wimtools ntfs-3g -y

# Get the disk size in GB and convert to MB
disk_size_gb=$(parted /dev/sda --script print | awk '/^Disk \/dev\/sda:/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))

# Calculate partition size (25% of total size)
part_size_mb=$((disk_size_mb / 4))

# Create GPT partition table
parted /dev/sda --script -- mklabel gpt

# Create two partitions
parted /dev/sda --script -- mkpart primary ntfs 1MB ${part_size_mb}MB
parted /dev/sda --script -- mkpart primary ntfs ${part_size_mb}MB $((2 * part_size_mb))MB

# Inform kernel of partition table changes
partprobe /dev/sda

sleep 30

# Reapply partprobe after a short delay
partprobe /dev/sda
sleep 30

partprobe /dev/sda
sleep 30

# Format the partitions as NTFS
mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2

echo "NTFS partitions created"

# Use gdisk to update the partition table
echo -e "r\ng\np\nw\nY\n" | gdisk /dev/sda

# Mount the first partition
mount /dev/sda1 /mnt

# Prepare directory for the Windows disk
cd ~
mkdir windisk
mount /dev/sda2 windisk

# Install GRUB bootloader
grub-install --root-directory=/mnt /dev/sda

# Edit GRUB configuration to add Windows boot entry
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "Windows installer" {
    insmod ntfs
    search --set=root --file=/bootmgr
    ntldr /bootmgr
    boot
}
EOF

# Download Windows ISO if not already downloaded
cd /root/windisk

if [ ! -f win10.iso ]; then
    echo "Downloading Windows 10 ISO..."
    wget -O win10.iso --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" https://bit.ly/3UGzNcB
fi

# Mount the ISO file and copy its contents to the partition
mkdir winfile
mount -o loop win10.iso winfile
rsync -avz --progress winfile/* /mnt

# Unmount the Windows ISO
umount winfile

# Download Virtio drivers ISO
if [ ! -f virtio.iso ]; then
    echo "Downloading Virtio drivers ISO..."
    wget -O virtio.iso https://bit.ly/4d1g7Ht
fi

# Mount Virtio drivers ISO and copy its contents
mount -o loop virtio.iso winfile
mkdir /mnt/sources/virtio
rsync -avz --progress winfile/* /mnt/sources/virtio

# Update boot.wim with Virtio drivers
cd /mnt/sources
touch cmd.txt
echo 'add virtio /virtio_drivers' >> cmd.txt
wimlib-imagex update boot.wim 2 < cmd.txt

# Reboot the system
reboot
