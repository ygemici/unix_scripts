echo "##Written by YUCEL 2025 v1.0.1##"
sleep 1

read -p "islem yapilacak sunucu ismini giriniz .. ? " sunucu
if [ -z "$sunucu" ] ; then
echo "Sunucu ismi girilmeden islem yapilamaz !! "
exit 1
fi

mesajyaz() {
echo "Taranacak disk [$1] dizinine mount edilmistir [OK] "
sleep 1
}

nmount_kontrol() {
mount|grep -w -q "on $1"
if [ $? -eq 0 ] ; then
echo "$1 dizinine zaten Mount yapilmis "
exit 1
fi
}

for i in $(lsblk -d|grep -v -w -e sda -e sdb -e sr0 | awk 'NR>1{print $1}') ; do
ext4_ok=0
xfs_ok=1

#LVM varsa
lsblk /dev/$i|grep -q lvm
if [ $? -eq 0 ] ; then
lvmdev=$(lsblk -o NAME,TYPE -n -i -r /dev/$i|grep -i lvm|awk '{a[$1]}END{for(i in a)print i} ')
for lvmi in $lvmdev ;
do
file -sL /dev/mapper/$lvmi|grep -q -i ext4
if [[ $? -eq 0 ]] ; then
ext4_ok=1
mount_kontrol /mnt/$sunucu;
mkdir -p /mnt/$sunucu || exit 1
mount -t ext4 /dev/mapper/$lvmi /mnt/$sunucu || exit 1
mesajyaz /mnt/$sunucu
fi
file -sL /dev/mapper/$lvmi|grep -q -i xfs
if [[ $? -eq 0 ]] ; then
xfs_ok=1
mount_kontrol /mnt/$sunucu;
mkdir -p /mnt/$sunucu || exit 1
mount -t xfs /dev/mapper/$lvmi /mnt/$sunucu || exit 1
mesajyaz /mnt/$sunucu
fi
done

else

#LVM degilse
file -sL /dev/$i|grep -q -i ext4
if [[ $? -eq 0 ]] ; then
ext4_ok=1
mount_kontrol /mnt/$sunucu;
mkdir -p /mnt/$sunucu || exit 1
mount -t ext4 /dev/$i /mnt/$sunucu || exit 1
mesajyaz /mnt/$sunucu
fi
file -sL /dev/mapper/$lvmi|grep -q -i xfs
if [[ $? -eq 0 ]] ; then
xfs_ok=1
mount_kontrol /mnt/$sunucu;
mkdir -p /mnt/$sunucu || exit 1
mount -t xfs /dev/$i /mnt/$sunucu || exit 1
mesajyaz /mnt/$sunucu
fi
fi

#if [[ $ext4_ok -ne 1 ]] || [[ $xfs_ok -ne 1 ]] ; then
#echo "Uygulamada sadece xfs ve ext4 destegi bulunmaktadir !! "
#fi

done
