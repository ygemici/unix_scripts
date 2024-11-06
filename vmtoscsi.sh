#!/bin/bash
###Yucel Gemici - VM disk <-> Vmware scsi
### updated 16-09-2022

### SATA disk destegi eklendi..
### updated 11-10-2022

### gelistirme ve kod ayiklama
### updated 24-07-2023

### gelistirme ve kod ayiklama
### guess2 19-08-2023

###exs
### [root@redhat8_yucel ~]# lsscsi -s
### [0:0:0:0]    disk    VMware   Virtual disk     2.0   /dev/sda   64.4GB
### [0:0:1:0]    disk    VMware   Virtual disk     2.0   /dev/sdb   40.8GB
### [0:0:2:0]    disk    VMware   Virtual disk     2.0   /dev/sdc   2.14GB
### [0:0:3:0]    disk    VMware   Virtual disk     2.0   /dev/sdd   3.43GB
### [3:0:0:0]    cd/dvd  NECVMWar VMware SATA CD00 1.00  /dev/sr0   1.07GB
### [4:0:0:0]    disk    ATA      VMware Virtual S 0001  /dev/sde   1.07GB
### [5:0:0:0]    disk    ATA      VMware Virtual S 0001  /dev/sdf   1.07GB
### [33:0:0:0]   disk    ATA      VMware Virtual S 0001  /dev/sdg   1.07GB
### [34:0:0:0]   disk    ATA      VMware Virtual S 0001  /dev/sdh   1.07GB

### [root@redhat8_yucel ~]# bash vmtoscsi.sh
### -normal-
### sda  [0:0:0:0]       VMware        <=====>       VM-scsi(0:0)              Hard Disk 1 - [60G]
### sdb  [0:0:1:0]       VMware        <=====>       VM-scsi(0:1)              Hard Disk 2 - [38G]
### sdc  [0:0:2:0]       VMware        <=====>       VM-scsi(0:2)              Hard Disk 3 - [2G]
### sdd  [0:0:3:0]       VMware        <=====>       VM-scsi(0:3)              Hard Disk 4 - [3.2G]
### sde  [4:0:0:0]       ATA           <=====>        VM-ata(0:0)              Hard Disk 5 - [1G]
### sdf  [5:0:0:0]       ATA           <=====>        VM-ata(1:0)              Hard Disk 6 - [1G]
### sdg  [3:3:0:0]       ATA           <=====>        VM-ata(2:0)              Hard Disk 7 - [1G]
### sdh  [3:4:0:0]       ATA           <=====>        VM-ata(3:1)              Hard Disk 8 - [1G]



#Dsk   VM  H:B:T:L - ( VM id )
#---   --- ---------------------
#sda = 0:0 0:0:0:0 - Hard disk 1
#sdb = 0:1 0:0:1:0 - Hard disk 2
#sdc = 0:2 0:0:2:0 - Hard disk 3
#sdd = 0:3 0:0:3:0 - Hard disk 4
#
#sde = 1:0 1:0:0:0 - Hard disk 5
#sdf = 2:0 2:0:0:0 - Hard disk 6
#
#sdg = 3:0 5:0:0:0 - Hard disk 7
#sdh = 3:1 5:0:1:0 - Hard disk 8

## host number, channel (or bus) number, target number and logical unit number (i.e. LUN)

#lsscsi &>/dev/null
#if [ $? -eq 0 ] ; then
#allscsis=$(lsscsi |awk '$2=="disk"'|awk '{sub("/dev/","",$NF);sub(/\[/,"",$1);sub(/\]/,"",$1);print $NF,$1}')
#allscsihost=$(lsscsi -H|awk '!(/ata/||/iscsi/||/usb/||/qla/||/fc/){sub(/\[/,"",$1);sub(/\]/,"",$1);print "host"$1}')
#allscsihost=$(lsscsi -H|awk '/scsi/&&!/iscsi/{sub(/\[/,"",$1);sub(/\]/,"",$1);print "host"$1}')
#onlyscsi=$(lsscsi |awk '/LOGICAL VOLUME/||/Virtual disk/{sub(/\[/,"",$1);sub(/:.*/,"",$1);sub("/dev/","",$NF);print "host"$1,$NF}')

#allscsis=$(ls -l /sys/block/sd*/device|awk -F"/" '{sub(".*block/","");print $1,$NF}')
#allscsihost=$(ls -ld /sys/class/scsi_host/host*|awk -F'/' '{print $NF}')
#allscsihost=$(ls -ld /sys/devices/*/*/*/*host*|awk -F'/' '!(/iscsi/||/ata/)'|awk -F'/' '!/scsi_host/{print $NF}')
#allscsihost=$(grep VMware /sys/devices/*/*/*/host*/*/*/vendor|awk -F'/' '{print $7}')
#onlyscsi=$(ls -l /sys/block/|awk -F'/' '/sd/&&!(/virtual/||/session/||/ata/||/usb/||/cd/||/sr/)&&NR>1{sub(/.*host/,"");print "host"$1,$NF}')


#############################
sds=/tmp/.sds
devs=/tmp/.devs
vms=/tmp/.vmscsis
vmstmp=$vms
vms_complx=/tmp/.vmscsis.cmplx
#sdsa=/tmp/.allsds
#sdsx=/tmp/.sdsx
sdvendors=/tmp/.sdvendors
scsisatavendors=/tmp/.scsisatavendors
scsisatavendors2=/tmp/.scsisatavendors2
fullinfo=/tmp/.scsivms
fullinfo_complx=/tmp/.scsivms.cmplx
fullinfo_complx_guess=/tmp/.scsivms.guess
fullinfo_guess=/tmp/.scsivms.out.guess
fullinfo_guess_chk=/tmp/.scsivms.out.guess.chk
fullinfo_guess_tmp=/tmp/.scsivms.out.guess.tmp
dsksz=/tmp/.dskszXy
dsksz_bck=$dsksz
dsksz_complx=/tmp/.dskszXy.cmplx
fullinfosz=/tmp/.scsivmsz
#############################




### tum scsi device lar ( cd/dvd ve sata lar dahil )
## dvd lerle isimiz yok !!
## ls -l /sys/block/s[dr]*/device|awk -F"/" '{sub(".*block/","");gsub(":"," ");print $1,$NF}' >$sdsa



#[root@ksunxtestr ~]# ls -l /sys/block/sd*/device|awk -F"/" '{sub(".*block/","");gsub(":"," ");print $1,$NF}'
#sda 9 0 0 0
#sdb 32 0 9 0



# vmscsi harici block devicelar
#grep -l -v VMware /sys/devices/*/*/*/host*/*/*/vendor|while read -r nonscsi ; do \
#x=$(echo "$nonscsi"|sed 's/\/vendor//');sdx=$(ls -d "$x"/block/s[dr]* |awk -F'/' '{print $NF}') ; \
#echo "$sdx $(cat "$nonscsi" )"; done

####update####
#------------#
# asagidaki sunucuda pci_bus bilgisinden dolayi farkli dizinler olustugu icin
# asagidaki 'grep -l "" ' ... komutunda bu dizin bilgisi olmadigi icin [sda] diski bulunamiyordu !!

#####host2#### -> +-10.0 - LSI Logic
#[root@ksunxtestr 0000:02:00.0]# grep -l "" /sys/devices/*/*/host*/*/*/vendor
#/sys/devices/pci0000:00/0000:00:07.1/host1/target1:0:0/1:0:0:0/vendor
#/sys/devices/pci0000:00/0000:00:10.0/host2/target2:0:0/2:0:0:0/vendor
#[root@ksunxtestr 0000:02:00.0]#

#####host3#### -> +-11.0-[02]----00.0 - LSI Logic
#[root@ksunxtestr 0000:02:00.0]# grep -l "" /sys/devices/*/*/*/host*/*/*/vendor
#/sys/devices/pci0000:00/0000:00:11.0/0000:02:00.0/host3/target3:0:0/3:0:0:0/vendor
#/sys/devices/pci0000:00/0000:00:11.0/0000:02:00.0/host3/target3:0:1/3:0:1:0/vendor
#/sys/devices/pci0000:00/0000:00:11.0/0000:02:00.0/host3/target3:0:2/3:0:2:0/vendor

