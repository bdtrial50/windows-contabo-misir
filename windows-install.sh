#!/bin/bash

apt update -y && apt upgrade -y
apt install grub2 wimtools ntfs-3g -y

mount /dev/sda1 /mnt

cd ~
mkdir windisk
mount /dev/sda2 windisk

grub-install --root-directory=/mnt /dev/sda

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

wget -O Windows_SERVER_2022_NTLite.iso "https://www.dropbox.com/scl/fi/glre2086eynmqor22m7lq/Misir_Win_Server_2022_TG_EDITION.iso?rlkey=q8p75gg085lvvb58rp8khy1op&st=nyfw3f9p&dl=1"

mount -o loop Windows_SERVER_2022_NTLite.iso winfile
rsync -avz --progress winfile/* /mnt
umount winfile

reboot
