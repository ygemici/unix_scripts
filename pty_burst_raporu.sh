#!/usr/bin/env bash
# =============================================================================
# pty_burst_raporu.sh - utempter ile açılan kısa pty oturumlarının (burst) kaynağını bulur
#
# Kullanım:
#   sudo ./pty_burst_raporu.sh                 # audit'teki EN SON burst'ü çözümler
#   sudo ./pty_burst_raporu.sh 673214          # belirli bir sahip PID'yi çözümler
#   sudo ./pty_burst_raporu.sh --bekle         # yeni burst gelene kadar bekler, sonra rapor yazar
#   TAM=1 sudo -E ./pty_burst_raporu.sh        # kısaltma yapmadan tüm kayıtları da yazar
#
# Arka planda bırakmak için (burst ne zaman gelirse rapor dosyaya yazılır):
#   nohup ./pty_burst_raporu.sh --bekle > /root/burst_raporu.txt 2>&1 &
#
# Önkoşul: kurallar burst'ten ÖNCE yüklü olmalı (eksikse eklenecek komutları yazar):
#   auditctl -w /usr/libexec/utempter/utempter -p x -k pty_watch
#   auditctl -a always,exit -F arch=b64 -S execve -F uid=0 -F auid=-1 -k noauid_exec
# =============================================================================

ARG="${1:-}"
SESSIZLIK="${SESSIZLIK:-20}"     # --bekle: son utempter olayından bu kadar saniye sonra burst bitmiş sayılır
ARALIK_BOSLUK=30                 # iki oturum arası bu süreden kısaysa aynı burst'tür (sn)

[ "$(id -u)" -eq 0 ] || { echo "Root olarak çalıştırın (audit kayıtları için)." >&2; exit 1; }
command -v ausearch >/dev/null 2>&1 || { echo "ausearch bulunamadı." >&2; exit 1; }

ep()  { date -d "$1" +%s; }                          # "MM/DD/YYYY HH:MM:SS" -> epoch
fmt() { date -d "@$1" "+%m/%d/%Y %H:%M:%S"; }        # epoch -> ausearch -ts biçimi

