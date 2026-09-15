echo "Ornek -> bash yucel_dosya_listesi_olustur_original.sh 07 2024"
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

echo "Kontrol edilecek dosyalara ait Tarih bilgisi : [$monthx-$yearx] "
sleep 1

original=${monthx}_${yearx}_dosya_listesi_Original.txt


if [ $monthx -lt 12 ]; then
monthnext=$((10#$monthx+1))
yearnext=$yearx
else
monthnext=01
yearnext=$(($yearx+1))
fi

find Original/ -type f -newermt $yearx-$monthx-01 ! -newermt $yearnext-$monthnext-01 |awk -F'/' '{print $NF}' >$original
if [ -s "$original" ] ; then
echo "[$monthx-$yearx] e ait dosya listesi olusturulmustur -> $(wc -l $original) "
sleep 1
else
echo "[$monthx-$yearx] e ait dosya listesi olusturulamamistir !! "
exit 1
fi

echo "Dosya listesi Yedek sunucusuna gonderiliyor .. "
scp $original ansible@SVPRDKYCNFS01:~

echo
echo "--------------------"
