#!/bin/bash
#===============================================================================
#  __        __   __   __        ___               __     
# |__)  /\  |  \ /  \ /  ` |__| |__     |     /\  |__)    
# |__) /~~\ |__/ \__/ \__, |  | |___    |___ /~~\ |__)    
#                                                         
#  __        ___     __   ___  __   ___ ___ ___  ___  __  
# |__) \  / |__     |__) |__  /__` |__   |   |  |__  |__) 
# |     \/  |___    |  \ |___ .__/ |___  |   |  |___ |  \ 
#                                                             
#
#===============================================================================  
# 
# Script Name   : PVE Node Resetter
# Description   : Automate the resetting process of PVE node.
# Author        : Alan Badier
# Date          : 2024-06-11
# Version       : 1.0
#
#===============================================================================

# Function to display the ASCII header
warning() {
  cat << "EOF"
===============================================================================
 __        __   __   __        ___               __     
|__)  /\  |  \ /  \ /  ` |__| |__     |     /\  |__)    
|__) /~~\ |__/ \__/ \__, |  | |___    |___ /~~\ |__)    
                                                        
 __        ___     __   ___  __   ___ ___ ___  ___  __  
|__) \  / |__     |__) |__  /__` |__   |   |  |__  |__) 
|     \/  |___    |  \ |___ .__/ |___  |   |  |___ |  \ 

===============================================================================  

Script Name   : PVE Node Resetter
Description   : Automate the resetting process of PVE node.
Author        : Alan Badier
Date          : 2024-06-11
Version       : 1.0

===============================================================================
EOF
}

# Function to log messages with a timestamp
log() {
  local message="$1"
  echo "$(date '+[%Y-%m-%d %H:%M:%S]') $message"
}

# Ask for confirmation before processing
read -p "Are you sure you want to proceed? THIS ACTION CANNOT BE UNDONE. (yes/no): " confirmation

if [ "$confirmation" != "yes" ]; then
    log "Operation aborted."
    exit 1
fi

# Deleting all VMs and templates
log "Deleting all VMs and templates..."
for vmid in $(qm list | awk 'NR>1 {print $1}'); do
    log "Deleting VM/Template ID $vmid..."
    qm stop $vmid
    qm destroy $vmid --purge 2>/dev/null
done

# Deleting all ISO images
log "Deleting all ISO images..."
for storage in $(pvesm status | awk 'NR>1 {print $1}'); do
    if pvesm list $storage | grep -q iso; then
        for iso in $(pvesm list $storage | grep iso | awk '{print $2}'); do
            log "Deleting ISO $iso from storage $storage..."
            pvesm free $storage:iso/$iso
        done
    fi
done

# Deleting all disk images
log "Deleting all disk images..."
for storage in $(pvesm status | awk 'NR>1 {print $1}'); do
    if pvesm list $storage | grep -q vm; then
        for disk in $(pvesm list $storage | grep vm | awk '{print $2}'); do
            log "Deleting disk $disk from storage $storage..."
            pvesm free $storage:$disk
        done
    fi
done

# Cleaning storage disks
log "Cleaning storage disks..."
for storage in $(pvesm status | awk 'NR>1 {print $1}'); do
    log "Cleaning storage $storage..."
    pvesm prune $storage --keep-all=0
done

# Deleting ISO templates
rm -rf /var/lib/vz/template/iso/*

log "Proxmox node has been reset to a clean state."