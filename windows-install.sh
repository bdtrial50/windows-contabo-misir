#!/bin/bash
set -e  # Exit on any error

# --- Update system and install dependencies ---
apt update -y && apt upgrade -y
apt install -y grub2 wimtools ntfs-3g wget rsync gdisk parted

# --- Get disk size in MB ---
disk_size_gb=$(parted /dev/sda --script print | awk '/^Disk \/dev\/sda:/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))
part_size_mb=$((disk_size_mb / 4))  # 25% for each partition

# --- Create GPT partition table ---
parted /dev/sda --script mklabel gpt

# --- Create two NTFS partitions ---
parted /dev/sda --script mkpart primary ntfs 1MB ${part_size_mb}MB
parted /dev/sda --script mkpart primary ntfs ${part_size_mb}MB $((2 * part_size_mb))MB

# --- Inform kernel ---
partprobe /dev/sda
sleep 5

# --- Format partitions ---
mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2
echo "NTFS partitions created"

# --- Set up GRUB ---
mount /dev/sda1 /mnt
mkdir -p /mnt/boot/grub
grub-install --root-directory=/mnt /dev/sda

cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "Windows Installer" {
    insmod ntfs
    search --set=root --file /bootmgr
    ntldr /bootmgr
    boot
}
EOF

# --- Prepare Windows disk ---
mkdir -p ~/windisk
mount /dev/sda2 ~/windisk
mkdir -p ~/windisk/winfile

# --- Download Windows Server 2022 ISO ---
wget -O ~/windisk/Windows_SERVER_2022_NTLite.iso \
"https://www.dropbox.com/scl/fi/kjvjlmhbt8fbwa9zxmke2/Windows_SERVER_2022_NTLite.iso?rlkey=2qrb3egcnec7wnt3wqrrk50rl&st=t69g63uc&dl=1"

# --- Mount ISO and copy files ---
mkdir -p ~/windisk/iso_mount
mount -o loop ~/windisk/Windows_SERVER_2022_NTLite.iso ~/windisk/iso_mount
rsync -avh --progress ~/windisk/iso_mount/ /mnt/
umount ~/windisk/iso_mount

# --- Cleanup and reboot ---
umount /mnt
echo "Setup complete. Rebooting..."
reboot
