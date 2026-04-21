#!/bin/bash
## justdoit simple users history view script unix.com @ygemici
user=$1
for i in `find "/home/$user" -name "*history" 2>/dev/null`
do
 echo $i|sed 's|.*/\(.*\)/.*$|\1 USER "'$(echo "${i##/*/}")'" HISTORY FILE(s)|'
 echo "=========================================";sleep 1
 which strings &>/dev/null && ( strings -a $i|cat -n|more -d;echo;sleep 2 ) || ( cat -n $i|more -d;echo;sleep 2 )
done