#[root@ksunxtestr 0000:02:00.0]# lspci -v -t|grep -i scsi
#           +-10.0  LSI Logic / Symbios Logic 53c1030 PCI-X Fusion-MPT Dual Ultra320 SCSI
#           +-11.0-[02]----00.0  LSI Logic / Symbios Logic 53c1030 PCI-X Fusion-MPT Dual Ultra320 SCSI


# tum sd device lar ( scsi , sata .. )
#grep -l "" /sys/devices/*/*/*/host*/*/*/vendor /sys/devices/*/*/host*/*/*/vendor /sys/devices/*/*/ata*/*/*/*/vendor /sys/devices/*/*/*/ata*/*/*/*/vendor 2>/dev/null|while read -r nonscsi ; do
##cd/dvd dahil
#x=$(echo "$nonscsi"|sed 's/\/vendor//');sdx=$(ls -d "$x"/block/s[dr]* |awk -F'/' '{print $NF}') ;
##cd/dvd haric
#x=$(echo "$nonscsi"|sed 's/\/vendor//');
#sdx=$(ls -d "$x"/block/s[d]* 2>/dev/null|awk -F'/' '{print $NF}') ;
#[ ! -z "$sdx" ] && echo "$sdx $(cat "$nonscsi" )"; done >$sdvendors

#[root@ksunxtestr ~]# grep -l "" /sys/devices/*/*/*/host*/*/*/vendor|while read -r nonscsi ; do
#> x=$(echo "$nonscsi"|sed 's/\/vendor//');sdx=$(ls -d "$x"/block/s[dr]* |awk -F'/' '{print $NF}') ;
#> echo "$sdx $(cat "$nonscsi" )"; done
#sr0 NECVMWar
#sda ATA
#sdb VMware


#### eski sds
### sd* icin sata devicelar a geliyor. ( dvd ler haric ) !!!
## target dosyasi olusturulma tarihine gore ??
#[root@ksunxtestr ~]# ls -l /sys/block/sd*/device
#lrwxrwxrwx 1 root root 0 Nov 10  2021 /sys/block/sda/device -> ../../../0:0:0:0
#lrwxrwxrwx 1 root root 0 Mar 23  2022 /sys/block/sdb/device -> ../../../3:0:0:0
#lrwxrwxrwx 1 root root 0 Mar 23  2022 /sys/block/sdc/device -> ../../../4:0:0:0
#lrwxrwxrwx 1 root root 0 Mar 23  2022 /sys/block/sdd/device -> ../../../5:0:0:0
#lrwxrwxrwx 1 root root 0 Apr 12  2022 /sys/block/sde/device -> ../../../4:0:1:0


## ls komutu defaul oalrak alfabetik sirali getirir.
ls -l /sys/block/sd*/device|awk -F"/" '{sub(".*block/","");gsub(":"," ");print $1,$NF}' >${sds}_name
#lsblk -dno name|grep 'sd' >${sds}_name


for i in $(find /sys/devices/ -name block) ; do
#hbtl=$(echo $i|awk -F'/' '{print $(NF-1)}')
sdx=$(ls -d "$i"/s[d]* 2>/dev/null|awk -F'/' '{print $NF}')
[ ! -z "$sdx" ] && echo "$sdx $i" ; done >$devs

#target numara sirasina gore
#sed 's;^\([^ ]*\).*target[^ ]*/\([^ ]*\)/[^ ]*;\1 \2;' $devs|sed 's/://g'|\
#awk '{a[x++]=$2;b[y++]=$1;}END{for(i=1;i<x;i++)for(j=0;j<x-i;j++)if(a[j]>a[j+1])\
#{temp=a[j+1];a[j+1]=a[j];a[j]=temp;temp2=b[j+1];b[j+1]=b[j];b[j]=temp2}for(i=0;i<x;i++)print b[i] FS a[i]}'|\
#sed 's/\([^ ]*\) \(.\)\(.\)\(.\)\(.\)/\1 \2 \3 \4 \5/g' >${sds}_sorted

#target numara sirasina gore - new
sed 's;^\([^ ]*\).*target[^ ]*/\([^ ]*\)/[^ ]*;\1 \2;' $devs >${sds}_sorted_tmp1
sed 's;^\([^ ]*\).*target[^ ]*/\([^ ]*\)/[^ ]*;\1 \2;' $devs|sed 's/[:]//g' >${sds}_sorted_tmp2
sed 's;^\([^ ]*\).*target[^ ]*/\([^ ]*\)/[^ ]*;\1 \2;' $devs|sed 's/[: ]/x/g'|awk -F'x' '{a[x++]=$2 $3 $4 $5;b[y++]=$1;}END{for(i=0;i<x;i++)asort(a,c,"@val_num_asc");for(i=1;i<=x;i++)print c[i]}' >${sds}_sorted_tmp3
awk 'FNR==NR{a[$2]=$1;next}{if($1 in a)print a[$1] FS $1}' ${sds}_sorted_tmp2 ${sds}_sorted_tmp3 >${sds}_sorted_tmp4
awk 'FNR==NR{a[$1]=$2;next}{if($1 in a)print $1 FS a[$1]}' ${sds}_sorted_tmp1 ${sds}_sorted_tmp4 >${sds}_sorted



## centos 5.6 da vendor bilgileri getirilemiyordu..kod genellestirildi. 05-12-2022
for i in $(find /sys/devices/ -name block ) ; do
sdx=$(ls -d "$i"/s[d]* 2>/dev/null|awk -F'/' '{print $NF}')
[ ! -z "$sdx" ] && echo "$sdx" "$(cat ${i/block/vendor})"
done >$sdvendors


#################
## tum sd vendors ( scsi ve sata ) ( dvd ler haric ) icin host-bus-target-lun bilgisi ekleniyor ..
# Eger uncomment lernirsa SATA disk lerde listelenecegi icin vmscsi-host sirasi HATALI gelebiliyor !!!
#awk 'FNR==NR {a[$1]=$2; next}{if($1 in a)print $0,a[$1]}' $sdvendors $sds >$scsisatavendors

## tum sd vendors ( "SADECE scsi = VMware disk ler" ) ( sata ve dvd ler haric ) icin host-bus-target-lun bilgisi ekleniyor ..
#awk 'FNR==NR&&/VMware/{a[$1]=$2; next}{if($1 in a)print $0,a[$1]}' $sdvendors $sds >$scsisatavendors


### ------------------------------------------------------------------------------------------------
# target bilgisi olusturulma tarih sirasina gore = "scsisatavendors"
# eski sds dosyasina gore calisir..
##awk 'FNR==NR{a[$1]=$0; next}{if($1 in a)print a[$1],$NF}' $sds $sdvendors #>$scsisatavendors

## target numarasi sirasina gore ..
awk 'FNR==NR{a[$1]=$2; next}{if($1 in a)print $0,a[$1]}' $sdvendors ${sds}_sorted >$scsisatavendors

## disk isimi sirasina gore ( sda , sdb , sdc .. ) = "scsisatavendors2"
awk 'FNR==NR{a[$1]=$NF; next}{if($1 in a)print $0,a[$1]}' $sdvendors ${sds}_name >$scsisatavendors2

### ------------------------------------------------------------------------------------------------


## 2 dosya ayni mi ?
xx=$(awk 'FNR==NR{a[++x]=$1;next}{++i;if(a[i]!=$1){print $1;exit}}' $scsisatavendors $scsisatavendors2)
if [ ! -z "$xx" ] ; then
scsisame=0
else
scsisame=1
fi



## tum sd vendors ( scsi , sata ) ( dvd ler dahil !! ) icin host-bus-target-lun bilgisi ekleniyor ..
## NOT : bu satir uncomment lenirse dvd ler de listelenir ..
#awk 'FNR==NR {a[$1]=$2; next}{if($1 in a)print $0,a[$1]}' $sdvendors $sdsa >$scsisatavendors



