#!/bin/bash

# Kok (root) yetkisi kontrolu
if [ "$EUID" -ne 0 ]; then
  echo "Lutfen bu betigi root (sudo) yetkisi ile calistirin."
  exit 1
fi

# 1. Parametre: Surec Sayisi kontrolu (Bos veya gecersizse default: 10)
PROCESS_COUNT=$1
if [ -z "$PROCESS_COUNT" ] || ! [[ "$PROCESS_COUNT" =~ ^[0-9]+$ ]]; then
  PROCESS_COUNT=10
fi

# 2. Parametre: Izleme Suresi kontrolu (Bos veya gecersizse default: 5 saniye)
DURATION=$2
if [ -z "$DURATION" ] || ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
  DURATION=5
fi

echo "========================================================================="
echo "En Fazla I/O Yapan Ilk $PROCESS_COUNT Surec/Thread ve Diskleri Tespit Ediliyor..."
echo "Disk trafigi $DURATION saniye boyunca izlenip SANIYELIK ORTALAMA HIZ hesaplaniyor..."
echo "========================================================================="
echo ""

TMP_FILE=$(mktemp)

# Dinamik sureye gore (-n $DURATION) izleme yapiliyor
iotop -b -d 1 -n "$DURATION" -o > "$TMP_FILE"

# Verileri toplayip toplam izleme süresine (DURATION) bolerek saniyelik hizi buluyoruz
TOP_PROCESSES=$(awk -v limit="$PROCESS_COUNT" -v dur="$DURATION" '
    NR > 3 {
        gsub(/b\x27/, "");
        gsub(/\x27/, "");

        pid = $1;
        read_val = $4;
        read_unit = $5;
        write_val = $6;
        write_unit = $7;

        cmd = "";
        for(i=10; i<=NF; i++) cmd = cmd " " $i;

        if (read_unit == "M/s") read_val = read_val * 1024;
        if (read_unit == "B/s") read_val = read_val / 1024;

        if (write_unit == "M/s") write_val = write_val * 1024;
        if (write_unit == "B/s") write_val = write_val / 1024;

        total_io = read_val + write_val;

        if (pid ~ /^[0-9]+$/ && total_io > 0) {
            io_total[pid] += total_io;
            cmd_map[pid] = cmd;
        }
    }
    END {
        for (pid in io_total) {
            # Izlenen saniyeye bolerek gercek saniyelik ORTALAMA hizi hesapla
            avg_io = io_total[pid] / dur;
            printf "%s|%.2f|%s\n", pid, avg_io, cmd_map[pid];
        }
    }
' "$TMP_FILE" | sort -t'|' -k2 -nr | head -n "$PROCESS_COUNT")

rm -f "$TMP_FILE"

if [ -z "$TOP_PROCESSES" ]; then
    echo "Belirtilen sure icinde aktif veya kayda deger I/O yapan bir surec bulunamadi."
    exit 0
fi

printf "%-10s %-15s %-35s %-30s\n" "PID/TID" "AVG I/O SPEED" "KOMUT" "KULLANILAN DISKLER / DOSYA SISTEMLERI"
echo "------------------------------------------------------------------------------------------------------------------------"

echo "$TOP_PROCESSES" | while IFS='|' read -r pid total_io cmd; do

    # 1. YONTEM: Dogrudan blok cihazi kontrolu
    disks=$(lsof -p "$pid" 2>/dev/null | awk '$9 ~ /^\/dev\/(sd|nvme|mapper|md)/ {print $9}' | sort -u | tr '\n' ',' | sed 's/,$//')

    # 2. YONTEM: df ile veri dizini kontrolu
    if [ -z "$disks" ]; then
        ppid=$(ps -o ppid= -p "$pid" | xargs)

        sample_file=$(lsof -p "$pid" ${ppid:+-p $ppid} 2>/dev/null | awk '
            $9 ~ /^\// && $9 !~ /^\/dev\/(null|shm|pts|zero)/ && $9 !~ /pipe/ && $9 !~ /socket/ {
                print $9;
                exit
            }
        ')

        if [ -z "$sample_file" ]; then
            sample_file=$(ls -l /proc/"$pid"/cwd 2>/dev/null | awk '{print $NF}')
            [ -z "$sample_file" ] && [ ! -z "$ppid" ] && sample_file=$(ls -l /proc/"$ppid"/cwd 2>/dev/null | awk '{print $NF}')
        fi

        if [ ! -z "$sample_file" ] && [ -e "$sample_file" ]; then
            disks=$(df -P "$sample_file" | awk 'NR==2 {print $1}')
        else
            disks="Tespit edilemedi"
        fi
    fi

    short_cmd=$(echo "$cmd" | xargs | cut -c1-33)

    if (( $(echo "$total_io > 1024" | bc -l) )); then
        friendly_io=$(echo "$total_io / 1024" | bc -l | awk '{printf "%.2f M/s", $1}')
    else
        friendly_io=$(printf "%.2f K/s" "$total_io")
    fi

    printf "%-10s %-15s %-35s %-30s\n" "$pid" "$friendly_io" "$short_cmd" "$disks"
done

echo "========================================================================="