# ausearch -i çıktısını "tarih ppid pid exe | komut satırı" biçimine çevirir
parse() {
    awk '
    /^type=PROCTITLE/ { t = $0; sub(/.*proctitle=/, "", t); next }
    /^type=SYSCALL/ {
        match($0, /audit\([0-9\/]+ [0-9:]+/); ts = substr($0, RSTART + 6, RLENGTH - 6)
        match($0, / ppid=[0-9]+/);           pp = substr($0, RSTART + 6, RLENGTH - 6)
        match($0, / pid=[0-9]+/);            p  = substr($0, RSTART + 5, RLENGTH - 5)
        match($0, / exe=[^ ]+/);             ex = substr($0, RSTART + 5, RLENGTH - 5)
        printf "%s  ppid=%-7s pid=%-7s %-34s | %s\n", ts, pp, p, ex, t
        t = ""
    }'
}

# parse çıktısından, verilen sahip PID'lerin torunları dahil tüm alt süreçlerini seçer
# $1: sahip PID'ler (boşlukla ayrılmış)
desc() {
    awk -v own="$1" '
    BEGIN { n = split(own, a, " "); for (i = 1; i <= n; i++) S[a[i]] = 1 }
    { L[NR] = $0
      match($0, / ppid=[0-9]+/); PP[NR] = substr($0, RSTART + 6, RLENGTH - 6)
      match($0, / pid=[0-9]+/);  PD[NR] = substr($0, RSTART + 5, RLENGTH - 5) }
    END {
        do { ch = 0
            for (i = 1; i <= NR; i++) if ((PP[i] in S) && !(PD[i] in S)) { S[PD[i]] = 1; ch = 1 }
        } while (ch)
        for (i = 1; i <= NR; i++) if ((PP[i] in S) && !seen[L[i]]++) print L[i]
    }'
}

# utempter exec kayıtları: "MM/DD/YYYY HH:MM:SS|ppid|pid" (zaman sırasına göre)
# $1: ausearch zaman seçeneği (varsayılan: "-ts today")
utempter_olaylari() {
    ausearch -i -k pty_watch ${1:--ts today} 2>/dev/null | grep "type=SYSCALL" \
      | grep "exe=/usr/libexec/utempter/utempter" \
      | sed -E 's#^type=SYSCALL msg=audit\(([0-9/]+ [0-9:]+)\.[0-9]+:[0-9]+\).* ppid=([0-9]+) pid=([0-9]+).*#\1|\2|\3#'
}

son_utempter_epoch() {
    local t
    t=$(utempter_olaylari "-ts recent" | tail -1 | cut -d'|' -f1)
    [ -n "$t" ] && ep "$t"
}

# --- 1) Kurallar yüklü mü? ---------------------------------------------------
RULES=$(auditctl -l 2>/dev/null)
EKSIK=0
echo "$RULES" | grep -q "pty_watch" || { echo "Eksik kural: auditctl -w /usr/libexec/utempter/utempter -p x -k pty_watch"; EKSIK=1; }
echo "$RULES" | grep -q "noauid_exec" || { echo "Eksik kural: auditctl -a always,exit -F arch=b64 -S execve -F uid=0 -F auid=-1 -k noauid_exec"; EKSIK=1; }
[ "$EKSIK" -eq 1 ] && { echo "Kuralları ekleyin, sonraki burst'ten sonra tekrar çalıştırın."; exit 1; }

# --- 2) --bekle: yeni burst gelene kadar bekle -------------------------------
BASLA=0
if [ "$ARG" = "--bekle" ]; then
    BASLA=$(date +%s)
    echo "$(date '+%F %T') pty burst'ü bekleniyor (Ctrl-C ile çıkılır)..."
    while true; do
        SON=$(son_utempter_epoch)
        if [ -n "$SON" ] && [ "$SON" -gt "$BASLA" ]; then
            while [ $(( $(date +%s) - $(son_utempter_epoch) )) -lt "$SESSIZLIK" ]; do sleep 3; done
            break
        fi
        sleep 10
    done
    echo "$(date '+%F %T') burst yakalandı, rapor hazırlanıyor."
fi

# --- 3) Burst aralığını ve sahip PID'leri belirle ----------------------------
UT=$(utempter_olaylari)
[ -z "$UT" ] && { echo "Bugün için utempter kaydı yok."; exit 1; }

EP=()   # "epoch|ppid"
while IFS='|' read -r t pp pid; do EP+=("$(ep "$t")|$pp"); done <<< "$UT"
N=${#EP[@]}

if [ -n "$ARG" ] && [ "$ARG" != "--bekle" ]; then
    # belirli sahip PID
    START=""; END=""
    for x in "${EP[@]}"; do
        [ "${x#*|}" = "$ARG" ] || continue
        e=${x%%|*}; [ -z "$START" ] && START=$e; END=$e
    done
    [ -z "$START" ] && { echo "PID $ARG için utempter kaydı bulunamadı."; exit 1; }
elif [ "$BASLA" -gt 0 ]; then
    START=""; END=""
    for x in "${EP[@]}"; do
        e=${x%%|*}; [ "$e" -gt "$BASLA" ] || continue
        [ -z "$START" ] && START=$e; END=$e
    done
    [ -z "$START" ] && { echo "Beklenen burst kaydı okunamadı."; exit 1; }
else
    # en son burst: sondan başa, oturumlar arası boşluk <= ARALIK_BOSLUK olduğu sürece
    END=${EP[$((N-1))]%%|*}; START=$END
    for ((i=N-1; i>=0; i--)); do
        e=${EP[$i]%%|*}
        if [ $((START - e)) -le "$ARALIK_BOSLUK" ]; then START=$e; else break; fi
    done
fi

OWNERS=()
for x in "${EP[@]}"; do
    e=${x%%|*}; pp=${x#*|}
    [ "$e" -ge "$START" ] && [ "$e" -le "$END" ] && OWNERS+=("$pp")
done
mapfile -t OWNERS < <(printf '%s\n' "${OWNERS[@]}" | awk '!s[$0]++')

echo
echo "=============================================="
echo " Burst özeti"
echo "=============================================="
echo "Aralık : $(fmt "$START") - $(fmt "$END")  ($((END - START)) sn)"
echo "Oturum : ${#OWNERS[@]} adet; sahip PID'ler: ${OWNERS[*]}"

# --- 4) Kural, burst'ten önce mi yüklendi? -----------------------------------
RT=$(ausearch -i -m CONFIG_CHANGE -ts today 2>/dev/null | grep "op=add_rule" | grep "key=noauid_exec" \
     | grep "res=yes" | grep -oE "audit\([0-9/]+ [0-9:]+" | head -1 | sed 's/^audit(//')
if [ -n "$RT" ] && [ "$START" -lt "$(ep "$RT")" ]; then
    echo
    echo "UYARI: Bu burst ($(fmt "$START")), noauid_exec kuralının yüklendiği andan ($RT) ÖNCEYDİ."
    echo "       Exec kaydı tutulmadı; sonraki burst'ü bekleyin:  $0 --bekle"
    exit 2
fi

# --- 5) Aralıktaki tüm root / login oturumu olmayan exec'ler ------------------
S=$(fmt $((START - 3))); E=$(fmt $((END + 3)))
OUT=$(ausearch -i -k noauid_exec -ts $S -te $E 2>/dev/null)
PARSED=""; [ -n "$OUT" ] && PARSED=$(echo "$OUT" | parse)

echo
echo "=============================================="
echo " Sahip süreçlerin altında (pty içinde) çalışan komutlar"
echo "=============================================="
if [ -z "$PARSED" ]; then
    echo "  (exec kaydı yok)"
else
    ALT=$(echo "$PARSED" | desc "${OWNERS[*]}")
    if [ -z "$ALT" ]; then
        echo "  (sahip süreçlerin çocuğu olarak kayıtlı komut yok)"
    else
        echo "$ALT" | head -n 60
        [ "$(echo "$ALT" | wc -l)" -gt 60 ] && echo "  ... ilk 60 gösterildi (hepsi için: TAM=1)"
    fi
fi

echo
echo "=============================================="
echo " Aynı aralıkta (±3 sn) root'un login oturumu olmayan TÜM exec'leri: özet"
echo "=============================================="
if [ -z "$PARSED" ]; then
    echo "  (kayıt yok)"
else
    echo "Toplam kayıt: $(echo "$PARSED" | wc -l)"
    CENT=$(echo "$PARSED" | grep -c "/centrifydc/")
    [ "$CENT" -gt 0 ] && echo "Bunların $CENT tanesi Centrify (centrifydc) bileşenlerine ait."
    echo
    echo "En çok çalışan programlar:"
    echo "$PARSED" | awk '{print $5}' | sort | uniq -c | sort -rn | head -n 8 | sed 's/^/  /'
    echo
    echo "En sık çalışan komutlar (ilk 12):"
    echo "$PARSED" | sed -E 's/^[^|]*\| //' | cut -c1-110 | sort | uniq -c | sort -rn | head -n 12 | sed 's/^/  /'
    if [ -n "${TAM:-}" ]; then
        echo; echo "--- sahip altındaki tüm komutlar (TAM=1) ---"
        echo "$PARSED" | desc "${OWNERS[*]}"
        echo; echo "--- aralıktaki tüm kayıtlar (TAM=1) ---"
        echo "$PARSED"
    fi
fi

# --- 6) İlk sahip süreçten yukarı zincir --------------------------------------
echo
echo "=============================================="
echo " Zincir (sahip PID ${OWNERS[0]} -> üst süreçler)"
echo "=============================================="
P="${OWNERS[0]}"
BULUNDU=0
for i in 1 2 3 4 5 6 7 8; do
    if [ "$P" = "1" ]; then echo "  zincir systemd'ye (PID 1) ulaştı."; break; fi
    R=$(ausearch -i -p "$P" 2>/dev/null)
    if [ -z "$R" ]; then
        if [ "$BULUNDU" -eq 0 ]; then
            echo "  Sahip PID $P için hiçbir audit kaydı yok. Olası sebepler:"
            echo "   - exec 32-bit bir süreçten yapılmış olabilir; noauid_exec kuralı yalnızca arch=b64 ise onu görmez."
            echo "     Ek kural:  auditctl -a always,exit -F arch=b32 -S execve -F uid=0 -F auid=-1 -k noauid_exec"
            echo "   - süreç bir daemon'un fork'u olabilir (exec yok). Geçici fork kuralı:"
            echo "     auditctl -a always,exit -F arch=b64 -S clone,fork,vfork -F uid=0 -F auid=-1 -k noauid_fork"
            echo "   - Ham kayıtlara da bakın:  grep -w $P /var/log/audit/audit.log*"
        else
            echo "  PID $P için exec kaydı yok (kuraldan önce başlamış, uzun ömürlü süreç)."
            echo "  Sorgula:  systemctl status $P ; ps -fp $P"
        fi
        break
    fi
    BULUNDU=1
    echo "$R" | parse | tail -n 1
    P=$(echo "$R" | grep "type=SYSCALL" | tail -n 1 | grep -oE " ppid=[0-9]+" | cut -d= -f2)
    [ -z "$P" ] && break
done
echo
