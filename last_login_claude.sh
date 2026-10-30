#!/usr/bin/env bash
# =============================================================================
# son_loginler.sh - Sunucu giriş (login) denetim raporu
#
# Gösterir:
#   - Şu an bağlı kullanıcılar
#   - Son başarılı girişler (wtmp) ve kullanıcı bazında son login (tarihe göre)
#   - Başarısız girişler (btmp) ve IP özetleri
#   - SSH loglarından başarılı/başarısız girişler (gerçek kaynak IP + yöntem)
#   - su / sudo: başarısız denemeler, başarılı su geçişleri, çalıştırılan sudo komutları
#   - Son reboot'lar
#
# Kullanım:
#   ./son_loginler.sh [kayıt_sayısı]            (varsayılan: 20)
#   sudo ./son_loginler.sh 50                   (tam rapor için root önerilir)
#   LOG_DOSYASI=/tmp/secure.txt ./son_loginler.sh   (kopyalanmış bir log dosyasını analiz et)
#   SUDO_LOG_DOSYASI=/tmp/sudo.log ./son_loginler.sh (sudo logunu elle belirt)
#   KOMUT_UZUNLUK=100 ./son_loginler.sh             (uzun komutları 100 karakterde kes; varsayılan: tamamı)
#   HARIC_KULLANICI=postgres,s00827 ./son_loginler.sh (SSH ve su/sudo bölümlerinde bilinen servis hesaplarını gizle;
#                                                     "özet" tabloları gizlemez, gizlenen sayı her bölümde yazılır)
#   GIZLE_YEREL_PTY=1 ./son_loginler.sh             (bölüm 2'de IP'siz kısa "yerel pty" oturumlarını gizle)
#   YEREL_PTY_ETIKET="yerel pty (ManageEngine dcservice -> script)" ./son_loginler.sh   (o oturumların kaynağını yaz)
#   /etc/son_loginler.conf                          (tüm bu ayarları kalıcı yazın; örnek dosya sonunda)
#   ROOT_SSH_IZINLI_IP=10.1.1.1,10.1.1.2 ./son_loginler.sh   (root SSH girişi bu IP'ler dışından gelirse uyar)
#   IP_ETIKET="10.66.1.2=Veeam proxy?;10.1.1.1=CyberArk CPM" ./son_loginler.sh   (IP'lerin yanına ad yaz; ayraç ';')
#   KULLANICI_IP_IZIN="s00827=10.66.1.2;postgres=10.180.50.145" ./son_loginler.sh  (bu kullanıcılar başka IP'den girerse listele)
#   MESAJ_LOG_DOSYASI=/tmp/messages ./son_loginler.sh (Centrify audit trail için messages logu)
#   ESKI_LOGLAR=1 ./son_loginler.sh                 (logrotate ile dönmüş secure-*/sudo.log-*/messages-* dosyalarını da oku;
#                                                     haftalık rotasyondan sonra raporun boş kalmasını önler)
#
# Centrify: dzdo komutları secure logunda "dzdo[pid]" olarak, yetki kararları ise
#           /var/log/messages içinde adclient AUDIT_TRAIL kayıtları olarak aranır.
#
# sudo logu: sudoers'taki "Defaults syslog=<facility>" ayarı ve rsyslog kuralından
#            (örn. local1.* /var/log/sudo.log) otomatik bulunur; bulunamazsa secure/auth.log kullanılır.
# audit    : auditd varsa sudo komutları ayrıca audit kayıtlarından da gösterilir
#            (auid = oturumu ilk açan kullanıcı). Zaman aralığı: AUDIT_TS (varsayılan this-month).
#
# Not: Yalnızca geçerli log dosyasını okur (/var/log/secure veya /var/log/auth.log).
#      Logrotate ile arşivlenmiş eski kayıtlar için LOG_DOSYASI ile ilgili dosyayı verin.
# =============================================================================

# Yapılandırma dosyası (varsa): sık kullanılan ayarları bir kez yazın. Komut satırındaki değişkenlerin
# dosyadaki değeri ezebilmesi için dosyada  DEGISKEN="${DEGISKEN:-değer}"  biçimini kullanın.
# Dosya root'a ait olmalı ve grup/diğer kullanıcılar tarafından yazılabilir olmamalı (root olarak çalıştırıldığı için).
CONF="${SON_LOGINLER_CONF:-/etc/son_loginler.conf}"
if [ -r "$CONF" ]; then
    if [ "$(stat -c %U "$CONF" 2>/dev/null)" = "root" ] && [ -z "$(find "$CONF" -perm /022 2>/dev/null)" ]; then
        . "$CONF"
    else
        echo "UYARI: $CONF yok sayıldı (sahibi root olmalı, grup/diğerleri yazamamalı: chown root:root; chmod 600)." >&2
    fi
fi

ADET="${1:-20}"
KOMUT_UZUNLUK="${KOMUT_UZUNLUK:-0}"     # komut sütununun azami uzunluğu (0 = komutun tamamı)
HARIC_KULLANICI="${HARIC_KULLANICI:-}"  # SSH ve su/sudo bölümlerinde gizlenecek kullanıcılar (virgülle, örn: postgres,s00827)
ROOT_SSH_IZINLI_IP="${ROOT_SSH_IZINLI_IP:-}"  # root'un SSH ile girmesine izin verilen IP'ler (virgülle); dışındakiler uyarılır
KULLANICI_IP_IZIN="${KULLANICI_IP_IZIN:-}"  # kullanıcı bazında izinli SSH kaynakları: "kullanici=ip1,ip2;kullanici2=ip3"
IP_ETIKET="${IP_ETIKET:-}"              # IP açıklamaları: "ip=ad;ip=ad" - rapordaki IP'lerin yanına ad ekler
YEREL_PTY_ETIKET="${YEREL_PTY_ETIKET:-yerel pty (script)}"   # wtmp'deki IP'siz root pty oturumlarının kaynağı (# ve & kullanmayın)

