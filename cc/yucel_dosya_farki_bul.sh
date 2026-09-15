echo "Ornek -> bash yucel_dosya_farki_bul.sh 07 2024"
sleep 1

if [ -z "$1" ] ; then
echo "Ay bilgisi girilmesi zorunludur"
exit
fi
monthx=$1

if [ -z "$2" ] ; then
echo "Yil bilgisi girilmesi zorunludur"
exit
fi
yearx=$2

original="/home/ansible/${monthx}_${yearx}_dosya_listesi_Original.txt"
if [ ! -s "$original" ] ; then
echo "$original dosyasi bulunamadi !! "
exit 1
fi

yedek=${monthx}_${yearx}_dosya_listesi_Yedek.txt
if [ ! -s "$yedek" ] ; then
echo "$yedek dosyasi bulunamadi !! "
exit 1
fi


workdirx="/nfs/nfsdata/prod/"
cd $workdirx
if [ $? -ne 0 ] ; then
echo "$workdirx dizini bulunamadi !! "
exit 1
fi

## Dosya farklari bulunuyor..
echo "Dosya farklari bulunuyor... "
sleep 1
fark=".tmp_FARK"
awk 'NR==FNR{a[$1];next}!($1 in a)' $original $yedek >$fark
if [ -s "$fark" ] ; then
echo "Fark bulunamadi.. [OK] "
else
cat $fark
fi

echo
echo "--------------------"
