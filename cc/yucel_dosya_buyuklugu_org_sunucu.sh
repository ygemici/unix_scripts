while read file;do du -s -B1 --apparent-size Original/$file |awk '{sub("Original/","",$NF);print $1,$NF}' >>2025_6_AY_dosya_size_listesi_Orginal ; done <2025_6_AY_dosya_listesi_Orginal
