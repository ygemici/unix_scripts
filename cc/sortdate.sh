cd /nfs/nfsdata/prod

for x in `find . -maxdepth 1  -name '*webm'`
do
DD=`date -r $x "+%Y/%m/%d"`
mkdir -p $DD
mv $x $DD
echo $DD
done
