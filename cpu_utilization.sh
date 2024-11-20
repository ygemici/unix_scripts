#!/bin/bash
### unix.com ygemici cpu top
### inspired from https://stackoverflow.com/questions/23367857/accurate-calculation-of-cpu-usage-given-in-percentage-in-linux

###exs
#[root@openshift4 ~]# bash cputop.sh 0.2 4
#   total %  3.00 - %  1.00(us) - %  2.00(sys) - %  0.00(ni) - %  0.00(wa) - %  0.00(hi) - %  0.00(si)
#    cpu0 %  5.00 - %  2.00(us) - %  3.00(sys) - %  0.00(ni) - %  0.00(wa) - %  0.00(hi) - %  0.00(si)
#--loop 1 OK--

#   total %  3.00 - %  1.00(us) - %  2.00(sys) - %  0.00(ni) - %  0.00(wa) - %  0.00(hi) - %  0.00(si)
#    cpu0 %  4.00 - %  1.00(us) - %  3.00(sys) - %  0.00(ni) - %  0.00(wa) - %  0.00(hi) - %  0.00(si)
#--loop 2 OK--

#   total %  5.00 - %  2.00(us) - %  3.00(sys) - %  0.00(ni) - %  0.00(wa) - %  0.00(hi) - %  0.00(si)
#    cpu0 %  4.00 - %  1.00(us) - %  3.00(sys) - %  0.00(ni) - %  0.00(wa) - %  0.00(hi) - %  0.00(si)
#--loop 3 OK--

#   total %  6.00 - %  2.00(us) - %  4.00(sys) - %  0.00(ni) - %  0.00(wa) - %  0.00(hi) - %  0.00(si)
#    cpu0 %  4.00 - %  1.00(us) - %  3.00(sys) - %  0.00(ni) - %  0.00(wa) - %  0.00(hi) - %  0.00(si)
#--loop 4 OK--



[ -z "$1" ] && sleepDurationSeconds=1 || sleepDurationSeconds=$1
[ -z "$2" ] && iteration=1 || iteration=$2
cc=1

while [ $iteration -ge 1 ] ; do

cpus=$(grep cpu /proc/stat|awk '{print $1}')
cpuc=$(grep 'cpu[0-9]\+' /proc/stat|awk 'END{print NR}')
for cpu in $cpus ; do

previousDate=$(date +%s%N | cut -b1-13)
previousStats=$(cat /proc/stat)
    previousLine=$(echo "$previousStats" | grep "$cpu ")
    prevuser=$(echo "$previousLine" | awk '{print $2}')
    prevnice=$(echo "$previousLine" | awk '{print $3}')
    prevsystem=$(echo "$previousLine" | awk '{print $4}')
    previdle=$(echo "$previousLine" | awk '{print $5}')
    previowait=$(echo "$previousLine" | awk '{print $6}')
    previrq=$(echo "$previousLine" | awk '{print $7}')
    prevsoftirq=$(echo "$previousLine" | awk '{print $8}')
    prevsteal=$(echo "$previousLine" | awk '{print $9}')
    prevguest=$(echo "$previousLine" | awk '{print $10}')
    prevguest_nice=$(echo "$previousLine" | awk '{print $11}')

    PrevIdle=$(awk -v a=$previdle -v b=$previowait 'BEGIN{printf "%0.2f\n" , a+b}')
    PrevNonIdle=$(awk -v a=$prevuser -v b=$prevnice -v c=$prevsystem -v d=$previrq -v e=$prevsoftirq -v f=$prevsteal 'BEGIN{printf "%0.2f\n" , a+b+c+d+e+f}')
    PrevTotal=$(awk -v a=$PrevIdle -v b=$PrevNonIdle 'BEGIN{printf "%0.2f\n" , a+b}')


#####interval
sleep $sleepDurationSeconds