#tum scsi block device lar ( vm scsi_host ) siralamasina bunu dahil etmemek gerekiyor ??
#ls -l /sys/block/|awk -F'/' '/sd/&&!(/virtual/||/session/||/ata/||/usb/||/cd/||/sr/)&&NR>1{sub(/.*host/,"");print "host"$1,$NF}' >${vms}.1


#sadece scsi (VMware disk - vmscsi ) oldugundan emin olalim.
#ornek olarak sata devicelari eleyebiliriz..
## not : sd disk ler VM uzerinden olusturulma sirasiyla gelmeyebilir.. o yuzden iptal !!
#vmwarescsi=$(grep -l VMware /sys/devices/*/*/*/host*/*/*/vendor|sed 's/\/vendor//')
#echo "$vmwarescsi"|while read -r hostdir ; do ls -d "$hostdir"/block/sd* |awk -F'/' '{print $7,$NF}'; done >${vms}.2


## VMware disk sirasi ( sda , sdb , .... sdx )
#ls -l /sys/block/sd*/device|awk -F"/" '{sub(".*block/","");gsub(":"," ");split($NF,a," ");;print a[1],$1}'|\
#awk 'BEGIN{vmh=0;vmt=0;c=1}{if(vmhc!=""){if($1!=vmhc){vmh++;vmt=0;}}print $2,vmh" "vmt++,"Hard Disk "c++;vmhc=$1}' >$vms



vms_complx_create() {
scsifile=$1
vmsofile=$2

#echo 1.DOSYA INPUT ---
#cat $1
#echo 2.DOSYA INPUT --- $(ls -ltr $2)
#cat $2
#echo

#if [ ! -z "$3" ] ; then
#[ $3 -eq 0 ] && fscsifile=$scsifile
#[ $3 -eq 1 ] && scsifile=$fscsifile
#fi


#awk '{print $2 FS $4 FS $1}' $scsifile | \
#awk 'BEGIN{vmh=0;vmt=0;vmhx="[+-X]";c=1;}{p="Hard Disk";fx=$3 FS vmh FS $2;fy=$3 FS vmh vmhx FS $2;\
#while(getline){cc++;
#if($1==vmhc){for(i=1;i<=y;i++)print b[i] FS p FS c++;y=0;if(s==0)a[++x]=fy;;a[++x]=$3 FS vmh vmhx FS $2;;s=1}
#else        {for(i=1;i<=x;i++)print a[i] FS p FS c++;x=0;if(s==0)b[++y]=fx;vmh++;;s=0}
#vmhc=$1;fx=$3 FS vmh FS $2;fy=$3 FS vmh vmhx FS $2;}
#if($1==vmhc){for(i=1;i<=x;i++)print a[i] FS p FS c++}
#if(s==0)print fx FS p FS c++}' > ${vmsofile}

#### ygemici analiz
#echo analiz $scsifile
#awk '{print $2 FS $4 FS $1 FS $NF}' $scsifile | \
#awk 'BEGIN{vmh=0;vmt=0;vmhx="[+-X]";c=1;}{p="Hard Disk";fx=$3 FS vmh FS $2;fy=$3 FS vmh vmhx FS $2;\
#while(getline){;
#if($1==vmhc){for(i=1;i<=y;i++)print b[i] FS p FS c++;y=0;if(s==0)a[++x]=fy;;a[++x]=$3 FS vmh vmhx FS $2;;s=1}
#else        {for(i=1;i<=x;i++)print a[i] FS p FS c++;x=0;if(s==0)b[++y]=fx;vmh++;s=0}
#vmhc=$1;fx=$3 FS vmh FS $2;fy=$3 FS vmh vmhx FS $2;}
#if($1==vmhc){for(i=1;i<=x;i++)print a[i] FS p FS c++; for(i=1;i<=y;i++)print b[i] FS p FS c++}
#if(s==0)print fx FS p FS c++}' > ${vmsofile}

####
#awk '{print $2 FS $4 FS $1 FS $NF}' $scsifile |
#awk 'BEGIN{scsivmh=0;atavmh=0;vmt=0;vmhx="[+-X]";c=0;}{
#if($NF~"ATA"){vmh=atavmh;ataf=1}else vmh=scsivmh;p="Hard Disk";fx=$3 FS vmh FS $2;fy=$3 FS vmh vmhx FS $2;
#while(getline){;
#if($1==vmhc){for(i=1;i<=y;i++)print b[i] FS p FS c++;y=0;if(s==0)a[++x]=fy;;a[++x]=$3 FS vmh vmhx FS $2;;s=1}
#else        {for(i=1;i<=x;i++)print a[i] FS p FS c++;x=0;if(s==0)b[++y]=fx;;if($NF~"ATA"){if(!ataf)vmh=atavmh++;else vmh=++atavmh}else vmh=++scsivmh;s=0}
#vmhc=$1;fx=$3 FS vmh FS $2;fy=$3 FS vmh vmhx FS $2;}
#if($1==vmhc){for(i=1;i<=x;i++)print a[i] FS p FS c++; for(i=1;i<=y;i++)print b[i] FS p FS c++}
#if(s==0)print fx FS p FS c++}' > ${vmsofile}


#### ygemici analiz - SATA destegi eklendi - v2
#awk '{print $2 FS $4 FS $1 FS $NF}' $scsifile | awk 'BEGIN{scsivmh=0;atavmh=0;vmt=0;vmhx="[+-X]";c=1;}{
#if($NF~"ATA"){vmh=atavmh;ataf=1}else vmh=scsivmh;p="Hard Disk";fx=$3 FS vmh FS $2;fy=$3 FS vmh vmhx FS $2;
#while(getline){;
#if($1==vmhc){for(i=1;i<=y;i++)print b[i] FS p FS c++ FS scsiata[i];y=0;if(s==0)a[++x]=fy;scsiata[x]=$NF;;a[++x]=$3 FS vmh vmhx FS $2;;s=1}
#else        {for(i=1;i<=x;i++)print a[i] FS p FS c++ FS scsiata[i];x=0;if(s==0)b[++y]=fx;scsiata[y]=$NF;;if($NF~"ATA"){if(!ataf)vmh=atavmh++;else vmh=++atavmh}else vmh=++scsivmh;s=0}
#vmhc=$1;fx=$3 FS vmh FS $2;fy=$3 FS vmh vmhx FS $2;}
#if($1==vmhc){for(i=1;i<=x;i++)print a[i] FS p FS c++ FS scsiata[i]; for(i=1;i<=y;i++)print b[i] FS p FS c++ FS scsiata[i]}
#if(s==0)print fx FS p FS c++ FS $NF}' > ${vmsofile}



### BURAYA SADECE TARGET NUMARARSI SIRALANMIS OLAN DATA GELMELIDIR !! -> "scsisatavendors" ( ${vms_complx}.$c = vms_complx.0 )

#### ygemici analiz - SATA destegi eklendi - v3
awk '{print $2 FS $4 FS $1 FS $NF}' $scsifile | awk 'BEGIN{scsivmh=0;atavmh=0;vmt=0;vmhx="[+-X]";c=1;}{
if($NF~"ATA"){vmh=atavmh;ataf=1}else vmh=scsivmh;p="Hard Disk";
fx=$3 FS vmh FS $2;fy=$3 FS vmh vmhx FS $2;
vmhc=$1;
while(getline){;
if($1==vmhc){for(i=1;i<=y;i++)print b[i] FS p FS c++ FS scsiata[i];y=0;if(s==0)a[++x]=fy;scsiata[x]=$NF;;a[++x]=$3 FS vmh vmhx FS $2;;s=1}
else        {for(i=1;i<=x;i++)print a[i] FS p FS c++ FS scsiata[i];x=0;if(s==0)b[++y]=fx;scsiata[y]=$NF;;if($NF~"ATA"){if(!ataf)vmh=atavmh++;else vmh=++atavmh}else vmh=++scsivmh;s=0}
fx=$3 FS vmh FS $2;fy=$3 FS vmh vmhx FS $2;vmhc=$1;}
if($1==vmhc){for(i=1;i<=x;i++)print a[i] FS p FS c++ FS scsiata[i]; for(i=1;i<=y;i++)print b[i] FS p FS c++ FS scsiata[i]}
if(s==0)print fx FS p FS c++ FS $NF;}' > ${vmsofile}


