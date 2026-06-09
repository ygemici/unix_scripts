#!/bin/bash

paramcheck() {
if [ -z "$1" ]; then
echo "VLAN bilgisi girilmeli -> or : 10.40.67.x "
else
vlan=$(echo $1|sed 's/^\([^ ]*\.[^ ]*\.[^ ]*\)\.[^ ]*$/\1/')
for n in {1..255}
do
host=${vlan}.$n
ping -c1 -w1 $host|grep "packet loss"|awk -F',' -v h="$host" '{split($3,a," ");sub("%","",a[1]);if(a[1]==0)print h " => Ping erisimi var"}' || break
done
fi
}

paramcheck $1
