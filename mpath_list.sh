### unix.com @ygemici MULTIPATH DETAILS SCRIPT
## use bash || ksh
#/* 2016_01_01 */
#/* update : 2025_02_07 */
##############################################

# for understandable outputs ,
## use systool tool
#systool -c fc_transport -v
#systool -c fc_host -v
##############################################

# best way use the mapdevs
#./mapdevs -gwtH
# Dwight(Bud) Brown *( REDHAT )
# http://people.redhat.com/bubrown/iopseudo/mapdevs.tar
##############################################

###exs

#ex-1
#[root@xxxx ~]# bash mpath_list.sh dev=sda
#usinggg [ Fri Feb  7 14:03:03 +03 2025 ] mpath infos..
#==================================================================================

#==================================================================================
#STORAGE DRIVER DEVICES
#==================================================================================
#sda is not a multipath device!!
#[root@xxxx ~]


#ex-2
#[root@xxxx ~]# bash mpath_list.sh dev=sdg yes
#mpaths names not found !! probably alias names used [OK]
#creaing mpath results file...
#usinggg [ Fri Feb  7 14:07:01 +03 2025 ] mpath infos..
#==================================================================================

#==================================================================================
#STORAGE DRIVER DEVICES
#==================================================================================
#backup (3624a937024c4139093df4e3c0003bc72) dm-3 PURE,FlashArray
#[backup 253,3 dm-3]   [PARTITIONS] \__ [backup1 253,6 dm-6]
#size=500G features='0' hwhandler='1 alua' wp=rw
#[CONTROLLER 1] `-+- policy='service-time 0' prio=50 status=active
#host1 0x100yyyyyyyyyyyyy[wwn]-> 0x200azzzzzzzzzzzz[swport] |- 1:0:0 0x524axxxxxxxxxxxx[twwn] sdc 8:32 active ready running
#host1 0x100yyyyyyyyyyyyy[wwn]-> 0x200azzzzzzzzzzzz[swport] |- 1:0:1 0x524axxxxxxxxxxxx[twwn] sdg 8:96 active ready running
#host3 0x100yyyyyyyyyyyyy[wwn]-> 0x2014zzzzzzzzzzzz[swport] |- 3:0:1 0x524axxxxxxxxxxxx[twwn] sdo 8:224 active ready running
#host3 0x100yyyyyyyyyyyyy[wwn]-> 0x2014zzzzzzzzzzzz[swport] `- 3:0:0 0x524axxxxxxxxxxxx[twwn] sdk 8:160 active ready running
#                ====host1 de:00.0 Fibre Channel: QLogic Corp. ISP2722-based 16/32Gb Fibre Channel to PCIe Adapter (rev 01)
#                ====host3 de:00.1 Fibre Channel: QLogic Corp. ISP2722-based 16/32Gb Fibre Channel to PCIe Adapter (rev 01)
#[root@xxxx ~]#


#ex-3
#[root@xxxx ~]# bash mpath_list.sh mpath=backup
#usinggg [ Fri Feb  7 14:07:01 +03 2025 ] mpath infos..
#==================================================================================

#==================================================================================
#STORAGE DRIVER DEVICES
#==================================================================================
#backup (3624a937024c4139093df4e3c0003bc72) dm-3 PURE,FlashArray
#[backup 253,3 dm-3]   [PARTITIONS] \__ [backup1 253,6 dm-6]
#size=500G features='0' hwhandler='1 alua' wp=rw
#[CONTROLLER 1] `-+- policy='service-time 0' prio=50 status=active
#host1 0x100yyyyyyyyyyyyy[wwn]-> 0x200azzzzzzzzzzzz[swport] |- 1:0:0 0x524axxxxxxxxxxxx[twwn] sdc 8:32 active ready running
#host1 0x100yyyyyyyyyyyyy[wwn]-> 0x200azzzzzzzzzzzz[swport] |- 1:0:1 0x524axxxxxxxxxxxx[twwn] sdg 8:96 active ready running
#host3 0x100yyyyyyyyyyyyy[wwn]-> 0x2014zzzzzzzzzzzz[swport] |- 3:0:1 0x524axxxxxxxxxxxx[twwn] sdo 8:224 active ready running
#host3 0x100yyyyyyyyyyyyy[wwn]-> 0x2014zzzzzzzzzzzz[swport] `- 3:0:0 0x524axxxxxxxxxxxx[twwn] sdk 8:160 active ready running
#                ====host1 de:00.0 Fibre Channel: QLogic Corp. ISP2722-based 16/32Gb Fibre Channel to PCIe Adapter (rev 01)
#                ====host3 de:00.1 Fibre Channel: QLogic Corp. ISP2722-based 16/32Gb Fibre Channel to PCIe Adapter (rev 01)
#[root@xxxx ~]#