#if [ ! -z "$3" ] ; then
#[ $3 -eq 0 ] && awk 1 ${vmsofile} >${vmsofile}.tmp && vmsofiledyn=${vmsofile}.tmp
#[ $3 -eq 1 ] && awk 'FNR==NR{$NF="";a[$1]=$0;c=0;next}{if($1 in a)print a[$1] FS c++}' $vmsofiledyn $scsifile >$vmsofile
#fi

}



case $scsisame in
0)c=0

## scsisatavendors ve scsisatavendors2 AYNI degil
#
for scsisorts in $scsisatavendors $scsisatavendors2
do

## basit vmsci:vmtarget disk yapilandirmasi
######################

if [ $c -eq 0 ] ; then
## ATA destegi
## bazi durumlar icin sorunlu calisiyor gibi ??
#awk '{print $2 FS $1 FS $NF}' $scsisorts|awk 'BEGIN{vmh=0;vmt=0;c=1}{if(vmhc)if($1!=vmhc){vmh++;vmt=0;}print $2,vmh" "vmt++,"Hard Disk "c++,$NF;vmhc=$1}' >${vms}.$c

awk '{print $2 FS $1 FS $NF}' $scsisorts|awk 'BEGIN{vmh=0;vmt=0;c=1}{if($1!=vmhc){vmh++;vmt=0;}print $2,vmh" "vmt++,"Hard Disk "c++,$NF;vmhc=$1}' >${vms}.$c
vms_complx_create $scsisorts ${vms_complx}.$c #$c
cat ${vms_complx}.$c > ${vms}.tmp

else

## ATA destegi yok
#awk '{print $2 FS $1}' $scsisatavendors|awk 'BEGIN{vmh=0;vmt=0;c=1}{if($1!=vmhc){vmh++;vmt=0;}print $2,vmh" "vmt++,"Hard Disk "c++;vmhc=$1}' > ${vms}.tmp

## ATA destegi
#awk '{print $2 FS $1 FS $NF}' $scsisorts|awk 'BEGIN{vmh=0;vmt=0;c=1}{if(vmhc)if($1!=vmhc){vmh++;vmt=0;}print $2,vmh" "vmt++,"Hard Disk "c++,$NF;vmhc=$1}' >${vms}.tmp

### normal degerler icin "$vms" e ihtiyacimiz var..
#awk 'FNR==NR{a[$1]=$0; next}{if($1 in a)print a[$1]}' ${vms}.tmp $scsisorts >${vms}.$c
awk 'NR==FNR{a[$1]=$0;next}{c[y++]=$1}END{for(j=0;j<=y;j++)for(i in a)if(i==c[j])print a[i]}' ${vms}.tmp $scsisorts >${vms_complx}.$c
cat ${vms_complx}.$c > ${vms}.$c

fi


#eski basit complex komutu
#awk '{print $2 FS $4 FS $1}' $i|awk 'BEGIN{vmh=0;vmt=0;c=1;}{if($1!=vmhc)vmh++;else if($2!=vmt){vmhx="+-X"};if(vmhx!="")print $3,vmh"["vmhx"]"" "$2,"Hard Disk "c++;else print $3,vmh" "$2,"Hard Disk "c++;vmhc=$1;vmt=$2;vmhx=""}' >${vms_complx}.$c
((c++))
done
;;



## scsisatavendors ve scsisatavendors2 AYNI
1)c=0

## normal degerler icin "$vms" e ihtiyacimiz var..

## ATA destegi yok
#awk '{print $2 FS $1}' $scsisatavendors|awk 'BEGIN{vmh=0;vmt=0;c=1}{if($1!=vmhc){vmh++;vmt=0;}print $2,vmh" "vmt++,"Hard Disk "c++;vmhc=$1}' >${vms}.$c

## ATA destegi
awk '{print $2 FS $1 FS $NF}' $scsisatavendors|awk 'BEGIN{vmh=0;vmt=0;c=1}{if($1!=vmhc){vmh++;vmt=0;}print $2,vmh" "vmt++,"Hard Disk "c++,$NF;vmhc=$1}' >${vms}.$c


#vms_complx_create $scsisatavendors $vms
vms_complx_create $scsisatavendors ${vms_complx}.$c


#eski basit complex komutu
#awk '{print $2 FS $4 FS $1}' $scsisatavendors|awk 'BEGIN{vmh=0;vmt=0;c=1;}{if($1!=vmhc)vmh++;else if($2!=vmt){vmhx="+-X"};if(vmhx!="")print $3,vmh"["vmhx"]"" "$2,"Hard Disk "c++;else print $3,vmh" "$2,"Hard Disk "c++;vmhc=$1;vmt=$2;vmhx=""}' >$vms_complx
;;
esac
##




##scsi host 0 devre disi
#awk '{print $2 FS $4 FS $1}' $scsisatavendors|awk 'BEGIN{vmh=0;vmt=0;c=1;printx="nok"}{if($1!=vmhc)vmh++;else if($2!=vmt){vmhx="+-X"};if(vmhx!="")print $3,vmh"["vmhx"]"" "$2,"Hard Disk "c++;else print $3,vmh" "$2,"Hard Disk "c++;vmhc=$1;vmt=$2;vmhx=""}' >$vms_complx

#awk '{print $2 FS $4 FS $1}' /tmp/.scsisatavendors|awk 'BEGIN{vmh=0;vmt=0;c=1;printx="nok"}{if($1!=vmhc)vmh++;else if($2!=vmt){if(vmhc!=0)vmhx="+-X"};if(vmhx!="")print $3,vmh"["vmhx"]"" "$2,"Hard Disk "c++;else print $3,vmh" "$2,"Hard Disk "c++;vmhc=$1;vmt=$2;vmhx=""}' >$vms_complx


#awk 'NR==FNR{a[x++]=$1;b[y++]=$2;;next}{c[$1]=$2}END{for(i=0;i<x;i++)print a[i],b[i];for(k in c){y=0;for(i=0;i<x;i++){;if(a[i]!=k)y++};if(y==x)print k}}' $sdsa $sds
#awk '{s[FNR]=(s[FNR] == "" ? "" : s[FNR] "\t<->\t")($0 == "" ? "?" : $0)}END{for (i=1; i<=length(s); i++) print s[i]}' $sds $vms

### sunucuda sadece scsi disk bulunuyorsa disk bilgileri ayni sirada olacagi icin karsilastirma yapmaya gerek yok
#awk 'NR==FNR{a[i++]=$4;b[j++]=$1;c[k++]=$2":"$3":"$4":"$NF;next}{printf "%-5s%-14s%-s%10s%-8s%-10s%-5s\n", b[x++], "[" c[xx++] "]", "<=====>" ,"     VM-scsi(", $1":"a[xxx++]") ", $3" "$4" ",$NF}' ${vms}.2 $vms

## eger sata cdrom larda listelenmek isteniyorsa
#awk 'NR==FNR{a[i++]=$3;b[j++]=$1;c[k++]=$2":"$3":"$4":"$NF;next}{y=0;for(i=0;i<j;i++)if($1==b[i])printf "%-5s%-14s%-s%10s%-8s%-10s%-5s\n", b[i], "[" c[i] "]", "<=====>" ,"     VM-scsi(", $2":"a[i]") ", $4" "$5" ",$NF;else printf "%-5s%-14s\n",b[i], "[" c[i] "]"}' $sds $vms

#awk 'NR==FNR{a[i++]=$3;b[j++]=$1;c[k++]=$2":"$3":"$4":"$NF;next}{y=0;for(i=0;i<j;i++)if($1==b[i])printf "%-5s%-14s%-s%10s%-8s%-10s%-5s\n", b[i], "[" c[i] "]", "<=====>" ,"     VM-scsi(", $2":"a[i]") ", $4" "$5" ",$NF;else printf "%-5s%-14s\n",b[i], "[" c[i] "]"}' $scsisatavendors $vms

