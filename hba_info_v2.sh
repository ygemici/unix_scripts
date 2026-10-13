#!/bin/bash

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
        printf "%-12s | %-6s | %-8s | %-16s | %-16s | %-32s | %-32s\n" "Alias" "Size" "Durum" "host1 (Act/Fail)" "host4 (Act/Fail)" "Usage Type / Target VG" "Storage Vendor / Model"
        echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------"

        for mpath in $multipath_list; do
            mpath_info=$(multipath -ll "$mpath")

            size=$(echo "$mpath_info" | grep -oE 'size=[0-9.]+[GTM]' | cut -d= -f2)
            [ -z "$size" ] && size=$(echo "$mpath_info" | grep -oE 'size=[0-9 architecturalG-TM]+' | cut -d= -f2)

            vendor_model=$(echo "$mpath_info" | grep -E '^[a-zA-Z0-9_-]+' | awk -F')' '{print $2}' | xargs)

            h1_active=$(echo "$mpath_info" | grep -E '[[:space:]]+1:[0-9]+:[0-9]+:[0-9]+' | grep -c -E 'running|ready|active')
            h1_failed=$(echo "$mpath_info" | grep -E '[[:space:]]+1:[0-9]+:[0-9]+:[0-9]+' | grep -c -E 'faulty|failed|offline|failed/faulty')

            h4_active=$(echo "$mpath_info" | grep -E '[[:space:]]+4:[0-9]+:[0-9]+:[0-9]+' | grep -c -E 'running|ready|active')
            h4_failed=$(echo "$mpath_info" | grep -E '[[:space:]]+4:[0-9]+:[0-9]+:[0-9]+' | grep -c -E 'faulty|failed|offline|failed/faulty')

            if [ "$h1_failed" -gt 0 ] || [ "$h4_failed" -gt 0 ]; then
                status="Degraded"
            else
                status="Healthy"
            fi

            usage_info="Unused / Raw"
            dev_path="/dev/mapper/$mpath"

            # 1. Geliştirilmiş LVM Sorgusu: Hem disk formatlarını hem de p1/mp1 gibi partition varyasyonlarını check eder
            if command -v pvs &> /dev/null; then
                vg_name=$(pvs --noheadings -o vg_name "$dev_path" "${dev_path}1" "${dev_path}p1" 2>/dev/null | xargs | awk '{print $1}')
                if [ ! -z "$vg_name" ]; then
                    usage_info="LVM VG: $vg_name"
                fi
            fi

            # 2. blkid ile Oracle ASM Sorgusu
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

            printf "%-12s | %-6s | %-8s | %-16s | %-16s | %-32.32s | %-32s\n" "$mpath" "$size" "$status" "$h1_active/$h1_failed" "$h4_active/$h4_failed" "$usage_info" "$vendor_model"
        done
    fi
else
    echo "[UYARI] 'multipath' komutu bulunamadı."
fi
echo "================================================================================================================================================================"

