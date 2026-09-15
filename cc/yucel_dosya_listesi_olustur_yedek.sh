echo "Ornek -> bash yucel_dosya_listesi_olustur.sh 07 2024"
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

workdirx="/nfs/nfsdata/prod/"
cd $workdirx
if [ $? -ne 0 ] ; then
echo "$workdirx dizini bulunamadi !! "
exit 1
fi

echo "Kontrol edilecek dosyalara ait Tarih bilgisi : [$monthx-$yearx] "
sleep 1

yedek=${monthx}_${yearx}_dosya_listesi_Yedek.txt

find $yearx/$monthx/ -type f |awk -F'/' '{print $NF}' >$yedek
if [ -s "$yedek" ] ; then
echo "[$monthx-$yearx] e ait dosya listesi olusturulmustur -> $(wc -l $yedek) "
sleep 1
else
echo "[$monthx-$yearx] e ait dosya listesi olusturulamamistir !! "
exit 1
fi

echo
echo "--------------------"