helpman() {
awkman 82;
echo "usage -> $0 'mpath1 mpath2 .. mpathxx' 'recalculate_mpaths[yes|no]'"
echo "usage -> $0 'dev=sda,sdb .. sdxx' 'recalculate_mpaths[yes|no]'"
echo "usage -> $0 'mpath=data01,data02 .. dataxx ' 'recalculate_mpaths[yes|no]'"
awkman 82;
echo "usage -> $0 --> write all paths and calculate all paths infos , if last calculation time is more than 1 day [ default ]"
echo "usage -> $0 'mpath1 yes' --> write only mpath1 and calculate all paths [ force ]"
echo "usage -> $0 'mpath1 mpath2 no' --> write mpath1 and mpath2 and no calculate all paths infos [ force ]"
awkman 82;
}

trap 'kill -9 $!' 2

direct_results()
{
if [[ ! -z $1 ]] ; then
awk 'BEGIN{print}/'$1'/{print;f=1;next}/^ *$/{f=0}f' mpath_results
else
echo;more mpath_results
fi
}

awkman() {
awk 'BEGIN{$'$1'=OFS="=";print}'
}

results()
{
multipath -l 2>&1 >/dev/null
if [ ! $? -eq 0  ] ; then
echo "multipath not found!!"
exit 1
fi

multipath -l |awk '/mpath/{print $1}' > mpaths
if [ ! -s mpaths ] ; then
echo "mpaths names not found !! probably alias names used [OK] "
echo
sleep 1
multipath -l|awk '/dm-/{print $1}' > mpaths
fi
if [ ! -s mpaths ] ; then
echo "mpaths names not found too !! [FAIL] "
exit 1
fi

printf "%s\n" "creating mpath results file..."
while [ ! -f mpath_results_last_created ]
do
printf "%c" "."
sleep 1
done &

>mpathsds ; while read -r mpath ; do
( multipath -ll $mpath ; echo "" ) >> mpathsds
done < mpaths

#below commented , because some systems has not sdxs:target maps
#ls -ltr /dev/disk/by-path/|sed 's/.*\(0x.*\):.*\/\(.*\)$/\1 \2/'|grep -v total|grep -v '/' > /tmp/sdpaths

grep "" /sys/class/fc_transport/*/port_name|sed 's/.*\(target\)\(.*\)\/port.*:\(.*\)/\1 \2 \3/' > host_ch_id_lun

awk 'NR==FNR{a[$2];b[$2]=$3;next}{for(rport in a)if($2":"~rport":"){$2=$2"[hcil]" FS b[rport] "[twwn]";$1=FS $1};if($0~"prio")$0="[CONTROLLER " ++c "]"FS $0;if($1~"mpath")c=0;print $0}' host_ch_id_lun mpathsds > full2

ls -ltr /dev/sd*|sed 's/.*\/\(.*\)/\1/' > diskparts

awk 'NR==FNR{a[$1];next}{if($4 in a){c=0;for(i=1;i<=9;i++){if(!($4 i in a))c++};if(c==9){$4=$4"[no partition]";b[x++]=$0}else b[x++]=$0}else b[x++]=$0}END{for(j=0;j<x;j++)print b[j]}' diskparts full2 > full3


ls -ltr /dev/mapper/* |awk '{sub("../","",$NF);sub("/dev/mapper/","",$(NF-2));print $NF,$(NF-2)}' > mpaths2
ls -ltr /dev/dm*|sed 's/[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* \([^ ]*,\) *\([^ ]*\).*\/\(.*\)$/\3 \1\2/' >dms
awk 'NR==FNR{a[$1]=$2;next}{if($1 in a)print $1,$2,a[$1]}' mpaths2 dms > full4
#awk 'NR==FNR{a[$NF]=$3 FS $2 FS $1;next}{if($1 in a){printf "%30s\n%15s%15s",$0,"["a[$1]"]","[PARTITIONS]";for(i=0;i<=9;i++){if(a[$1 i])printf "%20s","\\__ ["a[$1 i]"]"}printf "%s","\n"} else print }' full4 full3 > full5
awk 'NR==FNR{a[$NF]=$3 FS $2 FS $1;next}{if($1 in a){printf "%30s\n%15s%15s",$0,"["a[$1]"]","[PARTITIONS]";for(i=0;i<=9;i++){if(a[$1 i])printf "%20s","\\__ ["a[$1 i]"]";if(a[$1 "p" i])printf "%20s","\\__ ["a[$1  "p" i]"]"}printf "%s","\n"} else print }' full4 full3 > full5

>fullports ;
for host in $(ls -1d /sys/class/fc_host/host*|awk -F '/' '{print $NF}'); do
pci=$(find /sys/ -name "host[0-9]*"|sed -n '/.*pci.*'$host'/{s/.*\/.*:\(.*:.*\)\/'$host'/\1/p;q}')
#pci=$(find /sys/ -name "host[0-9]*"|sed -n '/'$host'/s/.*\/.*:\(.*:.*\)\/'$host'/\1/p');
swport=$(cat /sys/class/fc_host/$host/fabric_name 2>/dev/null);
[[ $? -eq 1 ]] && swport="[?]"
hostwwn=$(cat /sys/class/fc_host/$host/port_name 2>/dev/null)
awk -vhost=$host -vpci="$(lspci -s $pci)" 'BEGIN{print host FS pci }' >> fullports;
for rport in $(ls -1d /sys/class/fc_host/$host/device/rport-*|awk -F'/' '{print $NF}'); do
grep -H "FCP" /sys/class/fc_remote_ports/$rport/roles 2>/dev/null|
awk -F '/' -vhost="$host" -vhostwwn="$hostwwn" -vswport="$swport" '{print host,hostwwn"[wwn]->",swport"[swport]",$(NF-1)}'; done;
done >> fullports

awk 'NR==FNR{sub("rport-","",$NF);sub("-",":",$NF);;fullrec[$NF]=$1 FS $2 FS $3;;if($0~"Fibre")hbaports[$1]=$0;next}
{
if($1~/dm-/||/size/||/prio/)print $0;
else{if(!NF){for(hba in writehba){if(writehba[hba]){printf "%20s%50s\n","====",writehba[hba];writehba[hba]=""}}printf "%s","\n"}
hcil=$2;;sub(/:.*/,"",hcil);
if("host"hcil in hbaports){writehba["host"hcil]=hbaports["host"hcil];;sub(/:[0-9]*\[.*/,"",$2)};
if(fullrec[$2])print fullrec[$2] FS $0 ;else print}
}' fullports full5 > mpath_results

