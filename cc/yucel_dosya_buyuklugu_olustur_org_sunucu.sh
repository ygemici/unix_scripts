#!/bin/bash

find Original/ -type f -newermt 2024-06-01 ! -newermt 2024-07-01 |awk -F'/' '{print $NF}' >Haziran_2024_dosya_listesi_Original
while read file;do du -s -B1 --apparent-size Original/$file |awk '{sub("Original/","",$NF);print $1,$NF}' >>Haziran_2024_dosya_buyuklugu_Original ; done <Haziran_2024_dosya_listesi_Original

scp Haziran_2024_dosya_buyuklugu_Original Haziran_2024_dosya_buyuklugu_Original ansible@SVPRDCC01:~

## awk 'NR==FNR{a[$0];next}!($0 in a)' Haziran_2024_dosya_buyuklugu_Original Haziran_2024_dosya_buyuklugu_Yedek