#awk 'NR==FNR{a[++i]=$3;b[i]=$1;c[i]=$2":"$3":"$4":"$5;d[i]=$NF;next}{for(k=1;k<=i;k++)if($1==b[k])printf "%-5s%-14s%-10s%s%12s%-8s%-10s%-5s\n", b[k], "[" c[k] "]", d[k], "<=====>" ," VM-scsi(", $2":"a[k]") ", $4" "$5" ",$NF;else printf "%-5s%-14s%-10s\n",b[k], "[" c[k] "]",d[k]}' $scsisatavendors $vms


lsblkchk() {
lsblkod=1
which lsblk &>/dev/null
if [ $? -ne 0 ] ; then
#echo "Sunucuda lsblk bulunamadi !! "
lsblkod=0
fi
}


getdsize(){
## aslinda buraya iletilen tum diskelr parent diskdir.
## ileride partition size bulmak icinde faydali olabilir diye kontrol ekledim.
echo $1|grep '[0-9]\+$' &>/dev/null
if [ $? -eq 0 ] ; then
dparent=$(echo $1|sed 's/[0-9]\+//' )
ssize=$(cat /sys/block/$dparent/queue/hw_sector_size )
bcount=$(cat /sys/block/$dparent/$1/size )
tsize=$(awk -v a=$ssize -v b=$bcount 'BEGIN{print a*b/1024/1024/1024}' )
else
ssize=$(cat /sys/block/$1/queue/hw_sector_size)
bcount=$(cat /sys/block/$1/size )
tsize=$(awk -v a=$ssize -v b=$bcount 'BEGIN{print a*b/1024/1024/1024}' )
fi
}



diskview() {
case $1 in
normal)##IPTAL
;;
complx)out=$fullinfo_complx;vms=$vms_complx;dsksz=$dsksz_complx
### COMPLEX [+-X] li DOSYA OLUSTURMAK GEREKECEK ###
;;
esac
}


######getids#####
getids(){
#echo -normal-complex-
echo -$1-

case $1 in
normal)out=$fullinfo;vms=$vms;dsksz=$dsksz
;;
complx)out=$fullinfo_complx;vms=$vms_complx;dsksz=$dsksz_complx
;;
esac

lsblkchk;

case $scsisame in
0)c=0
for scsisorts in $scsisatavendors $scsisatavendors2 ; do

#awk 'BEGIN{vmhost=1}NR==FNR{a[++i]=$3;b[i]=$1;c[i]=$2":"$3":"$4":"$5;d[i]=$NF;next}{if($2~"X")e[$1]="X:"$3 ; else e[$1]=$2+vmhost":"$3;f[$1]=$4" "$5;g[$1]=$NF;x++}END{for(j=1;j<=i;j++){y=0;for(k in e){if(b[j]==k){printf "%-5s%-16s%-14s%-10s%12s%-18s%-11s%-s\n", b[j], "[" c[j] "]", d[j], "<=====>", " VM-scsi(", e[k] ") ", f[k],g[k];break} else {y++;}if(y==x)printf "%-5s%-16s%-14s\n", b[j], "[" c[j] "]", d[j] }}}' $i ${vms}.$c >${out}.$c

## ATA destegi yok
#awk 'BEGIN{vmhost=0}NR==FNR{a[++i]=$3;b[i]=$1;c[i]=$2":"$3":"$4":"$5;d[i]=$NF;next}{if($2~"X")e[$1]=$2+vmhost"+-X:"$3 ; else e[$1]=$2+vmhost":"$3;f[$1]=$4" "$5;g[$1]=$NF;x++}END{for(j=1;j<=i;j++){y=0;for(k in e){if(b[j]==k){printf "%-5s%-16s%-14s%-10s%12s%-18s%-11s%-s\n", b[j], "[" c[j] "]", d[j], "<=====>", " VM-scsi(", e[k] ") ", f[k],g[k];break} else {y++;}if(y==x)printf "%-5s%-16s%-14s\n", b[j], "[" c[j] "]", d[j] }}}' $scsisorts ${vms}.$c >${out}.$c

#[ $c -gt 0 ] && vmstmp=${vms}.$c || vmstmp=${vms}.$c
## ATA destegi
awk 'BEGIN{vmscsi=0;vmata=0}NR==FNR{a[++i]=$3;b[i]=$1;c[i]=$2":"$3":"$4":"$5;d[i]=$NF;next}{if($NF~"ATA")$2=vmata++;if($2~"X")e[$1]=$2+vmscsi"+-X:"$3;else e[$1]=$2+vmscsi":"$3;f[$1]=$4" "$5" "$6;g[$1]=$NF;x++}END{for(j=1;j<=i;j++){y=0;for(k in e){vmscsix=" VM-scsi";if(g[k]~"ATA")vmscsix=" VM-ata";if(b[j]==k){printf "%-5s%-16s%-14s%-10s%12s%-18s%-11s\n", b[j], "[" c[j] "]", d[j], "<=====>", vmscsix"(", e[k] ") ", f[k];break} else {y++;}if(y==x)printf "%-5s%-16s%-14s\n", b[j], "[" c[j] "]", d[j] }}}' $scsisorts ${vms}.$c >${out}.$c



if [ $lsblkod -eq 1 ] ; then
## disk size bilgilerini ekleyelim..
for i in $(awk '{print $1}' ${out}.$c ); do lsblk -d| awk -v dsk="$i" '$1==dsk{print $1 " ["$4"]"}'; done >$dsksz
else
for j in $(awk '{print $1}' ${out}.$c ); do getdsize $j ; awk -v dsk="$j" -v a=$tsize '$1==dsk{print $1 " ["a"G]"}'; done >$dsksz
fi


### disk isim "name" bilgisine gore sorted sadece "scsisatavendors2" icin gecerlidir..
if [ $c -gt 0 ] ; then
awk 'BEGIN{$25=OFS="-";printf "\n%s",$0 " Name-Sorted[+-X] " }'
awk 'BEGIN{$25=OFS="-";print $0 }'
fi
#####

###
awk 'NR==FNR{++i;a[i]=$0;b[i]=$1;next}{c[$1]=$2;}END{for(j=1;j<=i;j++)for(k in c)if(k==b[j])print a[j] " - " c[k]}' ${out}.$c $dsksz
#awk 'NR==FNR{a[++i]=$0;b[i]=$1;next}{for(j=1;j<=i;j++)if($1~b[j])print a[j] " - " $NF}' ${out}.$c $dsksz

#case $1 in
#normal) diskview $1 ${out}.$c $dsksz
#;;
#complx) diskview $1
#;;
#esac

((c++))
done
awk 'BEGIN{$25=OFS="=";print $0 }'
;;



1)c=0

## ATA destegi yok
#awk 'BEGIN{vmhost=0}NR==FNR{a[++i]=$3;b[i]=$1;c[i]=$2":"$3":"$4":"$5;d[i]=$NF;next}{if($2~"X")e[$1]=$2+vmhost"+-X:"$3 ; else e[$1]=$2+vmhost":"$3;f[$1]=$4" "$5;g[$1]=$NF;x++}END{for(j=1;j<=i;j++){y=0;for(k in e){if(b[j]==k){printf "%-5s%-16s%-14s%-10s%12s%-18s%-11s%-s\n", b[j], "[" c[j] "]", d[j], "<=====>", " VM-scsi(", e[k] ") ", f[k],g[k];break} else {y++;}if(y==x)printf "%-5s%-16s%-14s\n", b[j], "[" c[j] "]", d[j] }}}' $scsisatavendors ${vms}.$c >${out}.$c

