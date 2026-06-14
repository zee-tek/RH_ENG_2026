#!/bin/bash

# ==========================================================
# ANSI Color Palette Definitions
# ==========================================================
NC='\033[0m'               # Text Reset (No Color)

# Bold Text Colors
BOLD_WHITE='\033[1;37m'
BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_RED='\033[1;31m'
BOLD_MAGENTA='\033[1;35m'

# Regular Text Colors (FIXED: Added missing escape brackets)
TEXT_CYAN='\033[0;36m'
TEXT_GREEN='\033[0;32m'
TEXT_YELLOW='\033[0;33m'

clear
# Explicit Header Notice Requested
echo -e "${BOLD_MAGENTA}>>> Starting RHCE LAB SETUP...${NC}\n"

echo -e "${BOLD_CYAN}==================================================${NC}"
echo -e "${BOLD_WHITE}    RHCE Dynamic Lab Environment Manager          ${NC}"
echo -e "${BOLD_CYAN}==================================================${NC}"
echo -e "${BOLD_GREEN}1)${TEXT_GREEN} Deploy / Start Lab Elements${NC}"
echo -e "${BOLD_YELLOW}2)${TEXT_YELLOW} Halt / Stop Lab Elements (Keep Data)${NC}"
echo -e "${BOLD_RED}3)${TEXT_RED} Destroy Lab Elements (Wipe Data)${NC}"
echo -e "${BOLD_WHITE}4)${NC} Exit"
echo -e "${BOLD_CYAN}==================================================${NC}"
read -p "$(echo -e "${BOLD_YELLOW}Choose an option [1-4]: ${NC}")" main_choice

