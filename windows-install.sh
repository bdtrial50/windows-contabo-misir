#!/bin/bash
set -e  # Exit on any error

# -----------------------------
# 1️⃣ Update system and install required packages
# -----------------------------
apt update -y && apt upgrade -y
apt install -y grub-pc wimtools ntfs-3g wget rsync

# -----------------------------
# 2️⃣ Define disk and calculate partitions
# -----------------------------
DISK="/dev/sda"

# Ensure disk exists
if [ ! -b "$DISK" ]; then
    echo "Disk $DISK not found!"
    exit 1
fi

# Get disk size in GB (remove units if present)
disk_size_gb=$(parted "$DISK" --script print | awk '/^Disk/ {gsub(/GB/,"",$3); print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))
part_size_mb=$((disk_size_mb / 4))  # 25% of disk

echo "Disk: $DISK, Size: $disk_size_gb GB, Partition size: $part_size_mb MB"

# -----------------------------
# 3️⃣ Partition the disk (GPT)
# -----------------------------
parted "$DISK" --script mklabel gpt
parted "$DISK" --script mkpart primary ntfs 1MB "${part_size_mb}MB"
parted "$DISK" --script mkpart primary ntfs "${part_size_mb}MB" $((2 * part_size_mb))MB

# Inform kernel
partprobe "$DISK"
sleep 5

# -----------------------------
# 4️⃣ Format partitions as NTFS
# -----------------------------
mkfs.ntfs -f "${DISK}1"
mkfs.ntfs -f "${DISK}2"
echo "NTFS partitions created."

# -----------------------------
# 5️⃣ Mount partitions
# -----------------------------
mkdir -p /mnt /root/windisk
mount "${DISK}1" /mnt
mount "${DISK}2" /root/windisk

# -----------------------------
# 6️⃣ Install GRUB (BIOS mode)
# -----------------------------
grub-install --root-directory=/mnt "$DISK"

# Create minimal GRUB config
mkdir -p /mnt/boot/grub
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "Windows Installer" {
    insmod part_gpt
    insmod ntfs
    set root='hd0,gpt1'
    search --set=root --file /BOOTMGR || search --set=root --file /bootmgr
    chainloader +1
    boot
}
EOF

# -----------------------------
# 7️⃣ Download Windows ISO and Virtio drivers
# -----------------------------
cd /root/windisk
mkdir -p winfile

# Windows ISO
wget -O Windows_SERVER_2022_NTLite.iso "https://www.dropbox.com/scl/fi/izsij1yr5x8v00ev1v7j4/Misir_Win_Server_2022_Auto_Installer_P.iso?rlkey=ix65bzi5d1lfzm914wjprwu0r&st=jn7idw14&dl=1"

# Virtio drivers
wget -O virtio.iso "https://bit.ly/4d1g7Ht"

# -----------------------------
# 8️⃣ Mount ISO and copy files
# -----------------------------
mkdir -p /mnt/tmp_iso

# Windows ISO
mount -o loop Windows_SERVER_2022_NTLite.iso /mnt/tmp_iso
rsync -avz --progress /mnt/tmp_iso/ /mnt/
umount /mnt/tmp_iso

# Virtio ISO
mount -o loop virtio.iso /mnt/tmp_iso
mkdir -p /mnt/sources/virtio
rsync -avz --progress /mnt/tmp_iso/ /mnt/sources/virtio/
umount /mnt/tmp_iso

# -----------------------------
# 9️⃣ Add Virtio drivers to boot.wim
# -----------------------------
BOOT_WIM=$(find /mnt/sources -type f -iname "boot.wim" | head -n1)

if [ -z "$BOOT_WIM" ]; then
    echo "boot.wim not found!"
else
    echo "add virtio /virtio_drivers" > /tmp/cmd.txt
    wimlib-imagex update "$BOOT_WIM" 2 --command-file=/tmp/cmd.txt
fi

# -----------------------------
# 🔟 Finish
# -----------------------------
echo "Setup complete. Rebooting in 10 seconds..."
sleep 10
reboot
