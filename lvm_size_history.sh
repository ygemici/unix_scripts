#!/bin/bash

## Gemini ##

ARCHIVE_DIR="/etc/lvm/archive"

if [ "$EUID" -ne 0 ]; then
  echo "Lütfen bu scripti ROOT olarak (sudo) çalıştırın."
  exit 1
fi

echo "LVM arşivleri derinlemesine analiz ediliyor, lütfen bekleyin..."
echo -e "\n========================================================================================================================"
printf "%-25s | %-20s | %-12s | %s\n" "İşlem Tarihi" "Logical Volume (Disk)" "Değişim" "Tetikleyen Komut"
echo -e "========================================================================================================================"

TMP_FILE=$(mktemp)

for file in $ARCHIVE_DIR/*.vg; do
    [ -e "$file" ] || continue

    timestamp=$(grep -m 1 "time =" "$file" | awk '{print $3}')
    [ -z "$timestamp" ] && continue
    date_str=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$timestamp" "+%Y-%m-%d %H:%M:%S")

    desc=$(grep -m 1 "description =" "$file" | sed -E 's/.*description = "(.*)"/\1/')

    # Sadece diske alan ekleyen veya disk oluşturan ana komutları işle (Ara adımları filtrele)
    [[ "$desc" == *"vgdisplay"* || "$desc" == *"pvresize"* || "$desc" == *"vgextend"* ]] && continue

    vg_name=$(basename "$file" | cut -d'_' -f1)

    # Disk adını netleştir
    lv_target="$vg_name"
    if [[ "$desc" == *"-n "* ]]; then
        lv_target=$(echo "$desc" | sed -E 's/.*-n[[:space:]]+([a-zA-Z0-9_-]+).*/\1/')
    elif [[ "$desc" == *"/dev/mapper/"* ]]; then
        lv_target=$(echo "$desc" | sed -E 's/.*\/dev\/mapper\/[a-zA-Z0-9_-]+-([a-zA-Z0-9_-]+).*/\1/')
    elif [[ "$desc" == *"/dev/"* ]]; then
        lv_target=$(echo "$desc" | sed -E 's/.*\/dev\/[a-zA-Z0-9_-]+\/([a-zA-Z0-9_-]+).*/\1/')
    fi

    # Toplam sektörü hesapla
    total_lv_sectors=0
    while IFS= read -r line; do
        if [[ "$line" =~ size[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
            sector_val="${BASH_REMATCH[1]}"
            total_lv_sectors=$((total_lv_sectors + sector_val))
        fi
    done < "$file"

    if [ $total_lv_sectors -gt 0 ]; then
        echo "$timestamp|$date_str|$lv_target|$total_lv_sectors|$desc" >> "$TMP_FILE"
    fi
done

declare -A KRONOLOJIK_BOYUTLAR

while IFS='|' read -r ts dt lv sectors desc; do
    prev_sectors=${KRONOLOJIK_BOYUTLAR[$lv]}

    if [ -z "$prev_sectors" ]; then
        gb_size=$(( sectors * 512 / 1024 / 1024 / 1024 ))
        diff_str="İlk Boyut: ${gb_size}GB"
        KRONOLOJIK_BOYUTLAR[$lv]=$sectors
    else
        if [ "$sectors" -ne "$prev_sectors" ]; then
            diff=$((sectors - prev_sectors))
            if [ $diff -gt 0 ]; then
                gb_diff=$(( diff * 512 / 1024 / 1024 / 1024 ))
                diff_str="+$gb_diff GB"
            else
                abs_diff=$((prev_sectors - sectors))
                gb_diff=$(( abs_diff * 512 / 1024 / 1024 / 1024 ))
                diff_str="-$gb_diff GB"
            fi
            KRONOLOJIK_BOYUTLAR[$lv]=$sectors
        else
            continue
        fi
    fi

    printf "%-25s | %-20s | %-12s | %s\n" "$dt" "$lv" "$diff_str" "$desc"

done < <(sort -t'|' -k1,1n "$TMP_FILE" | uniq)

rm -f "$TMP_FILE"
echo -e "========================================================================================================================"

