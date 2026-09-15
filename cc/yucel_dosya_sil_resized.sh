echo "Ornek -> bash remove_callcenter_files.sh 07 2024"
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


## Dosya bilgileri bulunup silinecek..
echo "Dosyalar silinecek -> [$monthx-$yearx]"
sleep 2

if [ $monthx -lt 12 ]; then
monthnext=$((10#$monthx+1))
yearnext=$yearx
else
monthnext=01
yearnext=$(($yearx+1))
fi


echo "Dosya listesi olusturuluyor.."
prod=${monthx}_${yearx}_remove_dosya_listesi_Prod.txt
find Original/ -type f -newermt $yearx-$monthx-01 ! -newermt $yearnext-$monthnext-01 >$prod
if [ -s "$prod" ] ; then
echo "[$monthx-$yearx] e ait dosya listesi olusturulmustur -> $(wc -l $prod) "
sleep 1
else
echo "[$monthx-$yearx] e ait dosya listesi olusturulamamistir !! "
exit 1
fi


##Resized de klasorunde dosya var mi
resized=${monthx}_${yearx}_remove_dosya_listesi_Resized.txt
awk -F'/' '{print $NF}' $prod >$resized
removed_from_original="removed_from_original_files.txt"
>$removed_from_original
resized_nofiles=resized_nofiles.txt
>$resized_nofiles
while read -r fileresized ; do
resizedf="Resized/$fileresized"
if [ -f "$resizedf" ] ; then
echo "Original/$fileresized" >>$removed_from_original
else
echo "$fileresized dosyasi Resized klasorunde bulunamadi !! "
echo "$fileresized" >>$resized_nofiles
fi
done <$resized


remove_files() {
if [ ! -f "$removed_from_original" ] ; then
echo "Silinecek dosya listesi bulunamadi !! "
exit 1
fi
## Dosyalar siliniyor..
echo "Bu tarihe ait dosyalar Original klasorunden silinecek !! -> [$monthx-$yearx]"
sleep 2
while read -r fileremove ; do
rm -f $fileremove
if [ $? -ne 0 ] ; then
echo "$fileremove dosyasi silinirken bir hata olustu !! "
sleep 1
exit 1
fi
done <$removed_from_original

sleep 1
echo "[$monthx-$yearx] tarihli dosyalar silinmistir "
echo "--------------------"
}


remove_files;