case $main_choice in
    1)
        echo ""
        echo -e "${BOLD_WHITE}Deployment Modes:${NC}"
        echo -e "${BOLD_CYAN}a)${NC} Deploy Standard Lab (Controller + 5 Managed Servers)"
        echo -e "${BOLD_CYAN}b)${NC} Deploy Dedicated Curated Repo Server Only"
        echo -e "${BOLD_CYAN}c)${NC} Custom Deployment Selection (Pick individual VMs)"
        read -p "$(echo -e "${BOLD_YELLOW}Select deployment option [a/b/c]: ${NC}")" style_choice

        mkdir -p .ssh_keys
        declare -a active_servers=()

        if [ "$style_choice" == "a" ]; then
            echo -e "\n${BOLD_GREEN}Deploying standard RHCE cluster architecture...${NC}"
            active_servers=("controller" "servera" "serverb" "serverc" "serverd" "servere")
            for vm in "${active_servers[@]}"; do
                vagrant up "$vm"
            done

        elif [ "$style_choice" == "b" ]; then
            echo -e "\n${BOLD_GREEN}Deploying Standalone Local Repository Server...${NC}"
            active_servers=("reposerver")
            vagrant up reposerver

        elif [ "$style_choice" == "c" ]; then
            echo ""
            echo -e "${BOLD_CYAN}==================================================${NC}"
            echo -e "${BOLD_WHITE} Type 'y' for each VM you want to spin up:       ${NC}"
            echo -e "${BOLD_CYAN}==================================================${NC}"
            
            read -p "$(echo -e "${TEXT_CYAN}Deploy 'controller'? [y/N]: ${NC}")" choice_cntl
            if [[ "$choice_cntl" =~ ^[Yy]$ ]]; then active_servers+=("controller"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Deploy 'reposerver'? [y/N]: ${NC}")" choice_repo
            if [[ "$choice_repo" =~ ^[Yy]$ ]]; then active_servers+=("reposerver"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Deploy 'storage-lab'? [y/N]: ${NC}")" choice_stg
            if [[ "$choice_stg" =~ ^[Yy]$ ]]; then active_servers+=("storage-lab"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Deploy 'servera'? [y/N]: ${NC}")" choice_sa
            if [[ "$choice_sa" =~ ^[Yy]$ ]]; then active_servers+=("servera"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Deploy 'serverb'? [y/N]: ${NC}")" choice_sb
            if [[ "$choice_sb" =~ ^[Yy]$ ]]; then active_servers+=("serverb"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Deploy 'serverc'? [y/N]: ${NC}")" choice_sc
            if [[ "$choice_sc" =~ ^[Yy]$ ]]; then active_servers+=("serverc"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Deploy 'serverd'? [y/N]: ${NC}")" choice_sd
            if [[ "$choice_sd" =~ ^[Yy]$ ]]; then active_servers+=("serverd"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Deploy 'servere'? [y/N]: ${NC}")" choice_se
            if [[ "$choice_se" =~ ^[Yy]$ ]]; then active_servers+=("servere"); fi

            if [ ${#active_servers[@]} -eq 0 ]; then
                echo -e "${BOLD_RED}No VMs selected. Exiting.${NC}"
                exit 0
            fi

            echo -e "\n${BOLD_GREEN}Spinning up chosen machines: ${BOLD_WHITE}${active_servers[*]}${NC}"
            for vm in "${active_servers[@]}"; do
                vagrant up "$vm"
            done
        else
            echo -e "${BOLD_RED}Invalid selection. Exiting.${NC}"
            exit 1
        fi

        # Run internal IP network synchronization mapping only if controller is part of active build
        if [[ " ${active_servers[*]} " =~ " controller " ]]; then
            echo ""
            echo -e "${BOLD_CYAN}==================================================${NC}"
            echo -e "${BOLD_WHITE}   Configuring Controller /etc/hosts file...     ${NC}"
            echo -e "${BOLD_CYAN}==================================================${NC}"
            
            local_entries=$(mktemp)

            # 1. Capture the controller's own bridged IP
            cntl_ip=$(vagrant ssh controller -c "hostname -I" 2>/dev/null | tr ' ' '\n' | grep -v '^10\.0\.2\.' | head -n 1 | tr -d '\r\n')
            if [ ! -z "$cntl_ip" ]; then
                echo "$cntl_ip controller.example.com controller" >> "$local_entries"
                echo -e "${TEXT_GREEN}Captured:${NC} controller.example.com -> $cntl_ip"
            fi

            # 2. Capture and append all other active infrastructure targets
            for vm in "${active_servers[@]}"; do
                if [ "$vm" != "controller" ]; then
                    ip_addr=$(vagrant ssh "$vm" -c "hostname -I" 2>/dev/null | tr ' ' '\n' | grep -v '^10\.0\.2\.' | head -n 1 | tr -d '\r\n')
                    if [ ! -z "$ip_addr" ]; then
                        echo "$ip_addr ${vm}.example.com ${vm}" >> "$local_entries"
                        echo -e "${TEXT_GREEN}Captured:${NC} ${vm}.example.com -> $ip_addr"
                    else
                        echo -e "${BOLD_YELLOW}Warning: Could not fetch IP mapping for $vm${NC}"
                    fi
                fi
            done

            echo -e "\n${BOLD_WHITE}Injecting host mappings into controller...${NC}"
            vagrant ssh controller -c "
                sudo sed -i '/# --- RHCE LAB SERVERS START ---/,/# --- RHCE LAB SERVERS END ---/d' /etc/hosts
                cat << 'EOF' | sudo tee -a /etc/hosts > /dev/null
# --- RHCE LAB SERVERS START ---
$(cat "$local_entries")
# --- RHCE LAB SERVERS END ---
EOF
            " 2>/dev/null
            rm -f "$local_entries"
            echo -e "${BOLD_CYAN}==================================================${NC}"
            echo -e "${BOLD_GREEN} Controller /etc/hosts resolution completed.     ${NC}"
            echo -e "${BOLD_CYAN}==================================================${NC}"
        fi
        ;;
    2)
        echo ""
        echo -e "${BOLD_YELLOW}==================================================${NC}"
        echo -e "${BOLD_WHITE}              VM Halt / Stop Options              ${NC}"
        echo -e "${BOLD_YELLOW}==================================================${NC}"
        echo -e "${BOLD_CYAN}a)${NC} Halt EVERYTHING (Power down entire lab gracefully)"
        echo -e "${BOLD_CYAN}b)${NC} Custom Halt Selection (Pick individual VMs to stop)"
        read -p "$(echo -e "${BOLD_YELLOW}Select target shutdown strategy [a/b]: ${NC}")" halt_style

        if [ "$halt_style" == "a" ]; then
            echo -e "\n${BOLD_YELLOW}Gracefully shutting down all running environment nodes...${NC}"
            vagrant halt
            echo -e "${BOLD_GREEN}All lab machines are powered down successfully.${NC}"

        elif [ "$halt_style" == "b" ]; then
            echo ""
            echo -e "${BOLD_YELLOW}==================================================${NC}"
            echo -e "${BOLD_WHITE} Type 'y' for each VM you want to STOP:          ${NC}"
            echo -e "${BOLD_YELLOW}==================================================${NC}"
            declare -a targets_to_halt=()

            read -p "$(echo -e "${TEXT_CYAN}Stop 'controller'? [y/N]: ${NC}")" halt_cntl
            if [[ "$halt_cntl" =~ ^[Yy]$ ]]; then targets_to_halt+=("controller"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Stop 'reposerver'? [y/N]: ${NC}")" halt_repo
            if [[ "$halt_repo" =~ ^[Yy]$ ]]; then targets_to_halt+=("reposerver"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Stop 'storage-lab'? [y/N]: ${NC}")" halt_stg
            if [[ "$halt_stg" =~ ^[Yy]$ ]]; then targets_to_halt+=("storage-lab"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Stop 'servera'? [y/N]: ${NC}")" halt_sa
            if [[ "$halt_sa" =~ ^[Yy]$ ]]; then targets_to_halt+=("servera"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Stop 'serverb'? [y/N]: ${NC}")" halt_sb
            if [[ "$halt_sb" =~ ^[Yy]$ ]]; then targets_to_halt+=("serverb"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Stop 'serverc'? [y/N]: ${NC}")" halt_sc
            if [[ "$halt_sc" =~ ^[Yy]$ ]]; then targets_to_halt+=("serverc"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Stop 'serverd'? [y/N]: ${NC}")" halt_sd
            if [[ "$halt_sd" =~ ^[Yy]$ ]]; then targets_to_halt+=("serverd"); fi
            
            read -p "$(echo -e "${TEXT_CYAN}Stop 'servere'? [y/N]: ${NC}")" halt_se
            if [[ "$halt_se" =~ ^[Yy]$ ]]; then targets_to_halt+=("servere"); fi

            if [ ${#targets_to_halt[@]} -eq 0 ]; then
                echo -e "${BOLD_YELLOW}No VMs selected for halt execution. Returning to console.${NC}"
                exit 0
            fi

            echo -e "\n${BOLD_YELLOW}Stopping selected nodes: ${BOLD_WHITE}${targets_to_halt[*]}${NC}"
            for target in "${targets_to_halt[@]}"; do
                echo -e "${BOLD_YELLOW}Halting $target...${NC}"
                vagrant halt "$target"
            done
            echo -e "${BOLD_GREEN}Selected nodes stopped successfully.${NC}"
        else
            echo -e "${BOLD_RED}Invalid shutdown option selected.${NC}"
        fi
        ;;
    3)
        echo ""
        echo -e "${BOLD_RED}==================================================${NC}"
        echo -e "${BOLD_WHITE}            VM Destruction Options                ${NC}"
        echo -e "${BOLD_RED}==================================================${NC}"
        echo -e "${BOLD_CYAN}a)${NC} ${BOLD_RED}Destroy EVERYTHING (Wipe entire lab cluster)${NC}"
        echo -e "${BOLD_CYAN}b)${NC} Custom Destruction Selection (Pick individual VMs to wipe)"
        read -p "$(echo -e "${BOLD_YELLOW}Select teardown strategy [a/b]: ${NC}")" destroy_style

        if [ "$destroy_style" == "a" ]; then
            echo -e "\n${BOLD_RED}WARNING: This will completely delete all lab environment nodes.${NC}"
            read -p "$(echo -e "${BOLD_YELLOW}Confirm structural deletion? (y/n): ${NC}")" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                vagrant destroy -f
                rm -rf .ssh_keys storage_disk.vdi
                echo -e "${BOLD_GREEN}Complete lab cluster and storage files have been cleanly purged.${NC}"
            else
                echo -e "${BOLD_YELLOW}Operation aborted.${NC}"
            fi

        elif [ "$destroy_style" == "b" ]; then
            echo ""
            echo -e "${BOLD_RED}==================================================${NC}"
            echo -e "${BOLD_WHITE} Type 'y' for each VM you want to DESTROY:       ${NC}"
            echo -e "${BOLD_RED}==================================================${NC}"
            declare -a targets_to_destroy=()

            read -p "$(echo -e "${TEXT_YELLOW}Destroy 'controller'? [y/N]: ${NC}")" dest_cntl
            if [[ "$dest_cntl" =~ ^[Yy]$ ]]; then targets_to_destroy+=("controller"); fi
            
            read -p "$(echo -e "${TEXT_YELLOW}Destroy 'reposerver'? [y/N]: ${NC}")" dest_repo
            if [[ "$dest_repo" =~ ^[Yy]$ ]]; then targets_to_destroy+=("reposerver"); fi
            
            read -p "$(echo -e "${TEXT_YELLOW}Destroy 'storage-lab'? [y/N]: ${NC}")" dest_stg
            if [[ "$dest_stg" =~ ^[Yy]$ ]]; then targets_to_destroy+=("storage-lab"); fi
            
            read -p "$(echo -e "${TEXT_YELLOW}Destroy 'servera'? [y/N]: ${NC}")" dest_sa
            if [[ "$dest_sa" =~ ^[Yy]$ ]]; then targets_to_destroy+=("servera"); fi
            
            read -p "$(echo -e "${TEXT_YELLOW}Destroy 'serverb'? [y/N]: ${NC}")" dest_sb
            if [[ "$dest_sb" =~ ^[Yy]$ ]]; then targets_to_destroy+=("serverb"); fi
            
            read -p "$(echo -e "${TEXT_YELLOW}Destroy 'serverc'? [y/N]: ${NC}")" dest_sc
            if [[ "$dest_sc" =~ ^[Yy]$ ]]; then targets_to_destroy+=("serverc"); fi
            
            read -p "$(echo -e "${TEXT_YELLOW}Destroy 'serverd'? [y/N]: ${NC}")" dest_sd
            if [[ "$dest_sd" =~ ^[Yy]$ ]]; then targets_to_destroy+=("serverd"); fi
            
            read -p "$(echo -e "${TEXT_YELLOW}Destroy 'servere'? [y/N]: ${NC}")" dest_se
            if [[ "$dest_se" =~ ^[Yy]$ ]]; then targets_to_destroy+=("servere"); fi

            if [ ${#targets_to_destroy[@]} -eq 0 ]; then
                echo -e "${BOLD_YELLOW}No VMs selected for removal. Returning to console.${NC}"
                exit 0
            fi

            echo ""
            echo -e "${BOLD_RED}Targeting the following nodes for removal: ${BOLD_WHITE}${targets_to_destroy[*]}${NC}"
            read -p "$(echo -e "${BOLD_YELLOW}Are you absolutely sure you want to destroy these specific nodes? (y/n): ${NC}")" confirm_sub
            if [[ "$confirm_sub" =~ ^[Yy]$ ]]; then
                for target in "${targets_to_destroy[@]}"; do
                    echo -e "${BOLD_RED}Tearing down $target...${NC}"
                    vagrant destroy -f "$target"
                    if [ "$target" == "storage-lab" ]; then
                        rm -f storage_disk.vdi
                    fi
                done
                echo -e "${BOLD_GREEN}Selected nodes cleared successfully.${NC}"
            else
                echo -e "${BOLD_YELLOW}Operation aborted.${NC}"
            fi
        else
            echo -e "${BOLD_RED}Invalid teardown option selected.${NC}"
        fi
        ;;
    4)
        echo -e "${BOLD_WHITE}Exiting. Keep automating!${NC}"
        exit 0
        ;;
    *)
        echo -e "${BOLD_RED}Invalid option.${NC}"
        exit 1
        ;;
esac
