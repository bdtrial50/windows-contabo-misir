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
parted /dev/sda --script mklabel gpt

# Create two partitions:
#  - Partition 1: from 1MB to 25% of the disk (for Windows installation files)
#  - Partition 2: from 25% to 50% of the disk (used as working area)
parted /dev/sda --script mkpart primary ntfs 1MB ${part_size_mb}MB
parted /dev/sda --script mkpart primary ntfs ${part_size_mb}MB $((2 * part_size_mb))MB

# Inform kernel of partition table changes (with delays to ensure update)
partprobe /dev/sda
sleep 30
partprobe /dev/sda
sleep 30
partprobe /dev/sda
sleep 30 

# Format the partitions as NTFS
mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2

echo "NTFS partitions created"

# (Optional) Update partition table using gdisk
echo -e "r\ng\np\nw\nY\n" | gdisk /dev/sda

# Mount partitions:
#  - /dev/sda1 will host the Windows installation files
#  - /dev/sda2 will be used as a working directory
mount /dev/sda1 /mnt
mkdir -p /root/windisk
mount /dev/sda2 /root/windisk

# Install GRUB bootloader onto /dev/sda using /mnt as the root directory
grub-install --root-directory=/mnt /dev/sda

# Edit GRUB configuration to correctly chainload Windows boot manager
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "windows installer" {
    insmod ntfs
    search --set=root --file /bootmgr
    chainloader +1
    boot
}
EOF

# Download the Windows ISO into the correct directory
cd /root/windisk
mkdir -p winfile
wget -O /root/windisk/Windows_SERVER_2022_NTLite.iso "https://www.dropbox.com/scl/fi/kjvjlmhbt8fbwa9zxmke2/Windows_SERVER_2022_NTLite.iso?rlkey=2qrb3egcnec7wnt3wqrrk50rl&st=t69g63uc&dl=1"

# Mount the Windows ISO and copy its contents to /mnt
mount -o loop /root/windisk/Windows_SERVER_2022_NTLite.iso winfile
rsync -avz --progress winfile/* /mnt
umount winfile

# Download Virtio drivers ISO and copy its contents
wget -O /root/windisk/virtio.iso https://bit.ly/4d1g7Ht
mount -o loop /root/windisk/virtio.iso winfile
mkdir -p /mnt/sources/virtio
rsync -avz --progress winfile/* /mnt/sources/virtio
umount winfile

# Update boot.wim with Virtio drivers (from /mnt/sources)
cd /mnt/sources
touch cmd.txt
echo 'add virtio /virtio_drivers' >> cmd.txt
wimlib-imagex update boot.wim 2 < cmd.txt

# Reboot to load GRUB and start Windows installer
reboot
