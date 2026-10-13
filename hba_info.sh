#!/bin/bash

# Tablo başlığı
printf "%-8s | %-10s | %-8s | %-14s | %-25s | %-22s\n" "Host" "State" "Speed" "PCI Address" "Model / Brand" "WWN (Port Name)"
printf "%s\n" "----------------------------------------------------------------------------------------------------------------------------"

for host_dir in /sys/class/fc_host/host*; do
    if [ -d "$host_dir" ]; then
        host_name=$(basename "$host_dir")

        # Temel Bilgiler
        port_state=$(cat "$host_dir/port_state" 2>/dev/null)
        wwn=$(cat "$host_dir/port_name" 2>/dev/null)

        # Hız Bilgisi
        speed=$(cat "$host_dir/speed" 2>/dev/null)
        if [ "$speed" = "unknown" ] || [ -z "$speed" ]; then
            speed="N/A"
        fi

        # PCI Adresi Tespiti (Sadece yolun en sonundaki gerçek PCI adresini alır)
        pci_address=$(readlink "$host_dir" | grep -oE '[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]' | tail -n 1)

        # Kısa PCI adresi (lspci araması için örn: 07:00.0)
        short_pci=$(echo "$pci_address" | grep -oE '[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]')

        # Model ve Marka Bilgisi
        model_info="Unknown HBA"
        if [ ! -z "$short_pci" ]; then
            model_info=$(lspci -s "$short_pci" 2>/dev/null | sed -e 's/.*Fibre Channel: //' -e 's/Corp\.//' -e 's/Technologies, Inc\.//' -e 's/(rev.*//' | xargs)
        fi

        # Çıktıyı hizalı yazdır
        printf "%-8s | %-10s | %-8s | %-14s | %-25.25s | %-22s\n" "$host_name" "$port_state" "$speed" "$pci_address" "$model_info" "$wwn"
    fi
done
