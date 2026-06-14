#!/bin/bash

clear
echo "=================================================="
echo "    RHCE Dynamic Lab Environment Manager          "
echo "=================================================="
echo "1) Deploy / Start Lab Elements"
echo "2) Destroy Lab Elements"
echo "3) Exit"
read -p "Choose an option [1-3]: " main_choice

case $main_choice in
    1)
        echo ""
        echo "Deployment Modes:"
        echo "a) Deploy Standard Lab (Controller + 5 Managed Servers)"
        echo "b) Deploy Dedicated Curated Repo Server Only"
        echo "c) Custom Deployment Selection (Pick individual VMs)"
        read -p "Select deployment option [a/b/c]: " style_choice

        mkdir -p .ssh_keys
        declare -a active_servers=()

        if [ "$style_choice" == "a" ]; then
            echo "Deploying standard RHCE cluster architecture..."
            active_servers=("controller" "servera" "serverb" "serverc" "serverd" "servere")
            for vm in "${active_servers[@]}"; do
                vagrant up "$vm"
            done

        elif [ "$style_choice" == "b" ]; then
            echo "Deploying Standalone Local Repository Server..."
            active_servers=("reposerver")
            vagrant up reposerver

        elif [ "$style_choice" == "c" ]; then
            echo ""
            echo "=================================================="
            echo " Type 'y' for each VM you want to spin up:       "
            echo "=================================================="
            
            read -p "Deploy 'controller'? [y/N]: " choice_cntl
            if [[ "$choice_cntl" =~ ^[Yy]$ ]]; then active_servers+=("controller"); fi
            
            read -p "Deploy 'reposerver'? [y/N]: " choice_repo
            if [[ "$choice_repo" =~ ^[Yy]$ ]]; then active_servers+=("reposerver"); fi
            
            read -p "Deploy 'storage-lab'? [y/N]: " choice_stg
            if [[ "$choice_stg" =~ ^[Yy]$ ]]; then active_servers+=("storage-lab"); fi
            
            read -p "Deploy 'servera'? [y/N]: " choice_sa
            if [[ "$choice_sa" =~ ^[Yy]$ ]]; then active_servers+=("servera"); fi
            
            read -p "Deploy 'serverb'? [y/N]: " choice_sb
            if [[ "$choice_sb" =~ ^[Yy]$ ]]; then active_servers+=("serverb"); fi
            
            read -p "Deploy 'serverc'? [y/N]: " choice_sc
            if [[ "$choice_sc" =~ ^[Yy]$ ]]; then active_servers+=("serverc"); fi
            
            read -p "Deploy 'serverd'? [y/N]: " choice_sd
            if [[ "$choice_sd" =~ ^[Yy]$ ]]; then active_servers+=("serverd"); fi
            
            read -p "Deploy 'servere'? [y/N]: " choice_se
            if [[ "$choice_se" =~ ^[Yy]$ ]]; then active_servers+=("servere"); fi

            if [ ${#active_servers[@]} -eq 0 ]; then
                echo "No VMs selected. Exiting."
                exit 0
            fi

            echo "Spinning up chosen machines: ${active_servers[*]}"
            for vm in "${active_servers[@]}"; do
                vagrant up "$vm"
            done
        else
            echo "Invalid selection. Exiting."
            exit 1
        fi

        # Run internal IP network synchronization mapping only if controller is part of active build
        if [[ " ${active_servers[*]} " =~ " controller " ]]; then
            echo ""
            echo "=================================================="
            echo "   Configuring Controller /etc/hosts file...     "
            echo "=================================================="
            
            local_entries=$(mktemp)

            # 1. Capture the controller's own bridged IP
            cntl_ip=$(vagrant ssh controller -c "hostname -I" 2>/dev/null | tr ' ' '\n' | grep -v '^10\.0\.2\.' | head -n 1 | tr -d '\r\n')
            if [ ! -z "$cntl_ip" ]; then
                echo "$cntl_ip controller.example.com controller" >> "$local_entries"
                echo "Captured: controller.example.com -> $cntl_ip"
            fi

            # 2. Capture and append all other active infrastructure targets
            for vm in "${active_servers[@]}"; do
                if [ "$vm" != "controller" ]; then
                    ip_addr=$(vagrant ssh "$vm" -c "hostname -I" 2>/dev/null | tr ' ' '\n' | grep -v '^10\.0\.2\.' | head -n 1 | tr -d '\r\n')
                    if [ ! -z "$ip_addr" ]; then
                        echo "$ip_addr ${vm}.example.com ${vm}" >> "$local_entries"
                        echo "Captured: ${vm}.example.com -> $ip_addr"
                    else
                        echo "Warning: Could not fetch IP mapping for $vm"
                    fi
                fi
            done

            echo "Injecting host mappings into controller..."
            vagrant ssh controller -c "
                sudo sed -i '/# --- RHCE LAB SERVERS START ---/,/# --- RHCE LAB SERVERS END ---/d' /etc/hosts
                cat << 'EOF' | sudo tee -a /etc/hosts > /dev/null
# --- RHCE LAB SERVERS START ---
$(cat "$local_entries")
# --- RHCE LAB SERVERS END ---
EOF
            " 2>/dev/null
            rm -f "$local_entries"
            echo "=================================================="
            echo " Controller /etc/hosts resolution completed.     "
            echo "=================================================="
        fi
        ;;
    2)
        echo ""
        echo "=================================================="
        echo "            VM Destruction Options                "
        echo "=================================================="
        echo "a) Destroy EVERYTHING (Wipe entire lab cluster)"
        echo "b) Custom Destruction Selection (Pick individual VMs to wipe)"
        read -p "Select teardown strategy [a/b]: " destroy_style

        if [ "$destroy_style" == "a" ]; then
            echo "WARNING: This will completely delete all lab environment nodes."
            read -p "Confirm structural deletion? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                vagrant destroy -f
                rm -rf .ssh_keys storage_disk.vdi
                echo "Complete lab cluster and storage files have been cleanly purged."
            else
                echo "Operation aborted."
            fi

        elif [ "$destroy_style" == "b" ]; then
            echo ""
            echo "=================================================="
            echo " Type 'y' for each VM you want to DESTROY:       "
            echo "=================================================="
            declare -a targets_to_destroy=()

            read -p "Destroy 'controller'? [y/N]: " dest_cntl
            if [[ "$dest_cntl" =~ ^[Yy]$ ]]; then targets_to_destroy+=("controller"); fi
            
            read -p "Destroy 'reposerver'? [y/N]: " dest_repo
            if [[ "$dest_repo" =~ ^[Yy]$ ]]; then targets_to_destroy+=("reposerver"); fi
            
            read -p "Destroy 'storage-lab'? [y/N]: " dest_stg
            if [[ "$dest_stg" =~ ^[Yy]$ ]]; then targets_to_destroy+=("storage-lab"); fi
            
            read -p "Destroy 'servera'? [y/N]: " dest_sa
            if [[ "$dest_sa" =~ ^[Yy]$ ]]; then targets_to_destroy+=("servera"); fi
            
            read -p "Destroy 'serverb'? [y/N]: " dest_sb
            if [[ "$dest_sb" =~ ^[Yy]$ ]]; then targets_to_destroy+=("serverb"); fi
            
            read -p "Destroy 'serverc'? [y/N]: " dest_sc
            if [[ "$dest_sc" =~ ^[Yy]$ ]]; then targets_to_destroy+=("serverc"); fi
            
            read -p "Destroy 'serverd'? [y/N]: " dest_sd
            if [[ "$dest_sd" =~ ^[Yy]$ ]]; then targets_to_destroy+=("serverd"); fi
            
            read -p "Destroy 'servere'? [y/N]: " dest_se
            if [[ "$dest_se" =~ ^[Yy]$ ]]; then targets_to_destroy+=("servere"); fi

            if [ ${#targets_to_destroy[@]} -eq 0 ]; then
                echo "No VMs selected for removal. Returning to console."
                exit 0
            fi

            echo ""
            echo "Targeting the following nodes for removal: ${targets_to_destroy[*]}"
            read -p "Are you absolutely sure you want to destroy these specific nodes? (y/n): " confirm_sub
            if [[ "$confirm_sub" =~ ^[Yy]$ ]]; then
                for target in "${targets_to_destroy[@]}"; do
                    echo "Tearing down $target..."
                    vagrant destroy -f "$target"
                    if [ "$target" == "storage-lab" ]; then
                        rm -f storage_disk.vdi
                    fi
                done
                echo "Selected nodes cleared successfully."
            else
                echo "Operation aborted."
            fi
        else
            echo "Invalid teardown option selected."
        fi
        ;;
    3)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid option."
        exit 1
        ;;
esac