## ATA destegi
awk 'BEGIN{vmscsi=0;vmata=0}NR==FNR{a[++i]=$3;b[i]=$1;c[i]=$2":"$3":"$4":"$5;d[i]=$NF;next}{if($NF~"ATA")$2=vmata++;if($2~"X")e[$1]=$2+vmscsi"+-X:"$3;else e[$1]=$2+vmscsi":"$3;f[$1]=$4" "$5" "$6;g[$1]=$NF;x++}END{for(j=1;j<=i;j++){y=0;for(k in e){vmscsix=" VM-scsi";if(g[k]~"ATA")vmscsix=" VM-ata";if(b[j]==k){printf "%-5s%-16s%-14s%-10s%12s%-18s%-11s\n", b[j], "[" c[j] "]", d[j], "<=====>", vmscsix"(", e[k] ") ", f[k];break} else {y++;}if(y==x)printf "%-5s%-16s%-14s\n", b[j], "[" c[j] "]", d[j] }}}' $scsisatavendors ${vms}.$c >${out}.$c



if [ $lsblkod -eq 1 ] ; then
## disk size bilgilerini ekleyelim..
for i in $(awk '{print $1}' ${out}.$c ); do lsblk -d| awk -v dsk="$i" '$1==dsk{print $1 " ["$4"]"}'; done >$dsksz
else
for i in $(awk '{print $1}' ${out}.$c ); do getdsize $i ; awk -v dsk="$i" -v a=$tsize '$1==dsk{print $1 " ["a"G]"}'; done >$dsksz
fi


#echo vmsc=${vms}.$c xx outc=${out}.$c xx $dsksz

awk 'NR==FNR{a[++i]=$0;b[i]=$1;next}{for(j=1;j<=i;j++)if($1~b[j])print a[j] " - " $NF}' ${out}.$c $dsksz


#case $1 in
#normal) diskview $1 ${out}.$c $dsksz
#;;
#complx) diskview $1
#;;
#esac

esac

}



############
if [ -z "$2" ] ; then
### Default sort : Target bilgisi olusturulma sirasi
srtd=0
else
case $2 in
0)srtd=0
;;
1)srtd=1
;;
*)echo "disk siralamasi , target bilgisi yada disk isimlerine gore olabilir !! " ; exit 2
;;
esac
fi




guess1() {
##ygemici 24.07.2023
filex=$1
g=$2

awk -v X="$g" '
BEGIN{
XX=X;sub(".","",X)}
{
XXX=$5;sub("VM-scsi[(]","",$5);sub("[)]","",$5);gsub(/+-X/,"",$5);split($5,d,":");
hdisk=$(NF-2) FS $(NF-1) FS $NF;

if(XXX~"X"){
if(XX~"-")xx=d[1]-XX;;if(XX~"+")xx=d[1]+XX;yy="VM-scsi("xx":"d[2]")"
printf "%-5s%-16s%-14s%-14s%-16s%21s\n",$1,$2,$3,$4,yy,hdisk
a[x++]=xx d[2];
}

if(XXX!~"X"){
neq=1
for(i=0;i<x;i++){
if(a[i]==d[1] d[2]){
neq=0;break}
}

if(neq==0)
{
for(i=0;i<x;i++){
if(a[i]>d[1] d[2])
dt=d[1]+1
if(a[i]<d[1] d[2])
dt=d[1]-1
}
a[i]=dt d[2]
yy="VM-scsi("dt":"d[2]")"
printf "%-5s%-16s%-14s%-14s%-16s%21s\n",$1,$2,$3,$4,yy,hdisk
}

if(neq==1){
yy="VM-scsi("d[1]":"d[2]")"
printf "%-5s%-16s%-14s%-14s%-16s%21s\n",$1,$2,$3,$4,yy,hdisk
a[x++]=d[1] d[2];
}
}
}' $filex

}



guess2() {
### X degerlerini onceden almak gerekiyor.
### Cunku eger X degerleri SON satirda yer aliyorsa ve oncesindeki X olmayan satirlara atanan degerler ile
### cakisirsa bunun tespiti yapilip oncesindeki (zaten print edilmis ) target degerleri degistirilemez !!

filex=$1
g=$2


xval=$(awk -v X="$g" '
BEGIN{
XX=X;sub(".","",X)}
{
XXX=$5;sub("VM-scsi[(]","",$5);sub("[)]","",$5);gsub(/+-X/,"",$5);split($5,d,":");
if(XXX~"X"){
if(XX~"-")xx=d[1]-X;
if(XX~"+")xx=d[1]+X;
print xx
}
}' $filex
)




### 2. AWK
### esas target siralamasi burda yapiliyor. !!!
###

awk -v X="$g" -v aa="${xval[@]}" '
BEGIN{cc=split(aa,vals);for(i=1;i<=cc;i++)xvals[vals[i]];
XX=X;sub(".","",X)
}

{
XXX=$5;sub("VM-scsi[(]","",$5);sub("[)]","",$5);gsub(/+-X/,"",$5);split($5,d,":");


### X degerleri
if(XXX~"X")
{
if(XX~"-")xx=d[1]-X;
if(XX~"+")xx=d[1]+X;
yy="VM-scsi("xx":"d[2]")x";
b[xx];
e[xc++]=$1 FS $2 FS $3 FS $4 FS yy FS $(NF-2) FS $(NF-1) FS $NF
}


### Normal degerler
if(XXX!~"X")
{
#Normal degerler (d[1]) , newd degerlerine cevriliyor..

#Eger d[1] degeri daha onceden newd icine eklenmediyse..
if(!(d[1] in newd))
{
# yeni deger verdigimiz d[1] degerleri dizinde saklaniyor..
if(!dt)dt=0
if(first++)newd[d[1]]=dt++;else newd[d[1]]=dt

###Yeni olusturulan dt degerleri eger X degerlerin icinde de yer aliyorsa
#if(dt in b)
#{
#print "Xde yer aliyor",dt,c[y-1]
#if(dt>c[y-1]){while(c[y-1]<newdt){newdt--;if(newdt<=c[y-1]+1)break}}
#if(dt<=c[y-1]){while(c[y-1]>=newdt){print "GIRDI2";newdt++;if(newdt>=c[y-1]+1)break}}
#print "Xde cikti",dt
#}

yy="VM-scsi("dt":"d[2]")";
a[x++]=dt;f[dt];
newd[d[1]]=dt;
}

#Normal degerler , newd nin icinde zaten yer aliyorsa oldugu gibi kaliyor..
else{
#print "ESKI DT=",d[1]
yy="VM-scsi("newd[d[1]]":"d[2]")";
f[d[1]];
}

e[xc++]=$1 FS $2 FS $3 FS $4 FS yy FS $(NF-2) FS $(NF-1) FS $NF

}
}



END{

for(i in f){
if(i in xvals)
dif[i]
}


for(kk=0;kk<xc;kk++){
split(e[kk],dd);
hdisk=dd[6] FS dd[7] FS dd[8];

xxx=dd[5];
sub("VM-scsi[(]","",xxx);sub("[)]","",xxx);split(xxx,ddd,":")


####test
#print dd[5],"test"


####################
# Normal bir degerse
####################
if(xxx!~"x")
{

#print "GELEN",ddd[1]
newdt=ddd[1]
olddt=ddd[1]


# Mevcut deger Yeni degistirilmis degerler arasinda yer almiyorsa
if(!(olddt in news))
{
#olddt(var olan mevcut deger) icin Yeni bir deger olusturulmali

#print "xx_1=",newdts[xx-1]
if(newdts[xx-1]){
while(newdt>newdts[xx-1]){newdt--;if(newdt<=newdts[xx-1]+1)break}
while(newdt<newdts[xx-1]){newdt++;if(newdt>=newdts[xx-1]-1)break}
if(olddt!=newdt){newdts[xx++]=newdt;news[olddt]=newdt}
}

# X degerleri arasinda yer aliyor mu
if(newdt in b)
{
#print "newdt=",newdt,"degeri var X li degerler arasinda yer aliyor"
#print "X li kume = ";for(i in b)print i;

while(newdt in b){newdt++;if(!(newdt in b))break}
#print newdt,"degeri icin",newdt,"degeri zaten verilmisti"
if(olddt!=newdt)newdts[xx++]=newdt;
#print "newdt=",newdt
}

for(i in news){if(news[i]==newdt)newdt++;}
while(newdt in b){newdt++;if(!(newdt in b))break}
news[olddt]=newdt
#print "SONUC1= ",newdt
}

# Yeni degistirilmis degerler arasinda yer aliyorsa
else
{
#print "OLD",olddt,news[olddt]
for(i in news){if(news[i]==newdt)newdt++;}
newdt=news[olddt]
#print "SONUC2= ",newdt

# X degerleri arasinda yer aliyor mu
#if(newdt in b)
#{
#print "Xile2",newdt,"Xli deger cakisti"
#while(newdt in b){newdt++;if(!(newdt in b))break}
#if(olddt!=newdt){newdts[xx++]=newdt;print olddt,"degeri ekleniyor",newdt;news[olddt]=newdt}
#}
}

sub(ddd[1]":",newdt":",dd[5]);
printf "%-5s%-16s%-14s%-14s%-16s%21s\n",dd[1],dd[2],dd[3],dd[4],dd[5],hdisk
}


# X li degerler
else
{
sub("x","",dd[5]);
printf "%-5s%-16s%-14s%-14s%-16s%21s\n",dd[1],dd[2],dd[3],dd[4],dd[5],hdisk
}

}

}' $filex
}





