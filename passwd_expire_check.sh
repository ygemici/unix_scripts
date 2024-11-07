#!/bin/bash
## @ygemici unix.com simple password expire check script
## e.g -> "./passwd_expire_check.sh 'user' mailaddress" 'IFEXPDAYS[optional]'
## IFEXPDAYS if you specify interval day(s) for send to mail
## for ex -> IFEXPDAYS=100 means compare expire days if is it [1-100] then it sends e-mail

## exs
## ./passwd_expire_check.sh user root@localhost
## ./passwd_expire_check.sh user root@localhost 60
## ./passwd_expire_check.sh user 60


user_check() {
id $1 &>/dev/null
if [ ! $? -eq 0 ]; then
echo "There is no user named with '$1' "
exit 1
fi
}
user_check $1


expire_check() {
expirestatus=$(chage -l $1|awk -F'[: ]' '/Password expires/{print $4}')
[[ "$expirestatus" == "never" ]] && echo -e "Password expire status is NEVER for '$1' user.\nNo need to send an email !!" && exit
}
expire_check $1


doit() {
expiretime=$(date '+%s' -d $(chage -l "$1"|\
awk -F: '/Password expires/{print $2}'|\
awk 'BEGIN{ORS="=";;m="Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"};
{sub(",","",$2);split(m,a);for(i=1;i<=12;i++)if(a[i]==$1)printf "%02s/%s/%s",i,$2,$3}'))
expl=$(awk -vnow=$(date '+%s') -vexpt=$expiretime 'BEGIN{print int((expt-now)/60/60/24)}')

if [ ! -z "$2" ] ; then
if [[ ! $(echo "$2"|grep -o '.*@.*\..*') ]] ; then
echo "Please give a valid e-mail address for report !!"
echo -e "Local mail account is used this time -> '$USER@$(hostname)' \n"
mailaddr="$USER@$(hostname)"
expiredays=$2
else
mailaddr="$2"
[ ! -z "$3" ] && expiredays="$3"
fi
fi

if [[ $(echo "$expl"|grep '-') ]]; then
message="Password Expired for $1 user for '$expl' day(s)"
echo -e "$message.\nAn e-mail sent to '$2' for this information."
echo "Password expires in '$expl' days for user '$1' "|mail -s "Password Expired" "$mailaddr"
exit
fi

awk -v e=$expl -v i="$expiredays" 'BEGIN{if(e<i&&e>1){
print "Password expires in '$expl' days for user '$1'";
print "An e-mail (Password Expiration WARNING!!) sent to ( '$mailaddr' )..";
system("echo \"Please change your password within the next in '$expl' days\" |mail -s \"Password Expire Notification\" '$mailaddr'")}
else print "Password expires in '$expl' days for user '$1'"}'
}
doit $1 "$2" "$3"