date +'%s' > mpath_results_last_created
}

echoes() {
echo "usinggg [ $(date -d @"$1" ) ] mpath infos.."
awkman 82;
}

check_mpaths() {
>newmpths
multipath -ll|awk '$1~"mpath"{mps[$1]++}END{for(i in mps)print i}' > multipaths
if [ ! -s "multipaths" ] ; then
echo "mpaths names not found !! probably alias names used [WARN] "
awkman 82
grep alias /etc/multipath.conf |grep -v '#'
else
awk 'NR==FNR{a[$1];next}{paths[$1]++
if(!($1 in a))c++
else print $1
}
END{
if(c==0)exit 2
if(c==length(paths)){
for(i=0;i<82;i++)printf "%c","="
print "\nmpaths not found!! \n=== Avaliable mpath(s): ==="
for(i in a)print i;exit 1}
}' multipaths paths > newpaths
fi

if [ ! -s "newpaths" ] ; then
echo "mpaths not detected !! [FAIL] "
exit 1
fi


case $? in
0) awkman 82 ;;
1) awkman 82; exit 1 ;;
esac
}

check_dates() {
datelast=$(cat mpath_results_last_created 2>/dev/null)
[[ -z $datelast ]] && datelast=$(date +'%s')
datediff=$(( ( $(date +'%s') - $datelast ) ))
if [ $datediff -gt 86400 ] ; then
echoes "$(date +'%s')";
results;
else
if [ -f "mpath_results" ] ; then
echoes "$(cat mpath_results_last_created)";
else
echo "results file not found!!"
fi
fi
}


indirect_results(){
for i in $@ ; do direct_results $i ; done
}

isnew_paths() {
if [ ! -s "newpaths" ] ; then
exitpaths="1";
fi
}

isnew_sds() {
if [ ! -s "oksds" ] ; then
exitsds="1";
fi
}

sddev() {
#awk -v dev="$1" '{b=$1;while(getline&&NF)a[b]=a[b] RS $0}END{for(i in a){if((a[i]~dev FS)||(a[i]~dev"\\["))print RS i,dev RS"============",a[i];else c++}if(length(a)==c)print "\n" dev " is not a multipath device!!\n" }' mpath_results
devx=$1
awk -v dev="$devx" '{if(($0~dev " ")||($0~dev"\\[")){c="ok";print $0 "\n"}}END{if(!c)print dev " is not a multipath device!!\n"}' RS= mpath_results
}

getdevs() {
dev=$(echo "$1"|sed 's/dev.*=\(.*\)/\1/')
sds=$(echo "$dev"|awk -F',' 'BEGIN{OFS=" "}{for(i=1;i<=NF;i++)print $i >> "newsds" }')
}

check_sds() {
sed -n '/[0-9]$/!p' diskparts > sddevs
awk 'NR==FNR{a[$1];next}{if($1 in a)print $1 >> "oksds";else print $1 " device cannot be found in the system!!" }' sddevs newsds
}


mpthdev() {
devx=$1
awk -v dev="$devx" '{if($0~dev " "){c="ok";print $0 "\n"}}END{if(!c)print dev " is not a multipath device!!\n"}' RS= mpath_results
}

