#!/usr/bin/env bash
 
## author: Kutay Akgün
## edit : Yücel Gemici
## ex: bash log_rotate.sh log_file log_path
## ex: cronjob -> 59 23 * * * bash log_rotate.sh "error.log.$(date +\%Y-\%m-\%d)" "/var/log"

#set -euo pipefail
 
manage_old_logs() {
   local logfile="$1"
   local logpath="$2"
 
   [[ ! -z "$3" ]] && logfile_date="$3" || logfile_date="$logfile"
 
   # eğer log dizininde hali hazırda farklı aylara ait log dosyaları varsa
   # bu log dosyalarını ay-yıl formatında ait olduğu aya ait dizinlere taşı
   # echo "Eski aylara ait log dosyaları dizinlere taşınıyor..."
   #shopt -s nullglob # pattern bulunamazsa boş string dön
 
   local current_month_year="$(date +%m-%Y)"
 
   for old_file in "${logpath}/${logfile_date}".*.gz ; do
      local filename="$(basename -- "$old_file")"
 
 
      # dosya adından price-module.log. ve .gz kısımlarını at
      local date_part="${filename##*log.}"
      date_part="${date_part%.gz}"
 
 
      # tarih formatını ayrıştır
      year=$(echo $date_part|awk -F'-' '{print $1}')
      month=$(echo $date_part|awk -F'-' '{print $2}')
      month_year="${month}-${year}"
 
 
      # log güncel aya aitse taşıma
      #[[ "$month_year" == "$current_month_year" ]] && continue
 
      target_dir="${logpath}/${logfile_date}_${month_year}"
      [[ ! -d "$target_dir" ]] && mkdir --parents "${target_dir}"
      mv "$old_file" "$target_dir/"
   done
   # echo "Eski log dosyaları taşındı."
 
   #shopt -u nullglob
}
 

single_log_rotate() {
   local logfile="$1"
   local logpath="$2"
 
   [[ ! -z "$3" ]] && logfile_date="$3" || logfile_date="$logfile"
 
   # log dosyasını eski günün tarihiyle yedekle ve sıkıştır
   #local yesterday="$(date --date="yesterday" +%d-%m-%Y)"
   local yesterday="$(date --date="yesterday" +%Y-%m-%d)"
   local rotated_file="${logpath}/${logfile_date}.${yesterday}"
 
   # log'u rotate yap ve sıkıştır
   cp "${logpath}/${logfile}" "$rotated_file"
   gzip --best --force "$rotated_file"
 
   # dosyayı kullanan process ID'sini ve file descriptor'i bul
   # pid:fd formatında string olarak al
   # lsof çıktısında 2. kolon pid ve 4.kolon fd
   mapfile -t procs < <(lsof -nP "${logpath}/${logfile_date}" 2> /dev/null | \
      gawk '!/COMMAND/ {print $2":"$4}')
 
 
      # procs dizisi dolmuşsa log dosyası kullanılıyor demektir
      # dizideki tüm fd'leri sıfırla
      if (( ${#procs[@]} > 0 )); then
         for (( i = 0; i < ${#procs[@]}; ++i )); do
            # "pid:fd" olarak her diziye pid ve fd değerlerini yazmıştık
            # : sembolünü ayırıcı olarak kullanıp pid ve fd değerlerini ayrıştır
            IFS=: read pid fd <<< "${procs[i]}"
 
 
            fd="${fd%%[a-zA-Z]*}" # fd değerinin sayi kısmını al
 
            # process'in halen çalışır durumda olduğunu kontrol et
            if [[ -e "/proc/$pid/fd/$fd" ]]; then
               # log dosyasını sıfırla
               : > /proc/"$pid"/fd/"$fd"
            fi
         done
      
      elif [ "$logfile_date" = "wrapper.log" ] ; then
           # dosya wrapper.log ise ve herhangi bir aktif process tarafindan okunmuyorsa dosya manuel olarak sifirlanir.
          >${logpath}/${logfile_date}
      fi
   }
 
 
datechk() {
logfile_date="$1"
logfile_base=""
echo "$logfile_date"|grep -q "$(date +%Y-%m-%d)"$
if [ $? -eq 0 ] ; then
logfile_base=$(echo "$logfile_date"|sed "s/.$(date +%Y-%m-%d)//")
fi
}


log_file_get() {
[[ -z "$1" ]] && echo "Log dosya bilgisi belirtilmeli !! " && exit
[[ -z "$2" ]] && echo "Log dosya yada dizin bilgisi belirtilmeli !! " && exit
dirchk="${@: -1}"
[[ ! -d "$dirchk" ]] &&  echo "Son parametre gecerli bir dizin bilgisi olmali !! " && exit
cc="${#@}"
c=$((cc-1))
eval log_path=\${$cc}
LOG_PATH=$log_path
 
 
for((j=1;j<=$c;j++)) ; do
eval log_file=\${$j}
LOG_FILE=$log_file
 
datechk "$LOG_FILE"
[[ ! -z "$logfile_base" ]] && LOG_FILE_DATE="$logfile_base"
 
      exec 3>/var/lock/"$(basename "$LOG_FILE")".lock
      flock -n 3 || exit 1
 
[[ ! -f "$LOG_PATH"/"$LOG_FILE" ]] && continue
[[ ! -z "$logfile_base" ]] && test "$(echo "$LOG_FILE"|grep -v '\.log\.')" && continue
[[ -z "$logfile_base" ]] && test "$(echo "$LOG_FILE"|grep -v '\.log\.*')" && continue
 
      # önce log rotate yap
      single_log_rotate "$LOG_FILE" "$LOG_PATH" "$LOG_FILE_DATE"
 
      # sonra, eğer geçmiş aylara ait loglar varsa, arşivleme yap
      manage_old_logs "$LOG_FILE" "$LOG_PATH" "$LOG_FILE_DATE"
done
   }
 
log_file_get $@