# IP_ETIKET verildiyse raporu kendi kendine bir kez çağırıp çıktısını etiketleyen sed'den geçirir
if [ -n "$IP_ETIKET" ] && [ -z "$_IP_ETIKET_SARMAL" ]; then
    SEDSCR=""
    OLD_IFS=$IFS; IFS=';'
    for cift in $IP_ETIKET; do
        ip=${cift%%=*}; ad=${cift#*=}
        { [ -z "$ip" ] || [ "$ip" = "$cift" ]; } && continue
        ip_re=${ip//./\\.}; ad=${ad//\\/\\\\}; ad=${ad//&/\\&}; ad=${ad//#/\\#}
        SEDSCR+="s#(^|[^0-9.])${ip_re}(\$|[^0-9.])#\\1${ip} (${ad})\\2#g"$'\n'
    done
    IFS=$OLD_IFS
    export _IP_ETIKET_SARMAL=1
    bash "$0" "$@" | sed -E "$SEDSCR"
    exit "${PIPESTATUS[0]}"
fi
case "$ADET" in
    ''|*[!0-9]*) echo "Hata: kayıt sayısı bir sayı olmalı (örn: $0 50)" >&2; exit 1 ;;
esac

ROOT=0
[ "$(id -u)" -eq 0 ] && ROOT=1

# -----------------------------------------------------------------------------
# Yardımcı fonksiyonlar
# -----------------------------------------------------------------------------
baslik() {
    echo
    echo "=============================================="
    echo " $1"
    echo "=============================================="
}

komut_var() { command -v "$1" >/dev/null 2>&1; }

# last/lastb çıktısında IP yerine yazılan 0.0.0.0 / :: değerini etiketle.
# lastb (btmp): başarısız su denemeleri secure logundaki su kayıtlarıyla eşleştiği için "su/sudo".
# last (wtmp): su/sudo/dzdo wtmp'ye yazmıyor. Audit kaydı bu girişleri libutempter yardımcısının
#              (/usr/libexec/utempter/utempter add/del) ürettiğini, utempter'ı da util-linux "script"
#              komutunun çağırdığını gösterdi (örn. bir yönetim ajanının yum komutunu pty içinde
#              çalıştırması). Etiket: "yerel pty (script)".
# (TTY'si ssh:notty olan kayıtlar başarısız SSH denemesidir, su/sudo değildir)
# $1: IP'si olmayan (0.0.0.0) kayıtlar için yazılacak etiket (varsayılan: su/sudo)
yerel_etiket() {
    local e="${1:-su/sudo}"
    sed -E "/^[^ ]* +ssh:/ s# (0\.0\.0\.0|::)\$# (IP kaydı yok)#; t; s# (0\.0\.0\.0|::)\$# ${e}#"
}

# TAB ile ayrılmış satırları hizalı tablo olarak yazar
# $1: sütun genişlikleri (örn "24,16,16")   $2: başlıklar (örn "Tarih|Kullanıcı|IP")
# $3: (isteğe bağlı) son sütunun azami uzunluğu; aşan kısım "..." ile kesilir
# Not: awk bilerek LC_ALL=C ile çalışır; gawk 5 + UTF-8 yerelinde bayt aralıklı düzenli ifadeler hata verir,
#       C yerelinde ise printf bayt sayar ve aşağıdaki UTF-8 telafisi doğru hizalama sağlar.
tablo() {
    LC_ALL=C awk -F'\t' -v w="$1" -v h="$2" -v m="${3:-0}" '
    function satir(a, n,   i, v, t, extra) {
        for (i = 1; i <= n; i++) {
            v = (a[i] == "" ? "-" : a[i])
            if (i == n && m > 0 && length(v) > m) v = substr(v, 1, m - 3) "..."
            t = v
            extra = gsub(/[\200-\277]/, "", t)   # UTF-8 devam baytları (mawk bayt sayar)
            if (i < n) printf "%-" (W[i] + extra) "s ", v; else printf "%s", v
        }
        print ""
    }
    BEGIN { split(w, W, ","); n = split(h, H, "|"); satir(H, n) }
    { n = split($0, A, "\t"); satir(A, n) }
    END { if (NR == 0) print "  (kayıt bulunamadı)" }'
}

# stdin'deki değerleri sayıp en çok görünen ilk 10'u yazar
ozet_yaz() {
    sort | uniq -c | sort -rn | head -n 10 | awk '
        { n++; c = $1; $1 = ""; sub(/^ /, ""); printf "%6s deneme  -  %s\n", c, $0 }
        END { if (!n) print "  (kayıt bulunamadı)" }'
}

# last/lastb çıktısından (son sütun = IP) en çok görünen IP'ler.
# 0.0.0.0 ve :: "IP kaydı yok" demektir (yerel oturum), ayrıca sayılır.
ip_ozet() {
    local girdi sayilar yerel sshyok
    girdi=$(awk 'NF>0 && $1!="reboot" && $1!="wtmp" && $1!="btmp"')
    sayilar=$(printf '%s\n' "$girdi" | awk '$NF=="0.0.0.0" || $NF=="::" { if ($1 ~ /^ssh:/ || $2 ~ /^ssh:/) s++; else y++ } END { print y+0, s+0 }')
    read -r yerel sshyok <<< "$sayilar"
    printf '%s\n' "$girdi" | awk '{print $NF}' | grep -E '^[0-9a-fA-F.:]+$' | grep -E '[.:]' \
        | grep -v -x -F -e '0.0.0.0' -e '::' | ozet_yaz
    echo "  (${1:-su/sudo oturumu} - IP kaydı yok: ${yerel:-0})"
    if [ "${sshyok:-0}" -gt 0 ]; then
        echo "  (başarısız SSH denemesi - IP kaydı yok: $sshyok)"
    fi
}

# -----------------------------------------------------------------------------
# Güvenlik logunu geçici dosyaya al (bir kez okunur, tüm bölümler kullanır)
#   RHEL/CentOS/Rocky -> /var/log/secure
#   Debian/Ubuntu     -> /var/log/auth.log
#   Diğer             -> journalctl
# -----------------------------------------------------------------------------
LOG="$(mktemp)"
SLOG="$(mktemp)"
MLOG="$(mktemp)"
KLOG="$(mktemp)"
trap 'rm -f "$LOG" "$SLOG" "$MLOG" "$KLOG"' EXIT

# Bir logu okur. ESKI_LOGLAR doluysa logrotate ile dönmüş eski dosyaları da (değişiklik zamanına göre,
# en eskiden yeniye; .gz dahil) başa ekler. $1: güncel log dosyasının yolu
log_topla() {
    local base="$1" f
    if [ -n "$ESKI_LOGLAR" ]; then
        for f in $(ls -1tr "$base"-* "$base".[0-9]* 2>/dev/null); do zcat -f "$f" 2>/dev/null; done
    fi
    cat "$base" 2>/dev/null
}

# sudo logunun yolunu bulur: sudoers "Defaults syslog=X" -> rsyslog "X.* /yol/dosya"
sudo_log_bul() {
    local fac dosya
    fac=$(grep -rhE '^[[:space:]]*Defaults[^#:]*[[:space:]]syslog=[a-z0-9]+' /etc/sudoers /etc/sudoers.d 2>/dev/null \
          | tail -n 1 | sed -E 's/.*syslog=//; s/[^a-z0-9].*$//')
    if [ -n "$fac" ]; then
        dosya=$(grep -hE "^[[:space:]]*([a-z0-9*;.,-]+;)?${fac}\.[^#]*[[:space:]]-?/" /etc/rsyslog.conf /etc/rsyslog.d/*.conf 2>/dev/null \
                | head -n 1 | awk '{print $NF}' | sed 's/^-//')
        [ -n "$dosya" ] && { echo "$dosya"; return; }
    fi
    echo /var/log/sudo.log
}
LOG_KAYNAK="okunamadı (root yetkisi gerekebilir)"

if [ -n "$LOG_DOSYASI" ] && [ -r "$LOG_DOSYASI" ]; then
    cp "$LOG_DOSYASI" "$LOG"; LOG_KAYNAK="$LOG_DOSYASI"
elif [ -r /var/log/secure ]; then
    log_topla /var/log/secure > "$LOG"; LOG_KAYNAK="/var/log/secure${ESKI_LOGLAR:+ (+ döndürülmüş eski dosyalar)}"
elif [ -r /var/log/auth.log ]; then
    log_topla /var/log/auth.log > "$LOG"; LOG_KAYNAK="/var/log/auth.log${ESKI_LOGLAR:+ (+ döndürülmüş eski dosyalar)}"
elif komut_var journalctl && [ "$ROOT" -eq 1 ]; then
    journalctl -t sshd -t sshd-session -t su -t sudo --no-pager -o short-iso > "$LOG" 2>/dev/null \
        && LOG_KAYNAK="journalctl"
fi

# Centrify (dzdo) audit trail kayıtlarını messages/syslog'dan ayıkla
if [ -n "$MESAJ_LOG_DOSYASI" ] && [ -r "$MESAJ_LOG_DOSYASI" ]; then
    grep -F 'AUDIT_TRAIL|Centrify Suite|dzdo|' "$MESAJ_LOG_DOSYASI" > "$MLOG" 2>/dev/null
elif [ -r /var/log/messages ]; then
    log_topla /var/log/messages | grep -F 'AUDIT_TRAIL|Centrify Suite|dzdo|' > "$MLOG" 2>/dev/null
elif [ -r /var/log/syslog ]; then
    log_topla /var/log/syslog | grep -F 'AUDIT_TRAIL|Centrify Suite|dzdo|' > "$MLOG" 2>/dev/null
fi

# sudo komutları için ayrı log varsa onu kullan, yoksa güvenlik logu
SUDO_KAYNAK="$LOG_KAYNAK"
cp "$LOG" "$SLOG" 2>/dev/null
if [ -n "$SUDO_LOG_DOSYASI" ] && [ -r "$SUDO_LOG_DOSYASI" ]; then
    cp "$SUDO_LOG_DOSYASI" "$SLOG"; SUDO_KAYNAK="$SUDO_LOG_DOSYASI"
elif [ -z "$LOG_DOSYASI" ]; then
    SUDO_ADAY="$(sudo_log_bul)"
    if [ -r "$SUDO_ADAY" ]; then
        log_topla "$SUDO_ADAY" > "$SLOG"; SUDO_KAYNAK="$SUDO_ADAY${ESKI_LOGLAR:+ (+ döndürülmüş eski dosyalar)}"
    fi
fi

# -----------------------------------------------------------------------------
# Log ayrıştırıcıları (çıktı: TAB ile ayrılmış alanlar)
# Tarih alanı hem syslog ("Oct 20 21:00:47") hem ISO ("2026-10-20T21:00:47+0300") formatını destekler
# -----------------------------------------------------------------------------

# tarih, kullanıcı, IP, yöntem
ssh_basarili() {
    sed -nE 's#^(.{15}|[0-9T:+-]+) [^ ]+ sshd[a-z-]*\[[0-9]+\]: Accepted ([a-z/-]+) for ([^ ]+) from ([0-9a-fA-F.:]+) port.*#\1\t\3\t\4\t\2#p' "$LOG"
}

# tarih, kullanıcı, IP, yöntem
ssh_basarisiz() {
    sed -nE 's#^(.{15}|[0-9T:+-]+) [^ ]+ sshd[a-z-]*\[[0-9]+\]: Failed ([a-z/-]+) for (invalid user )?([^ ]+) from ([0-9a-fA-F.:]+) port.*#\1\t\4\t\5\t\2#p' "$LOG"
}

# HARIC_KULLANICI listesindeki kullanıcıların satırlarını eler (2. alan = kullanıcı)
haric_filtre() {
    awk -F'\t' -v h="$HARIC_KULLANICI" 'BEGIN { n = split(h, H, ",") } { for (i = 1; i <= n; i++) if ($2 == H[i]) next; print }'
}

# Gizlenen kayıt sayısını bildirir. Argümanlar: ayrıştırıcı fonksiyon adı (+ parametresi, örn: pam_hata su)
haric_notu() {
    [ -n "$HARIC_KULLANICI" ] || return 0
    local toplam kalan
    toplam=$("$@" | wc -l); kalan=$("$@" | haric_filtre | wc -l)
    echo "  (hariç tutulan kullanıcı: $HARIC_KULLANICI - gizlenen kayıt: $((toplam - kalan)))"
}

# SSH'ın "Failed password" dışındaki red/hata kayıtları: anlaşma hatası, geçersiz kullanıcı, ön-kimlik doğrulama kopmaları...
# çıktı: tarih, tür, IP, ayrıntı
ssh_diger_hata() {
    local D='^(.{15}|[0-9T:+-]+) [^ ]+ sshd[a-z-]*\[[0-9]+\]: ' IP='([0-9a-fA-F.:]+)'
    sed -nE \
      -e "s#${D}Unable to negotiate with ${IP} port [0-9]+: (.*)\$#\\1\\tanlaşma hatası\\t\\2\\t\\3#p" \
      -e "s#${D}Invalid user ([^ ]*) from ${IP}( port [0-9]+)?.*\$#\\1\\tgeçersiz kullanıcı\\t\\3\\tkullanıcı=\\2#p" \
      -e "s#${D}Connection closed by (authenticating|invalid) user ([^ ]*) ${IP} port [0-9]+ \\[preauth\\]\$#\\1\\tbağlantı kapatıldı (preauth)\\t\\4\\tkullanıcı=\\3#p" \
      -e "s#${D}Disconnecting (authenticating|invalid) user ([^ ]*) ${IP} port [0-9]+: (.*)\$#\\1\\tbağlantı kesildi\\t\\4\\tkullanıcı=\\3; \\5#p" \
      -e "s#${D}error: maximum authentication attempts exceeded for (invalid user )?([^ ]+) from ${IP} port [0-9]+.*\$#\\1\\tçok fazla deneme\\t\\4\\tkullanıcı=\\3#p" \
      -e "s#${D}Did not receive identification string from ${IP}.*\$#\\1\\tkimlik dizgesi yok\\t\\2\\t#p" \
      -e "s#${D}ROOT LOGIN REFUSED FROM ${IP}.*\$#\\1\\troot girişi reddedildi\\t\\2\\t#p" \
      -e "s#${D}Connection reset by ${IP} port [0-9]+ \\[preauth\\]\$#\\1\\tbağlantı sıfırlandı (preauth)\\t\\2\\t#p" \
      "$LOG" | sed -E 's/ \[preauth\]//'
}

# $1 = su | sudo  ->  tarih, kimden (logname), hedef kullanıcı, tty, rhost
pam_hata() {
    sed -nE "s#^(.{15}|[0-9T:+-]+) [^ ]+ $1\[[0-9]+\]: pam_unix\($1(-l)?:auth\): authentication failure;.*logname=([^ ]*) .*tty=([^ ]*) .*rhost=([^ ]*) +user=([^ ]*).*#\1\t\3\t\6\t\4\t\5#p" "$LOG"
}

# tarih, kimden, hedef kullanıcı
su_basarili() {
    sed -nE 's#^(.{15}|[0-9T:+-]+) [^ ]+ su\[[0-9]+\]: pam_unix\(su(-l)?:session\): session opened for user ([^ (]+)(\([^)]*\))? by ([^( ]*)\(uid=[0-9]+\).*#\1\t\5\t\3#p' "$LOG"
}

# tarih, kullanıcı, hedef kullanıcı, komut
sudo_komut() {
    grep -E 'sudo\[[0-9]+\]: +[^ ]+ : ' "$SLOG" \
      | grep -v -E ': (user NOT in sudoers|command not allowed|[0-9]+ incorrect password attempts?)' \
      | sed -nE 's#^(.{15}|[0-9T:+-]+) [^ ]+ sudo\[[0-9]+\]: +([^ ]+) : .*USER=([^ ;]+) ; COMMAND=(.*)$#\1\t\2\t\3\t\4#p'
}

# tarih, kullanıcı, sebep, hedef kullanıcı, komut
sudo_hata() {
    grep -E 'sudo\[[0-9]+\]: +[^ ]+ : (user NOT in sudoers|command not allowed|[0-9]+ incorrect password attempts?)' "$SLOG" \
      | sed -nE 's#^(.{15}|[0-9T:+-]+) [^ ]+ sudo\[[0-9]+\]: +([^ ]+) : (user NOT in sudoers|command not allowed|[0-9]+ incorrect password attempts?) ;.*USER=([^ ;]+) ; COMMAND=(.*)$#\1\t\2\t\3\t\4\t\5#p'
}

# dzdo (Centrify) komutları - secure logunda "dzdo[pid]: kullanıcı : TTY=.. ; USER=.. ; COMMAND=.."
# çıktı: tarih, kullanıcı, hedef kullanıcı, komut
dzdo_komut() {
    grep -E 'dzdo\[[0-9]+\]: +[^ ]+ : ' "$LOG" \
      | grep -v -E ': (user NOT in|command not allowed|[0-9]+ incorrect password attempts?)' \
      | sed -nE 's#^(.{15}|[0-9T:+-]+) [^ ]+ dzdo\[[0-9]+\]: +([^ ]+) : .*USER=([^ ;]+) ; COMMAND=(.*)$#\1\t\2\t\3\t\4#p'
}

# Centrify adclient AUDIT_TRAIL: yetki kararları (granted/denied...). Komut başlangıç/bitiş olayları atlanır.
# çıktı: tarih, kullanıcı, olay, durum, hedef kullanıcı, komut
centrify_audit() {
    sed -nE 's#^(.{15}|[0-9T:+-]+) [^ ]+ adclient\[[0-9]+\]: .*AUDIT_TRAIL\|Centrify Suite\|dzdo\|[^|]*\|[^|]*\|([^|]*)\|[^|]*\|(.*)$#\1\t\2\t\3#p' "$MLOG" \
      | awk -F'\t' '
        function kv(str, k) {
            if (match(str, k "=[^ ]*")) return substr(str, RSTART + length(k) + 1, RLENGTH - length(k) - 1)
            return ""
        }
        function komut(str,   i, r) {
            i = index(str, "command="); if (!i) return ""
            r = substr(str, i + 8)
            sub(/ (runas|exitcode|role|env|MfaRequired)=.*$/, "", r)
            return r
        }
        $2 ~ /execution (starts|ends)/ { next }
        { u = kv($3, "user"); sub(/\(.*/, "", u)
          printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, u, $2, kv($3, "status"), kv($3, "runas"), komut($3) }'
}

