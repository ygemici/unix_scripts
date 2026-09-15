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

workdirx="/nfs/nfsdata/prod/"
cd $workdirx
if [ $? -ne 0 ] ; then
echo "$workdirx dizini bulunamadi !! "
exit 1
fi


remove_files() {
## Dosya bilgileri bulunup silinecek..
echo "Dosyalar silinecek -> [$monthx-$yearx]"
sleep 2
find $yearx/$monthx/ -type f -delete

sleep 1
echo "[$monthx-$yearx] tarihli dosyalar silinmistir "
echo "--------------------"
}


remove_files;
