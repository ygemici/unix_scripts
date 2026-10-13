#!/bin/bash

## Gemini ##

# Gelen parametreyi kontrol et
if [ "$1" == "scan" ]; then
    echo "================================================================================================================================"
    echo "                              [BİLGİ] GLOBAL SCSI BUS VE HBA PORTLARI TARANIYOR (SCANNING)...                                  "
    echo "================================================================================================================================"

    # 1. Yöntem: rescan-scsi-bus.sh kontrolü ve tetiklenmesi
    if command -v rescan-scsi-bus.sh &> /dev/null; then
        echo "-> 'rescan-scsi-bus.sh' kullanılarak tüm SCSI yolları taranıyor..."
        rescan-scsi-bus.sh -a -r > /dev/null 2>&1
    else
        # 2. Yöntem: Sistemdeki tüm host portlarını dinamik olarak tara
        echo "-> Sistemdeki tüm mevcut scsi_host kanalları tetikleniyor..."
        for host in /sys/class/scsi_host/host*; do
            if [ -d "$host" ]; then
                echo "- - -" > "$host/scan" 2>/dev/null
            fi
        done
    fi

    # Multipath daemon'ı yeni diskleri haritalaması için tetikle
    if command -v multipath &> /dev/null; then
        echo "-> Multipath katmanı güncelleniyor (multipath reload)..."
        multipath > /dev/null 2>&1
        sleep 2
    fi
    echo -e "-> Tarama tamamlandı. Rapor üretiliyor...\n\n"
fi

clear
echo "================================================================================================================================================================"
echo "                                                          1. HBA VE SAN FABRIC (SWITCH) DETAYLARI                                                               "
echo "================================================================================================================================================================"
printf "%-8s | %-8s | %-8s | %-13s | %-25s | %-20s | %-20s\n" "Host" "State" "Speed" "PCI Address" "Model / Brand" "Port WWN" "Fabric Name / Node"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"

for host_dir in /sys/class/fc_host/host*; do
    if [ -d "$host_dir" ]; then
        host_name=$(basename "$host_dir")
        port_state=$(cat "$host_dir/port_state" 2>/dev/null)
        wwn=$(cat "$host_dir/port_name" 2>/dev/null | sed 's/0x//')
        speed=$(cat "$host_dir/speed" 2>/dev/null)
        [ "$speed" = "unknown" ] || [ -z "$speed" ] && speed="N/A"

        pci_address=$(readlink "$host_dir" | grep -oE '[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]' | tail -n 1)
        short_pci=$(echo "$pci_address" | grep -oE '[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]')

        model_info="Unknown HBA"
        if [ ! -z "$short_pci" ]; then
            model_info=$(lspci -s "$short_pci" 2>/dev/null | sed -e 's/.*Fibre Channel: //' -e 's/Corp\.//' -e 's/Technologies, Inc\.//' -e 's/(rev.*//' | xargs)
        fi

        fabric_name=$(cat "$host_dir/fabric_name" 2>/dev/null | sed 's/0x//')
        if [ -z "$fabric_name" ] || [ "$fabric_name" = "0" ]; then
            fabric_name="No Fabric/Direct"
        fi

        printf "%-8s | %-8s | %-8s | %-13s | %-25.25s | 0x%-18s | 0x%-18s\n" "$host_name" "$port_state" "$speed" "$pci_address" "$model_info" "$wwn" "$fabric_name"
    fi
done

echo -e "\n"
echo "================================================================================================================================================================"
echo "                                                       2. MULTIPATH DISK, YOL VE DOKU (LVM/ASM) ANALİZİ                                                         "
echo "================================================================================================================================================================"

if command -v multipath &> /dev/null; then
    multipath_list=$(multipath -ll | grep -E '^[a-zA-Z0-9_-]+ \([0-9a-fA-F]+\)' | awk '{print $1}')
    multipath_count=$(echo "$multipath_list" | grep -v '^$' | wc -l)

    if [ "$multipath_count" -eq 0 ]; then
        echo "[BİLGİ] Sunucuda tanımlı aktif bir Multipath (MPIO) diski bulunamadı."
    else
        echo "Toplam Aktif Multipath Cihazı Sayısı: $multipath_count"
        echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"
        printf "%-12s | %-6s | %-8s | %-18s | %-32s | %-32s\n" "Alias" "Size" "Durum" "Total Paths (Act/Fail)" "Usage Type / Target VG" "Storage Vendor / Model"
        echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"

        for mpath in $multipath_list; do
            mpath_info=$(multipath -ll "$mpath")

            size=$(echo "$mpath_info" | grep -oE 'size=[0-9.]+[GTM]' | cut -d= -f2)
            [ -z "$size" ] && size=$(echo "$mpath_info" | grep -oE 'size=[0-9 architecturalG-TM]+' | cut -d= -f2)

            vendor_model=$(echo "$mpath_info" | grep -E '^[a-zA-Z0-9_-]+' | awk -F')' '{print $2}' | xargs)

            # Sunucudaki HBA sayısından bağımsız olarak tüm aktif ve arızalı yolları genel olarak sayar
            total_active=$(echo "$mpath_info" | grep -E '[[:space:]]+[0-9]+:[0-9]+:[0-9]+:[0-9]+' | grep -c -E 'running|ready|active')
            total_failed=$(echo "$mpath_info" | grep -E '[[:space:]]+[0-9]+:[0-9]+:[0-9]+:[0-9]+' | grep -c -E 'faulty|failed|offline|failed/faulty')

            if [ "$total_failed" -gt 0 ]; then
                status="Degraded"
            else
                status="Healthy"
            fi

            usage_info="Unused / Raw"
            dev_path="/dev/mapper/$mpath"

            # LVM Kontrolü (Partition bağımsız dinamik eşleşme)
            if command -v pvs &> /dev/null; then
                vg_name=$(pvs --noheadings -o vg_name "$dev_path" "${dev_path}1" "${dev_path}p1" 2>/dev/null | xargs | awk '{print $1}')
                if [ ! -z "$vg_name" ]; then
                    usage_info="LVM VG: $vg_name"
                fi
            fi

            # blkid ile Oracle ASM Kontrolü
            if [ "$usage_info" = "Unused / Raw" ]; then
                first_sd_dev=$(echo "$mpath_info" | grep -E 'running|ready|active' | awk '{print $3}' | grep -E '^sd[a-z]+' | head -n 1)
                if [ ! -z "$first_sd_dev" ]; then
                    blkid_search=$(blkid | grep -E "/dev/${first_sd_dev}[0-9]*:")
                    if echo "$blkid_search" | grep -q 'TYPE="oracleasm"'; then
                        asm_label=$(echo "$blkid_search" | grep 'TYPE="oracleasm"' | grep -oP 'LABEL="\K[^"]+' | head -n 1)
                        usage_info="Oracle ASM (LABEL: $asm_label)"
                    fi
                fi
            fi

            printf "%-12s | %-6s | %-8s | %-22s | %-32.32s | %-32s\n" "$mpath" "$size" "$status" "$total_active/$total_failed" "$usage_info" "$vendor_model"
        done
    fi
else
    echo "[UYARI] 'multipath' komutu bulunamadı."
fi
echo "================================================================================================================================================================"