# audit USER_CMD kayıtları: tarih, oturumu açan (auid), çalıştıran (uid), tty, sonuç, komut
audit_sudo() {
    ausearch -m USER_CMD -i -ts "${AUDIT_TS:-this-month}" 2>/dev/null | grep '^type=USER_CMD' \
      | sed -nE 's#^type=USER_CMD msg=audit\((.*)\.[0-9]+:[0-9]+\) *: .* uid=([^ ]+) auid=([^ ]+) .*cmd="?(.*[^"])"? exe=[^ ]* terminal=([^ ]*) res=([a-z]+).*#\1\t\3\t\2\t\5\t\6\t\4#p'
}

# =============================================================================
# RAPOR
# =============================================================================
echo "Sunucu : $(hostname)"
echo "Tarih  : $(date '+%d.%m.%Y %H:%M:%S %z')"
echo "Çalıştıran: $(id -un)$([ "$ROOT" -eq 0 ] && echo ' (root değil - bazı bölümler atlanacak)')"
echo "Log kaynağı: $LOG_KAYNAK"
echo "sudo logu  : $SUDO_KAYNAK"

# 1) Şu anda bağlı kullanıcılar
baslik "1) Şu an bağlı olan kullanıcılar"
who -H

# 2) Son başarılı girişler (wtmp)
baslik "2) Son $ADET başarılı giriş - wtmp (en yeni üstte)"
if komut_var last; then
    if [ -n "$GIZLE_YEREL_PTY" ]; then
        TUMU=$(last -F -w -a -i 2>/dev/null | yerel_etiket "$YEREL_PTY_ETIKET" | grep -v -E '^(reboot|wtmp|$)')
        GIZLI=$(printf '%s\n' "$TUMU" | awk -v e="$YEREL_PTY_ETIKET" 'substr($0, length($0) - length(e) + 1) == e' | wc -l)
        printf '%s\n' "$TUMU" | awk -v e="$YEREL_PTY_ETIKET" 'substr($0, length($0) - length(e) + 1) != e' | head -n "$ADET"
        echo "  (gizlenen IP'siz yerel pty oturumu: $GIZLI - yönetim ajanı kaynaklı olabilir; göstermek için GIZLE_YEREL_PTY'yi kaldırın)"
    else
        last -n "$ADET" -F -w -a -i 2>/dev/null | yerel_etiket "$YEREL_PTY_ETIKET" | grep -v -E '^(reboot|wtmp|$)' || echo "  (kayıt bulunamadı)"
    fi
