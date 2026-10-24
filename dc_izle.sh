#!/usr/bin/env bash
# =============================================================================
# dc_izle.sh - "script" süreçlerini yakalar ve üst süreç zincirini (script -> ... -> servis) kaydeder.
# Audit kuralı gerektirmez; audit logları hızlı dönse bile kayıt dosyada kalır.
#
# Başlat (arka planda):
#   nohup bash ./dc_izle.sh > /root/dc_izle.log 2>&1 &  echo $! > /root/dc_izle.pid
# Sonucu oku:
#   cat /root/dc_izle.log
# Durdur:
#   kill $(cat /root/dc_izle.pid)
# =============================================================================

declare -A SEEN
echo "$(date '+%F %T') izleme başladı (PID $$)"

while true; do
    for pid in $(pgrep -x script); do
        [ -n "${SEEN[$pid]:-}" ] && continue          # aynı süreci bir kez yaz
        SEEN[$pid]=1
        echo "$(date '+%F %T') --- script PID $pid yakalandı"
        p=$pid
        for i in 1 2 3 4 5 6 7 8; do
            line=$(ps -o pid=,ppid=,user=,args= -p "$p" 2>/dev/null)
            [ -z "$line" ] && break
            echo "    $line"
            p=$(echo "$line" | awk '{print $2}')
            { [ "$p" = "1" ] || [ "$p" = "0" ]; } && break
        done
    done
    sleep 1
done