getmpths() {
dev=$(echo "$1"|sed 's/mpath.*=\(.*\)/\1/')
echo "$dev"|awk -F',' 'BEGIN{OFS=" "}{for(i=1;i<=NF;i++)print $i >> "newmpths" }'
}

check_mpths() {
if [ ! -s "newmpths" ] ; then
echo "mpaths file cannot be found !! "
exit
fi
mpthsc=$(awk 'END{print NR}' newmpths)
while read mpathx ; do
grep $mpathx mpaths &>/dev/null
[[ $? -ne 0 ]] && ((c++))
done < newmpths
if [[ $c = $mpthsc ]] ; then
echo "Mpath names cannot be found !! "
exit 2
fi
}

printter() {
echo;
awkman 82;
echo "$1 DEVICES"
awkman 82;
}

check_results_date() {
if [ ! -f mpath_results_last_created ] ; then
awkman 82
echo "last script process time info cannot be found!!"
results;
echo
awkman 82;
fi
}


results_sds() {
for sddevs in $(awk '{a[$1]}END{for(i in a)print i}' oksds)
do
sddev $sddevs
done
}

results_mpths() {
for mpthdv in $(cat newmpths)
do
mpthdev $mpthdv
done
}


check_params() {
# working directory -> /tmp
cd /tmp ; [[ ! $? -eq 0 ]] && "/tmp directory access problem" && exit 1


echo "$1"|grep "nohelp" 2>&1 >/dev/null
if [ ! $? -eq 0 ] ; then
#helpman;nohelp="1"
unset arr[${#arr[@]}-1];
fi

echo "$1"|grep "yes" 2>&1 >/dev/null
if [ $? -ne 0 ] ; then
check_results_date
fi


###params
arr=( $2 )
arrtwo=( $2 )
###


if [ ${#arr[@]} -gt 1 ] ; then
case "$1" in
yes) y=1;unset arr[${#arr[@]}-1];
if [ "$nohelp" = "1" ] ; then
echoes "$(cat mpath_results_last_created)"
else
results; echoes "$(cat mpath_results_last_created)"
fi
;;
no) n=1;unset arr[${#arr[@]}-1]
echoes "$(cat mpath_results_last_created)"
;;
*) check_dates
;;
esac


###param checks
echo "${arr[@]}" | grep "dev=" 2>&1 >/dev/null
if [ $? -eq 0 ] ; then
devc="1"
>newsds;>oksds;>newmpths;
fi

echo "${arr[@]}" | grep "mpath" 2>&1 >/dev/null
if [ $? -eq 0 ] ; then
pathc="1"
>checkpaths;
fi

if [ "$devc" = "1" ] || [ "$pathc" = "1" ] ; then
for params in ${arr[@]}
do
case "$params" in
dev=*) newsds="1";exitsds="0";getdevs $params
;;
mpath*) newpath="1";exitpaths="0";echo $params >>checkpaths
;;
esac
done
fi

###sds
if [ "$newsds" = "1" ] ; then
check_sds;
isnew_sds;
if [ "$exitsds" = "0" ] ; then
printter "STORAGE DRIVER";
fi
results_sds
fi

###mpaths
if [ "$newpath" = "1" ] ; then
awk '{a[$1]}END{for(i in a)print i}' checkpaths > paths
check_mpaths;
isnew_paths;
if [ "$exitpaths" = "0" ] ; then
printter MULTIPATH;
indirect_results $(cat newpaths)
fi
results_mpths
fi

fi



###
if [ ${#arrtwo[@]} -eq 1 ] ; then
check_dates;
case $1 in
y|ye|yes)
results;printter MULTIPATH;
direct_results
;;
n|no)
printter MULTIPATH;
direct_results
;;
dev=*)
>newsds;>oksds
getdevs $1
check_sds;
exitsds="0";
isnew_sds;
if [ "$exitsds" = "0" ] ; then
printter "STORAGE DRIVER";
results_sds
else
exit 1
fi
;;
mpath=*)
>newmpths;
getmpths $1
check_mpths
results_mpths
;;
mpath*)
echo $1 > checkpaths;
awk '{a[$1]}END{for(i in a)print i}' checkpaths > paths
check_mpaths;
exitpaths="0";
isnew_paths;
if [ "$exitpaths" = "0" ] ; then
printter MULTIPATH;
indirect_results $1
else
exit 1
fi
;;
*) echo "parameters are undefined!!"
exit 1
;;
esac

else
if [ ${#arrtwo[@]} -eq 0 ] ; then
printter MULTIPATH;
check_dates
direct_results;
fi
fi
awk 'BEGIN{printf "%s","\b\b\n"}'
}

params="$@"
oldpwd=$PWD
check_params ${@: -1} "$params"