else
    echo "  'last' komutu bulunamadı."
fi

# 3) Kullanıcı bazında son login - tarihe göre sıralı
baslik "3) Kullanıcı bazında son login (tarihe göre, en yeni üstte)"
if komut_var lastlog; then
    lastlog 2>/dev/null | tail -n +2 | grep -v "Never logged in" | (
        set -f
        while IFS= read -r satir; do
            tarih=$(echo "$satir" | grep -oE '[A-Z][a-z]{2} [A-Z][a-z]{2} +[0-9]+ [0-9:]{8} [+-][0-9]{4} [0-9]{4}')
            [ -z "$tarih" ] && continue
            onek="${satir%%"$tarih"*}"
            set -- $onek
            epoch=$(date -d "$tarih" +%s 2>/dev/null) || continue
            printf '%s\t%s\t%s\t%s\t%s\n' "$epoch" "$1" "${2:--}" "${3:--}" "$tarih"
        done
    ) | sort -t$'\t' -k1,1nr | head -n "$ADET" | cut -f2- | tablo "16,8,16" "Kullanıcı|Port|IP|Son Login"
else
    echo "  'lastlog' komutu bulunamadı (yeni sistemlerde 'lastlog2' kullanılıyor olabilir)."
fi

# 4) Başarısız girişler - btmp (root gerekir)
if [ "$ROOT" -eq 1 ] && komut_var lastb; then
    baslik "4) Son $ADET başarısız giriş - btmp (en yeni üstte)"
    lastb -n "$ADET" -F -w -a -i 2>/dev/null | yerel_etiket | grep -v -E '^(btmp|$)' || echo "  (kayıt bulunamadı)"

    baslik "5) btmp: başarısız denemelerde en çok görünen IP'ler"
    lastb -F -w -a -i 2>/dev/null | ip_ozet
