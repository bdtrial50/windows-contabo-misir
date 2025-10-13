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

wget -O Windows_SERVER_2022_NTLite.iso "https://www.dropbox.com/scl/fi/kjvjlmhbt8fbwa9zxmke2/Windows_SERVER_2022_NTLite.iso?rlkey=2qrb3egcnec7wnt3wqrrk50rl&st=t69g63uc&dl=1"

mount -o loop Windows_SERVER_2022_NTLite.iso winfile
rsync -avz --progress winfile/* /mnt
umount winfile

reboot
