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
mkdir windisk

mount /dev/sda2 windisk

grub-install --root-directory=/mnt /dev/sda

# Edit GRUB configuration
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "windows installer" {
    insmod ntfs
    search --set=root --file=/bootmgr
    ntldr /bootmgr
    boot
}
EOF

cd /root/windisk

mkdir winfile

# Download Windows Server 2022 ISO without user-agent
wget -O Windows_SERVER_2022_NTLite.iso "https://www.dropbox.com/scl/fi/kjvjlmhbt8fbwa9zxmke2/Windows_SERVER_2022_NTLite.iso?rlkey=2qrb3egcnec7wnt3wqrrk50rl&st=t69g63uc&dl=1"

mount -o loop Windows_SERVER_2022_NTLite.iso winfile

rsync -avz --progress winfile/* /mnt

umount winfile

reboot