show_guess() {
outguess=$1
awk 'NR==FNR{++i;a[i]=$0;b[i]=$1;next}{c[$1]=$2;}END{for(j=1;j<=i;j++)for(k in c)if(k==b[j])print a[j] " - " c[k]}' $outguess $dsksz
}

print_guess() {
printguess=$1
cc=$2
g=$3
####Guess-X####
case $2 in
1|2)a="target"
;;
3|4)a="name";cc=$((cc-2))
;;
esac

awk -v x=$cc -v y="$a" 'BEGIN{$25=OFS="-";printf "\n%s%d [%s] ",$0 " Guess(+-X)-",x,y}'
awk 'BEGIN{$25=OFS="-";print $0 }'

### Guess/guess/GUESS kodu burda giriliyor... ###
####################################################
awk -v a="$g" '/X/{y=$5;sub("VM-scsi[(]","",y);sub("[)]","",y);sub(/\[.*\]/,"",y);split(y,d,":");x=a;sub("^.","",x);if(a~"+")yy=d[1]+x;else yy=d[1]-x;if(yy<0)yy=0;yyy="VM-scsi("yy":"d[2]")";xx=" "$9" "$10;printf "%-5s%-16s%-14s%-14s%-20s%10s%5s%3s%-10s\n",$1,$2,$3,$4,yyy,$6,$7,$8,xx}!/X/{printf "%s\n",$0}' $printguess
####################################################
}


getidsguess() {
g="$1"
#arama icin "$g" # tahmini guess -1

out_guess=$fullinfo_guess
show_guess=${fullinfo_guess}_show
dsksz=$dsksz_complx

##Eger sirali diskler icin de Guess konfig calisacaksa for dongusu enable edilmeli
c=1
#for i in ${fullinfo_complx}.$((c++)) ${fullinfo_complx}.$((c++)) ; do
#out=$i
#done

## target bilgisi olusturulma tarih sirasina gore = 0
#[ $srtd -eq 0 ] && out=${fullinfo_complx}.0

## disk isimi sirasina gore ( sda , sdb , sdc .. ) = 1
#[ $srtd -eq 1 ] && out=${fullinfo_complx}.1

#${fullinfo_complx}.0 = target numarasi siralamasi
#${fullinfo_complx}.1 = disk ismi siralamasi


for fullinfoguess in ${fullinfo_complx}.0 ${fullinfo_complx}.1
do


####guess####
guess1 $fullinfoguess "$g" > ${out_guess}.$c
show_guess ${out_guess}.$c > ${show_guess}.$c
print_guess ${show_guess}.$c $c "$g"

((c++))


guess2 $fullinfoguess "$g" > ${out_guess}.$c
show_guess ${out_guess}.$c > ${show_guess}.$c
print_guess ${show_guess}.$c $c "$g"

((c++))

#############




###DISABLED SOME CODE @ygemici
####guess-Xhost####
#### gerek yok bu kadar DETAYa
#awk '{x=$5;gsub("VM-scsi","",x);++i;;a[i]=$0;b[i]=x;}END{for(k=1;k<=i;k++){x=0;for(j=1;j<=i;j++){if(k!=j)if(b[k]==b[j]){c++;if(c%2)dup[c+1]=a[k];else dup[c-1]=a[k];break}x++}if(x==i)norm[++l]=a[k]}for(y=1;y<=l;y++){if(norm[y])print norm[y];if(dup[y])print dup[y]}}' $fullinfo_guess_chk >$fullinfo_guess_tmp


#####24.07.2023 IPTAL ettim. Gereksiz complex duruma gerek yok !! #####
##awk 'BEGIN{$25=OFS="-";printf "\n%s",$0 " Guess-UnKnown-config " }'
#awk 'BEGIN{$25=OFS="-";print $0 }'
#awk '{x=$5;gsub("VM-scsi","",x);++i;;a[i]=$0;b[i]=x;}END{for(k=1;k<=i;k++){x=0;for(j=1;j<=i;j++){if(k!=j)if(b[k]==b[j]){c++;if(c%2)dup[c+1]=a[k];else dup[c-1]=a[k];break}x++}if(x==i)norm[++l]=a[k]}for(y=1;y<=l;y++){if(norm[y])print norm[y];if(dup[y])print dup[y]}}' $fullinfo_guess_chk|awk '/X/{a[++x]=$0;c=NR;}!/X/{if(c){y=$5;sub("VM-scsi[(]","",y);sub("[)]","",y);split(y,d,":");yy=d[1]++;yyy="VM-scsi("d[1]":"d[2]")";xx=" "$9" "$10;printf "%-5s%-16s%-14s%-10s%17s%17s%5s%3s%-10s\n",$1,$2,$3,$4,yyy,$6,$7,$8,xx}else print $0}END{for(i=1;i<=x;i++)print a[i]}'

#awk '/X/{a[++x]=$0;c=NR;}!/X/{if(c){y=$5;sub("VM-scsi[(]","",y);sub("[)]","",y);split(y,d,":");;yyy="VM-scsi("d[1]":"d[2]")";xx=" "$9" "$10;printf "%-5s%-16s%-14s%-10s%16s%18s%5s%3s%-10s\n",$1,$2,$3,$4,yyy,$6,$7,$8,xx}else print $0}END{for(i=1;i<=x;i++)print a[i]}' $fullinfo_guess_tmp


#awk 'NR==FNR{a[++i]=$0;b[i]=$1;next}{for(j=1;j<=i;j++)if($1~b[j])print a[j] " - " $NF}' $fullinfoguess $dsksz >${fullinfoguess}.cmplx
awk 'NR==FNR{++i;a[i]=$0;b[i]=$1;next}{c[$1]=$2;}END{for(j=1;j<=i;j++)for(k in c)if(k==b[j])print a[j] " - " c[k]}' $fullinfoguess $dsksz >${fullinfoguess}.cmplx

###Eger Unknown durumda olanlar ilk sirada olmayacaksa Enable edilebilir !!
#awk 'NR==1{if(/X/){x="ok";split($2,a,":");sub(/\[/,"",a[1]);xc=a[1];if(xc==0)print;else unk[i++]=$0}if(!/X/){print}x="nok"} NR>1{if(/X/){if(x=="ok"){split($2,a,":");sub(/\]/,"",a[1]);if(xc==0){if(a[1]==0)print;else unk[i++]=$0}}else unk[i++]=$0;}if(!/X/){print}x="nok"}END{for(j=0;j<i;j++)print unk[j]}' ${fullinfoguess}.cmplx


###Unknown durumda olanlar ilk siralara getirilir..
#awk 'NR==1{if(!/X/){x="ok";split($2,a,":");sub(/\(/,"",a[1]);xc=a[1];if(xc==0)print;else unk[i++]=$0}if(/X/){print}x="nok"} NR>1{if(!/X/){if(x=="ok"){split($2,a,":");sub(/\]/,"",a[1]);if(xc==0){if(a[1]==0)print;else unk[i++]=$0}}else unk[i++]=$0;}if(/X/){print}x="nok"}END{for(j=0;j<i;j++)print unk[j]}' ${fullinfoguess}.cmplx

#[ $c -eq 1 ] && mess=" Guess-UnKnown-config-Target-Sorted " || mess=" Guess-UnKnown-config-Name-Sorted "
#awk -v a="$mess" 'BEGIN{$25=OFS="-";printf "\n%s",$0 a}'
#awk 'BEGIN{$25=OFS="-";print $0 }'
#awk 'NR==FNR{++i;a[i]=$0;b[i]=$1;next}{c[$1]=$0}END{for(j=1;j<=i;j++)for(k in c)if(k==b[j])print c[k]}' $out_tmp ${fullinfoguess}.cmplx

#awk 'BEGIN{$50=OFS="-";print $0 }'
done

}


