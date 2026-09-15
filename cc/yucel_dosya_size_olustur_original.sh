echo "Ornek -> bash yucel_dosya_size_olustur_original.sh 07 2024"
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


workdirx="/nfs/nfsdata/intprod/intprod-enverify-enverify-api-new-pvc-7085cba5-b04d-486a-bfc8-8c5933a3a68e/Video/"
cd $workdirx
if [ $? -ne 0 ] ; then
echo "$workdirx dizini bulunamadi !! "
exit 1
fi

original=${monthx}_${yearx}_dosya_listesi_Original.txt
if [ ! -s "$original" ] ; then
echo "$yedek dosyasi bulunamadi !! "
exit 1
fi

## Dosya size bilgileri bulunuyor..
echo "Dosya size bilgileri bulunuyor...[$monthx-$yearx]"
originalsize=${monthx}_${yearx}_dosya_size_listesi_Original.txt
>$originalsize
while read file; do
du -s -B1 --apparent-size Original/$file |awk '{sub("Original/","",$NF);print $1,$NF}' >>$originalsize
done <$original

echo "Dosya listesi Yedek sunucusuna gonderiliyor .. "
scp $originalsize ansible@SVPRDKYCNFS01:~

echo
echo "--------------------"
