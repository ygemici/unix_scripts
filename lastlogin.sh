#!/bin/bash
## @ygemici unix.com last logins check script

# # # # # # # # # # # # # # # # #
# ./loginusers.sh notlogins 90  #
# ./loginusers.sh logins 90     #
# ./loginusers.sh username 90   #
# ./loginusers.sh 90            #
# # # # # # # # # # # # # # # # #

###exs
#[root@openshift4 ~]# bash lastlogin.sh admin 100

#             admin
#=======================================================
#Last Login Date -> Sun Oct  6 08:33:01 PM +03 2024
#Elapsed Times (Days): 44.7937
#Elapsed Times (Hours): 1075.05
#Elapsed Time (Minutes): 64503
#Elapsed Times (Seconds): 3870180
#=======================================================

#[root@openshift4 ~]# bash lastlogin.sh root 10

#                root
#=======================================================
#Last Login Date -> Wed Nov 20 03:10:01 PM +03 2024
#Elapsed Times (Days): 0.0181019
#Elapsed Times (Hours): 0.434444
#Elapsed Time (Minutes): 26.0667
#Elapsed Times (Seconds): 1564
#=======================================================


writeerror() {
echo "Last Login information for '$1' could [not found] for $day days"
}

writelogin() {
nowepochtime=$(date +%s)
diff=$((nowepochtime-lastlgepochtime))
awk -vuser=$user 'BEGIN{printf "\n%20s\n",user}' ; awk 'BEGIN{$55=OFS="=";printf "%s\n",$0}'
awk -vdatex="$(date -d @${lastlgepochtime})" 'BEGIN{printf "%s%30s\n","Last Login Date -> ", datex}'
awk -vdiff=$diff 'BEGIN{printf "%20s%s\n%20s%s\n%20s%s\n%20s%s\n","Elapsed Times (Days): ",diff/60/60/24,"Elapsed Times (Hours): ",diff/60/60,"Elapsed Time (Minutes): ",diff/60,"Elapsed Times (Seconds): ",diff}'
awk 'BEGIN{$55=OFS="=";print $0"\n"}'
}

calloldwtmp() {
lastlogf=$(ls -lt /var/log/wtmp*|awk 'END{print $NF}')
lasttyear=$(last -f $lastlogf|awk 'END{print $NF}')
}

calllastlogin() {
#lmonth=$(awk -vmonth=$lastmonthstart 'BEGIN{split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec",month," ");for(i=1;i<=12;i++)if(month[i]~month)print i}'
calloldwtmp


if [[ "$lasttyear" != "$validyear" ]] ; then

for((i=$lasttyear;i<=$validyear;i++)) ; do
lastlogl=$(last -t ${i}1231235959 -1 $user -f /var/log/wtmp*|awk 'NR==1')
j=$((i+1)) ; lastlogf=$(last -t ${j}1231235959 -1 $user -f /var/log/wtmp*|awk 'NR==1')
[[ "$lastlogl" == "$lastlogf" ]] && validyearnew=$i
done
else
validyearnew=$validyear
fi


lastlogin=$(last -1 $user -f /var/log/wtmp*|awk -vy=$validyearnew 'NR==1&&NF{if(/pts/)print $5,$6,",",y,$7":01";if(/tty/)print $4,$5,",",y,$6":01"}')
if [ -z "$lastlogin" ] ; then
 if [ "$1" = "notlogins" ] || [ "$1" = "$user" ] || [ -z "$1" ] ; then
 writeerror $user
 fi
else

 lastlgepochtime=$(date +%s -d"$lastlogin")
 wantedepochtime=$(date +%s -d"-$day days")

 if [ $lastlgepochtime -lt $wantedepochtime ] ; then
 echo "Last Login time is long from period ['$day'] of days ago for [$user] user"
 else
 if [ "$1" = "logins" ] || [ "$1" = "$user" ] || [ -z "$1" ] ; then
 writelogin $user
 fi
 fi
fi
}

calllastloginall() {
awk -F':' '$NF!~/nologin/{print $1}' $passwd | while read -r user ; do
if [ -z "$1" ] ; then
calllastlogin
else
calllastlogin $1
fi
done
}

callfunc() {
case $1 in
 notlogins) calllastloginall notlogins ;;
 logins)  calllastloginall logins ;;
 *) user=$1 ; calllastlogin $user ;;
esac
}

checkuser() {
if [ "$1" != "notlogins" ] && [ "$1" != "logins" ] ; then
grep -q $1 $passwd
if [ $? -ne 0 ] ; then
id $1 &>/dev/null
if [ $? -ne 0 ] ; then
echo "Username is seem invalid !!"
exit
fi
fi
else
awk -vn=$1 'BEGIN{printf "%30s\n",n}'
echo|awk 'BEGIN{printf "%15c","-";for(i=1;i<=25;i++)printf "%c","-"}END{printf "%s","\n"}'
fi
}

calldates() {
daysago=$(date -d "-$day days" +'%Y%m%d%H%M%S')
#validyear=$(date -d "-$day days" +'%Y')
validyear=$(date '+%Y')
}

numcheckandset() {
numcheck=$(echo|awk -va=$1 '{print a+=0}')
if [ $numcheck -eq 0 ] ; then echo "where is the period of day ? " ; exit 1 ; fi
passwd='/etc/passwd'
calldates
}

case $# in
 2) day=$2 ; numcheckandset $day ; checkuser $1 ; callfunc $1 ;;
 1) day=$1 ; numcheckandset $day ; calllastloginall ;;
 *) exit 1 ;;
esac