else
    baslik "4-5) Başarısız girişler - btmp"
    echo "  Bu bölümler için scripti sudo ile çalıştırın: sudo $0"
fi

# 6-9) SSH ve su/sudo logları
if [ -s "$LOG" ]; then

    baslik "6) SSH logu: son $ADET başarılı giriş (gerçek kaynak IP + yöntem)"
    ssh_basarili | haric_filtre | tail -n "$ADET" | tac | tablo "24,18,40" "Tarih|Kullanıcı|IP|Yöntem"
    haric_notu ssh_basarili

    echo
    echo "--- Doğrudan root SSH girişleri (son $ADET) ---"
    ssh_basarili | awk -F'\t' '$2 == "root"' | tail -n "$ADET" | tac | tablo "24,18,40" "Tarih|Kullanıcı|IP|Yöntem"
    NROOT=$(ssh_basarili | awk -F'\t' '$2 == "root"' | wc -l)
    if [ "$NROOT" -gt 0 ] && [ "$ROOT" -eq 1 ] && komut_var sshd; then
        PRL=$(sshd -T 2>/dev/null | awk '/^permitrootlogin/ {print $2; exit}')
        echo "  (logdaki root girişi: $NROOT; sshd genel PermitRootLogin: ${PRL:-?})"
        if [ -n "$ROOT_SSH_IZINLI_IP" ]; then
            DISARI=$(ssh_basarili | awk -F'\t' -v ok="$ROOT_SSH_IZINLI_IP" '
                BEGIN { n = split(ok, A, ",") }
                $2 == "root" { f = 0; for (i = 1; i <= n; i++) if ($3 == A[i]) f = 1; if (!f) print }')
            if [ -n "$DISARI" ]; then
                echo "  UYARI: İzin listesi dışındaki IP'lerden root SSH girişi var (son 10):"
                echo "$DISARI" | tail -n 10 | tac | tablo "24,18,40" "Tarih|Kullanıcı|IP|Yöntem"
            else
                echo "  Tüm root SSH girişleri izin listesindeki IP'lerden ($ROOT_SSH_IZINLI_IP)."
            fi
        elif [ "$PRL" = "no" ]; then
            echo "  UYARI: Genel ayar 'no' ama root girişi kabul edilmiş. Bir Match bloğu istisna tanıyor olabilir:"
            echo "         grep -nEi '^\s*(Match|PermitRootLogin)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf"
            echo "         İstisna bilinçliyse izinli IP'leri tanımlayın: ROOT_SSH_IZINLI_IP=ip1,ip2 (uyarı yalnızca listedışı IP'lerde çıkar)"
        fi
    fi

    if [ -n "$KULLANICI_IP_IZIN" ]; then
        echo
        echo "--- Beklenmeyen kaynaktan SSH girişleri (KULLANICI_IP_IZIN listesindeki kullanıcılar için, son $ADET) ---"
        BEKLENMEYEN_SSH=$(ssh_basarili | awk -F'\t' -v m="$KULLANICI_IP_IZIN" '
            BEGIN { n = split(m, P, ";")
                    for (i = 1; i <= n; i++) { k = index(P[i], "="); if (!k) continue
                        u = substr(P[i], 1, k - 1); l = split(substr(P[i], k + 1), A, ",")
                        for (j = 1; j <= l; j++) OK[u, A[j]] = 1; HAS[u] = 1 } }
            ($2 in HAS) && !(($2, $3) in OK)')
        if [ -n "$BEKLENMEYEN_SSH" ]; then
            echo "$BEKLENMEYEN_SSH" | tail -n "$ADET" | tac | tablo "24,18,40" "Tarih|Kullanıcı|IP|Yöntem"
        else
            echo "  (yok: listedeki kullanıcıların tüm girişleri izinli IP'lerden)"
        fi
    fi

    baslik "7) SSH logu: son $ADET başarısız giriş (gerçek kaynak IP + yöntem)"
    ssh_basarisiz | haric_filtre | tail -n "$ADET" | tac | tablo "24,18,40" "Tarih|Kullanıcı|IP|Yöntem"
    haric_notu ssh_basarisiz

    echo
    echo "--- SSH başarısız denemelerde en çok görünen IP'ler (ilk 10) ---"
    ssh_basarisiz | haric_filtre | cut -f3 | ozet_yaz

    echo
    echo "--- SSH başarılı girişlerde en çok görünen IP'ler (ilk 10) ---"
    ssh_basarili | haric_filtre | cut -f3 | ozet_yaz

    echo
    echo "--- SSH başarılı girişler: kullanıcı başına sayı (filtresiz, ilk 10) ---"
    ssh_basarili | cut -f2 | ozet_yaz

    echo
    echo "--- Diğer SSH hataları: anlaşma / geçersiz kullanıcı / ön-kimlik doğrulama kopması (son $ADET) ---"
    ssh_diger_hata | tail -n "$ADET" | tac | tablo "24,32,40" "Tarih|Tür|IP|Ayrıntı"
    echo
    echo "--- Bu hataların özeti: tür <- IP (ilk 10) ---"
    ssh_diger_hata | awk -F'\t' '{print $2 " <- " $3}' | ozet_yaz

    baslik "8) su: son $ADET başarısız deneme"
    pam_hata su | haric_filtre | tail -n "$ADET" | tac | tablo "24,18,14,12" "Tarih|Kimden (logname)|Hedef|TTY|RHOST"
    haric_notu pam_hata su

    echo
    echo "--- su: son $ADET başarılı geçiş ---"
    su_basarili | haric_filtre | tail -n "$ADET" | tac | tablo "24,18" "Tarih|Kimden|Hedef kullanıcı"
    haric_notu su_basarili

    baslik "9) sudo: son $ADET çalıştırılan komut (kaynak: $SUDO_KAYNAK)"
    sudo_komut | haric_filtre | tail -n "$ADET" | tac | tablo "24,16,12" "Tarih|Kullanıcı|Hedef|Komut" "$KOMUT_UZUNLUK"
    haric_notu sudo_komut

    echo
    echo "--- sudo: son $ADET başarısız / reddedilen deneme ---"
    sudo_hata | haric_filtre | tail -n "$ADET" | tac | tablo "24,16,32,10" "Tarih|Kullanıcı|Sebep|Hedef|Komut" "$KOMUT_UZUNLUK"
    haric_notu sudo_hata

    echo
    echo "--- sudo: PAM parola hataları (son $ADET) ---"
    pam_hata sudo | haric_filtre | tail -n "$ADET" | tac | tablo "24,18,14,14" "Tarih|Kimden (logname)|Kullanıcı|TTY|RHOST"
    haric_notu pam_hata sudo

    if grep -q 'dzdo\[[0-9]*\]:' "$LOG"; then
        echo
        echo "--- dzdo (Centrify): son $ADET komut (secure logu) ---"
        dzdo_komut | tail -n "$ADET" | tac | tablo "24,16,12" "Tarih|Kullanıcı|Hedef|Komut" "$KOMUT_UZUNLUK"
    fi

    if [ -s "$MLOG" ]; then
        echo
        echo "--- Centrify audit trail: dzdo yetki kararları (son $ADET) ---"
        centrify_audit | tail -n "$ADET" | tac | tablo "24,12,20,9,8" "Tarih|Kullanıcı|Olay|Durum|Hedef|Komut" "$KOMUT_UZUNLUK"
    fi

    if [ "$ROOT" -eq 1 ] && komut_var ausearch; then
        echo
        echo "--- audit: son $ADET sudo komutu (auid = oturumu ilk açan kullanıcı) ---"
        audit_sudo | tail -n "$ADET" | tac | tablo "24,20,18,10,8" "Tarih|Oturumu açan (auid)|Çalıştıran (uid)|TTY|Sonuç|Komut" "$KOMUT_UZUNLUK"
    fi

    echo
    echo "--- su/sudo başarısız deneme yapan kullanıcılar (ilk 10) ---"
    { pam_hata su; pam_hata sudo; sudo_hata | awk -F'\t' '{print "x\t" $2}'; } | cut -f2 | ozet_yaz

else
    baslik "6-9) SSH ve su/sudo logları"
    echo "  Log okunamadı. sudo ile çalıştırın veya LOG_DOSYASI=/yol/dosya ile log verin."
fi

# 10) Başarılı girişlerde en çok görünen IP'ler (wtmp)
baslik "10) wtmp: başarılı girişlerde en çok görünen IP'ler"
if komut_var last; then
    last -F -w -a -i 2>/dev/null | ip_ozet "$YEREL_PTY_ETIKET"
fi

# 11) Son reboot'lar
baslik "11) Son 5 reboot"
REBOOT=""
komut_var last && REBOOT=$(last reboot -n 5 -F 2>/dev/null | grep -v -E '^(wtmp|$)')
if [ -n "$REBOOT" ]; then
    echo "$REBOOT"
else
    echo "  wtmp içinde reboot kaydı yok (log rotasyonu nedeniyle olabilir)."
    echo "  Son açılış zamanı: $(uptime -s 2>/dev/null || who -b 2>/dev/null)"
fi

# 12) Son oturumlar ve oturum süresince sudo/dzdo ile çalıştırılan komutlar
if [ "$ROOT" -eq 1 ] && komut_var last && [ -s "$LOG" ]; then
    baslik "12) Son oturumlar ve oturum sırasında sudo/dzdo ile çalıştırılan komutlar"
    echo "Eşleştirme: oturum süresi (wtmp) x sudo.log/dzdo kayıtları, kullanıcı adı ve zamana göre."
    echo "Ansible komutları modül adıyla özetlenir (tam komutlar bölüm 9'da). sudo/dzdo KULLANILMADAN çalıştırılan"
    echo "komutlar hiçbir yerde kayıtlı değildir; bunun için auditd execve kuralı ya da psacct gerekir."
    echo
    { sudo_komut; dzdo_komut; } > "$KLOG"
    last -F -w -i 2>/dev/null | grep -v -E '^(reboot|wtmp|btmp|$)' | LC_ALL=C awk -v hex="$HARIC_KULLANICI" -v KFILE="$KLOG" \
        -v gizle="${GIZLE_YEREL_PTY:-}" -v lim="$ADET" -v maxlen="$KOMUT_UZUNLUK" -v nowstr="$(date '+%Y %m %d %H %M %S')" '
    function dn(y, m, d,   era, yoe, doy, doe) {
        y -= (m <= 2); era = int(y / 400); yoe = y - era * 400
        doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
        doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
        return era * 146097 + doe - 719468
    }
    function nv(y, m, d, hh, mi, ss) { return dn(y, m, d) * 86400 + hh * 3600 + mi * 60 + ss }
    function mon(s) { return int((index("JanFebMarAprMayJunJulAugSepOctNovDec", s) + 2) / 3) }
    function logep(ds,   p, t, ep) {
        if (ds ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/)
            return nv(substr(ds,1,4)+0, substr(ds,6,2)+0, substr(ds,9,2)+0, substr(ds,12,2)+0, substr(ds,15,2)+0, substr(ds,18,2)+0)
        split(ds, p, " "); split(p[3], t, ":")
        ep = nv(CY, mon(p[1]), p[2]+0, t[1]+0, t[2]+0, t[3]+0)
        if (ep > NOWN + 86400) ep = nv(CY - 1, mon(p[1]), p[2]+0, t[1]+0, t[2]+0, t[3]+0)
        return ep
    }
    function show(c) {
        if (match(c, /AnsiballZ_[A-Za-z0-9_]+\.py/)) return "ansible modülü: " substr(c, RSTART + 10, RLENGTH - 13)
        if (maxlen + 0 > 0 && length(c) > maxlen) c = substr(c, 1, maxlen - 3) "..."
        return c
    }
    BEGIN {
        split(nowstr, w, " "); CY = w[1] + 0; NOWN = nv(w[1]+0, w[2]+0, w[3]+0, w[4]+0, w[5]+0, w[6]+0)
        n = split(hex, hx, ","); for (i = 1; i <= n; i++) if (hx[i] != "") EX[tolower(hx[i])] = 1
        FS = "\t"
        while ((getline line < KFILE) > 0) {
            split(line, a, "\t"); nc++
            CD[nc] = a[1]; CU[nc] = tolower(a[2]); CT[nc] = a[3]; CC[nc] = a[4]; CE[nc] = logep(a[1])
        }
        FS = " "
    }
    {
        if (ns >= lim) next
        user = $1; tty = $2
        if (user == "" || (tolower(user) in EX)) next
        ip = ($3 ~ /^[0-9A-Fa-f.:]+$/ && $3 ~ /[.:]/) ? $3 : "-"
        if (gizle != "" && (ip == "0.0.0.0" || ip == "::")) next
        rest = $0; nd = 0
        while (match(rest, /[A-Z][a-z][a-z] [A-Z][a-z][a-z] +[0-9]+ [0-9][0-9]:[0-9][0-9]:[0-9][0-9] [0-9][0-9][0-9][0-9]/)) {
            D[++nd] = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        }
        if (nd < 1) next
        split(D[1], q, " "); split(q[4], t, ":")
        st = nv(q[5]+0, mon(q[2]), q[3]+0, t[1]+0, t[2]+0, t[3]+0)
        if (nd >= 2) { split(D[2], q, " "); split(q[4], t, ":"); en = nv(q[5]+0, mon(q[2]), q[3]+0, t[1]+0, t[2]+0, t[3]+0); es = D[2] }
        else if ($0 ~ /still logged in/) { en = NOWN; es = "devam ediyor" }
        else { en = st; es = "bilinmiyor" }
        ns++; SU[ns] = tolower(user); SS[ns] = st; SE[ns] = en
        SH[ns] = sprintf("%-10s %-6s %-16s %s -> %s", user, tty, ip, D[1], es)
    }
    END {
        for (i = 1; i <= ns; i++) {
            print SH[i]; found = 0
            for (j = 1; j <= nc; j++)
                if (CU[j] == SU[i] && CE[j] >= SS[i] - 1 && CE[j] <= SE[i] + 2) {
                    printf "   %s  %-10s %s\n", CD[j], CT[j], show(CC[j]); found = 1
                }
            if (!found) print "   (sudo/dzdo komutu kaydı yok)"
            print ""
        }
        if (ns == 0) print "  (gösterilecek oturum yok)"
    }'
fi

# =============================================================================
# ÖRNEK /etc/son_loginler.conf  (bu blok yalnızca yorumdur; kopyalayıp dosyaya yazın)
# =============================================================================
# HARIC_KULLANICI="${HARIC_KULLANICI:-postgres,s00827}"
# GIZLE_YEREL_PTY="${GIZLE_YEREL_PTY:-1}"
# ESKI_LOGLAR="${ESKI_LOGLAR:-1}"
# ROOT_SSH_IZINLI_IP="${ROOT_SSH_IZINLI_IP:-10.180.99.82,10.180.99.84,10.180.99.86,10.180.99.88}"
# KULLANICI_IP_IZIN="${KULLANICI_IP_IZIN:-s00827=10.66.1.2;postgres=10.180.50.145}"
# YEREL_PTY_ETIKET="${YEREL_PTY_ETIKET:-yerel pty (ManageEngine dcservice -> script)}"
# IP_ETIKET="${IP_ETIKET:-10.66.1.2=Veeam proxy?;10.180.99.82=CyberArk CPM;10.180.99.84=CyberArk;10.180.99.86=CyberArk;10.180.99.88=CyberArk}"