checkguessprm() {
echo "$1"|grep '^[-+][0-9]\+$' &>/dev/null
if [ $? -ne 0 ] ; then
echo
echo "Tahmin degerleri icin +1 yada -1 gibi sayisal degerler kullanilabilir !! "
exit 2
fi
}


###getids###
#awk 'BEGIN{$50=OFS="=";print $0; }'

## target bilgisi (target-host)
## ( VM uzerinde disk eklenme tarihi olabilir ?? .. yada VM uzerinde hangi SCSi host-target bilgisi ile eklendigine gor siralama degisebilir ?? )
## or : /sys/devices/pci0000:00/0000:00:15.0/0000:03:00.0/host0/target0:0:0/0:0:0:0
#root@ksunxtestr ~]# ls -l /sys/devices/*/*/*/host*/*/*/vendor
#-r--r--r-- 1 root root 4096 Sep 12 18:04 /sys/devices/pci0000:00/0000:00:07.1/ata2/host5/target5:0:0/5:0:0:0/vendor
#-r--r--r-- 1 root root 4096 Sep 12 18:04 /sys/devices/pci0000:00/0000:00:15.0/0000:03:00.0/host0/target0:0:0/0:0:0:0/vendor
#-r--r--r-- 1 root root 4096 Sep 12 18:04 /sys/devices/pci0000:00/0000:00:15.1/0000:04:00.0/host1/target1:0:0/1:0:0:0/vendor
#-r--r--r-- 1 root root 4096 Sep 12 18:04 /sys/devices/pci0000:00/0000:00:15.1/0000:04:00.0/host1/target1:0:1/1:0:1:0/vendor
#-r--r--r-- 1 root root 4096 Sep 12 18:04 /sys/devices/pci0000:00/0000:00:17.0/0000:13:00.0/host2/target2:0:0/2:0:0:0/vendor
#-r--r--r-- 1 root root 4096 Sep 12 18:04 /sys/devices/pci0000:00/0000:00:17.0/0000:13:00.0/host2/target2:0:1/2:0:1:0/vendor
#-r--r--r-- 1 root root 4096 Sep 12 18:04 /sys/devices/pci0000:00/0000:00:18.0/0000:1b:00.0/host3/target3:0:0/3:0:0:0/vendor


## disk ismi sirasina gore ( sda , sdb , sdc .. ) = 1
## or :
#[root@ksunxtestr ~]# ls -l /sys/block/s[dr]*/device
#lrwxrwxrwx 1 root root 0 Aug 22 11:48 /sys/block/sda/device -> ../../../0:0:0:0
#lrwxrwxrwx 1 root root 0 Aug 22 11:48 /sys/block/sdb/device -> ../../../1:0:0:0
#lrwxrwxrwx 1 root root 0 Aug 22 11:48 /sys/block/sdc/device -> ../../../1:0:1:0
#lrwxrwxrwx 1 root root 0 Aug 22 11:48 /sys/block/sdd/device -> ../../../2:0:0:0
#lrwxrwxrwx 1 root root 0 Aug 22 11:48 /sys/block/sde/device -> ../../../3:0:0:0
#lrwxrwxrwx 1 root root 0 Aug 22 11:48 /sys/block/sdf/device -> ../../../2:0:1:0
#lrwxrwxrwx 1 root root 0 Aug 22 11:48 /sys/block/sr0/device -> ../../../5:0:0:0

#[root@ksunxtestr ~]# ls -l /sys/block/s[dr]*/device|awk -F"/" '{sub(".*block/","");gsub(":"," ");print $1,$NF}'
#sda 0 0 0 0
#sdb 1 0 0 0
#sdc 1 0 1 0
#sdd 2 0 0 0
#sde 3 0 0 0
#sdf 2 0 1 0
#sr0 5 0 0 0

##lssci
#[root@ksunxtestr ~]# lsscsi -x
#[0:0:0:0x0000]              disk    VMware   Virtual disk     2.0   /dev/sda
#[1:0:0:0x0000]              disk    VMware   Virtual disk     2.0   /dev/sdb
#[1:0:1:0x0000]              disk    VMware   Virtual disk     2.0   /dev/sdc
#[2:0:0:0x0000]              disk    VMware   Virtual disk     2.0   /dev/sdd
#[2:0:1:0x0000]              disk    VMware   Virtual disk     2.0   /dev/sdf
#[3:0:0:0x0000]              disk    VMware   Virtual disk     2.0   /dev/sde
#[5:0:0:0x0000]              cd/dvd  NECVMWar VMware IDE CDR10 1.00  /dev/sr0


### Eger scsi host tanimlarinda "aynı host farklı target ( or: 3:0 - 3:1 )" bilgisi varsa bir tahmin-guess durumu olusturulabilir.
### Cunku farkli target ler VM tarafinda farkli VMhost bilgisi ile temsil edilebilir ??
###tahmin###

case $scsisame in
0)
## target numarasi sirasina gore = 1
grep 'X' "${vms_complx}.0" &>/dev/null
xcmpl=$?
############################################################
;;

#1)
### disk isim sirasi(target dosya olusturulma tarih sirasina) gore = 0
#grep 'X' "${vms_complx}.0" &>/dev/null
#xcmpl=$?
#;;
#esac

*)xcmpl=1
;;
esac


if [ $xcmpl -eq 0 ] ; then

for i in normal complx ; do
awk 'BEGIN{$50=OFS="-";print $0; }'
getids $i
echo
done

if [ -z "$1" ] ; then
#default tahmin -1 scsi host
getidsguess "-1"
else
checkguessprm $1
getidsguess "$1"
fi

else
getids normal
fi



### tmp dosyalari temizleyelim.
remove_tmp() {
for i in $vms ${vms}.0 ${vms}.1 ${vms}.tmp $vmstmp ${vmstmp}.0 ${vmstmp}.1 ${vmstmp}.tmp ${vms_complx}.0 ${vms_complx}.0.tmp ${vms_complx}.1 $sds $sdvendors $scsisatavendors $scsisatavendors2 $dsksz $dsksz_complx $dsksz_bck $fullinfo ${fullinfo}.0 ${fullinfo}.1 $fullinfo_complx ${fullinfo_complx}.0 ${fullinfo_complx}.1 ${fullinfo_complx}.0.cmplx ${fullinfo_complx}.1.cmplx $fullinfo_complx_guess $fullinfo_guess $fullinfo_guess_chk $fullinfo_guess_tmp $fullinfosz $devs ${sds}_sorted ${sds}_name ${show_guess}.1 ${show_guess}.2 ${show_guess}.3 ${show_guess}.4 ${out_guess}.1 ${out_guess}.2 ${out_guess}.3 ${out_guess}.4
do
[ -f $i ] && rm $i
##cd /tmp && ls -1al|grep -v ^d|awk '$NF~"^[.]"{print $NF}'|while read file ; do rm -f $file; don
done
}

remove_tmp;


### SON ###

## yucel gemici ##
