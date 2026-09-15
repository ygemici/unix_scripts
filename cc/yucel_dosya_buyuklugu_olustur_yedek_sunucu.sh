echo "Ornek -> bash yucel_dosya_size_olustur.sh 07 2024"
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

yedek="${monthx}_${yearx}_dosya_listesi_Yedek.txt"
if [ ! -s "$yedek" ] ; then
echo "$yedek dosyasi bulunamadi !! "
exit 1
fi


## Dosya size bilgileri bulunuyor..
echo "Dosya size bilgileri bulunuyor...[$monthx-$yearx]"
yedeksize=${monthx}_${yearx}_dosya_size_listesi_Yedek.txt
>$yedeksize
while read file; do
du -s -B1 --apparent-size $yearx/$monthx/*/$file |awk -v a="$yearx" -v b="$monthx" '{sub(a"/"b"/.*/","",$NF);print $1,$NF}' >>$yedeksize
done <$yedek


echo
echo "--------------------"
