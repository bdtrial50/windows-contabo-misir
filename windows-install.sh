#!/bin/bash

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

partprobe /dev/sda

sleep 30

partprobe /dev/sda

sleep 30 

# Format the partitions
mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2

echo "NTFS partitions created"

echo -e "r\ng\np\nw\nY\n" | gdisk /dev/sda

mount /dev/sda1 /mnt

# Prepare directory for the Windows disk
cd ~
mkdir -p /root/windisk

mount /dev/sda2 /root/windisk

grub-install --root-directory=/mnt /dev/sda

# Edit GRUB configuration
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "windows installer" {
    insmod ntfs
    search --set=root --file /bootmgr
    chainloader +1
    boot
}
EOF

# Download the Windows ISO to the correct path
cd /root/windisk
mkdir -p winfile

wget -O /root/windisk/Windows_SERVER_2022_NTLite.iso "https://www.dropbox.com/scl/fi/kjvjlmhbt8fbwa9zxmke2/Windows_SERVER_2022_NTLite.iso?rlkey=2qrb3egcnec7wnt3wqrrk50rl&st=t69g63uc&dl=1"

# Mount the ISO and copy files
mount -o loop /root/windisk/Windows_SERVER_2022_NTLite.iso winfile

rsync -avz --progress winfile/* /mnt

umount winfile

# Download virtio drivers
wget -O /root/windisk/virtio.iso https://bit.ly/4d1g7Ht

mount -o loop /root/windisk/virtio.iso winfile

mkdir /mnt/sources/virtio

rsync -avz --progress winfile/* /mnt/sources/virtio

# Add virtio drivers to the boot.wim
cd /mnt/sources

touch cmd.txt

echo 'add virtio /virtio_drivers' >> cmd.txt

wimlib-imagex update boot.wim 2 < cmd.txt

# Reboot after installation steps
reboot