currentDate=$(date +%s%N | cut -b1-13)
currentStats=$(cat /proc/stat)
    currentLine=$(echo "$currentStats" | grep "$cpu ")
    user=$(echo "$currentLine" | awk '{print $2}')
    nice=$(echo "$currentLine" | awk '{print $3}')
    system=$(echo "$currentLine" | awk '{print $4}')
    idle=$(echo "$currentLine" | awk '{print $5}')
    iowait=$(echo "$currentLine" | awk '{print $6}')
    irq=$(echo "$currentLine" | awk '{print $7}')
    softirq=$(echo "$currentLine" | awk '{print $8}')
    steal=$(echo "$currentLine" | awk '{print $9}')
    guest=$(echo "$currentLine" | awk '{print $10}')
    guest_nice=$(echo "$currentLine" | awk '{print $11}')

    Idle=$(awk -v a=$idle -v b=$iowait 'BEGIN{printf "%0.2f\n" , a+b}')
    NonIdle=$(awk -v a=$user -v b=$nice -v c=$system -v d=$irq -v e=$softirq -v f=$steal 'BEGIN{printf "%0.2f\n" , a+b+c+d+e+f}')
    Total=$(awk -v a=$Idle -v b=$NonIdle 'BEGIN{printf "%0.2f\n" , a+b}')


#######results

    totald=$(awk -v cpucnt=$cpuc -v a=$Total -v b=$PrevTotal 'BEGIN{printf "%0.2f\n" , (a-b)}')
    idled=$(awk -v cpucnt=$cpuc -v a=$Idle -v b=$PrevIdle 'BEGIN{printf "%0.2f\n" , (a-b)}')

    userd=$(awk -v a=$user -v b=$prevuser 'BEGIN{printf "%0.2f\n" , a-b}')
    niced=$(awk -v a=$nice -v b=$prevnice 'BEGIN{printf "%0.2f\n" , a-b}')
    sysd=$(awk -v a=$system -v b=$prevsystem 'BEGIN{printf "%0.2f\n" , a-b}')
    idled=$(awk -v a=$idle -v b=$previdle 'BEGIN{printf "%0.2f\n" , a-b}')
    iowaitd=$(awk -v a=$iowait -v b=$previowait 'BEGIN{printf "%0.2f\n" , a-b}')
    irqd=$(awk -v a=$irq -v b=$previrq 'BEGIN{printf "%0.2f\n" , a-b}')
    softirqd=$(awk -v a=$softirq -v b=$prevsoftirq 'BEGIN{printf "%0.2f\n" , a-b}')
    steald=$(awk -v a=$steal -v b=$prevsteal 'BEGIN{printf "%0.2f\n" , a-b}')

    #CPU_Percentage=$(awk -v cpucnt=$cpuc -v a=$totald -v b=$idled -v c=$prevcpux 'BEGIN {if((a==0)&&(b==0))printf "%0.2f\n" , c ;else {if(a==0)a=0.01; printf "%0.2f\n" , (a-b)/a*100}}')
    CPU_Percentage=$(awk -v cpucnt=$cpuc -v a=$totald -v b=$idled -v c=$prevcpux 'BEGIN {if((a==0)&&(b==0))printf "%0.2f\n" , c ;else {if(a==0)a=0.01; printf "%0.2f\n" , (a-b)/100}}')

    #echo $CPU_Percentage xx $totald

    if [[ "$cpu" == "cpu" ]]; then
    cpux=total
    awk -v cpucnt=$cpuc -v cpu="$cpux" -v a=$CPU_Percentage -v b=$userd -v c=$sysd -v d=$niced -v e=$iowaitd -v f=$irqd -v g=$softirqd -v h=$steald 'BEGIN{printf "%8s%s%6.2f %s%6.2f%-4s %s%6.2f%-4s %s%6.2f%-4s %s%6.2f%-4s %s%6.2f%-4s %s%6.2f%-4s\n", cpu," %",(a*100/cpucnt) , "- %",b/cpucnt,"(us)", "- %",c/cpucnt,"(sys)", "- %",d/cpucnt,"(ni)", "- %",e/cpucnt,"(wa)", "- %",f/cpucnt,"(hi)", "- %",g/cpucnt,"(si)", "- %",h/cpucnt,"(st)" }'
    else
    cpux=$cpu
    awk -v cpu="$cpux" -v a=$CPU_Percentage -v b=$userd -v c=$sysd -v d=$niced -v e=$iowaitd -v f=$irqd -v g=$softirqd -v h=$steald 'BEGIN{printf "%8s%s%6.2f %s%6.2f%-4s %s%6.2f%-4s %s%6.2f%-4s %s%6.2f%-4s %s%6.2f%-4s %s%6.2f%-4s\n", cpu," %",(a*100) , "- %",b,"(us)", "- %",c,"(sys)", "- %",d,"(ni)", "- %",e,"(wa)", "- %",f,"(hi)", "- %",g,"(si)", "- %",h,"(st)" }'
fi


prevcpux=$CPU_Percentage
done
echo --loop $((cc)) OK--
echo
((iteration--))
((cc++))
done

