echo "Ornek -> bash yucel_dosya_size_farki_bul.sh 07 2024"
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

originalsize="/home/ansible/${monthx}_${yearx}_dosya_size_listesi_Original.txt"
if [ ! -s "$originalsize" ] ; then
echo "$original size dosyasi bulunamadi !! "
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


## Dosya size farklari bulunuyor..
echo "Dosya size farklari bulunuyor...[$monthx-$yearx]"
sleep 1
fark=".tmp_size_FARK"
awk 'NR==FNR{a[$0];next}!($0 in a)' $originalsize $yedeksize >$fark
if [ -s "$fark" ] ; then
echo "Fark bulunamadi.. [OK] "
else
cat $fark
fi

echo
echo "--------------------"
