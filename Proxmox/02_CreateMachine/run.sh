#!/bin/bash
#===============================================================================
#  __        __   __   __        ___               __                         
# |__)  /\  |  \ /  \ /  ` |__| |__     |     /\  |__)                        
# |__) /~~\ |__/ \__/ \__, |  | |___    |___ /~~\ |__)                        
#                                                                             
#  __        ___                   __   ___       ___  __       ___  __   __  
# |__) \  / |__     \  /  |\/|    / _` |__  |\ | |__  |__)  /\   |  /  \ |__) 
# |     \/  |___     \/   |  |    \__> |___ | \| |___ |  \ /~~\  |  \__/ |  \ 
#
#===============================================================================  
# 
# Script Name   : PVE VM Generator
# Description   : Automate the creation process of PVE VM.
# Author        : Alan Badier
# Date          : 2024-06-11
# Version       : 1.0
#
#===============================================================================

# Function to display the ASCII header
display_header() {
  cat << "EOF"
===============================================================================
 __        __   __   __        ___               __                         
|__)  /\  |  \ /  \ /  ` |__| |__     |     /\  |__)                        
|__) /~~\ |__/ \__/ \__, |  | |___    |___ /~~\ |__)                        
                                                                            
 __        ___                   __   ___       ___  __       ___  __   __  
|__) \  / |__     \  /  |\/|    / _` |__  |\ | |__  |__)  /\   |  /  \ |__) 
|     \/  |___     \/   |  |    \__> |___ | \| |___ |  \ /~~\  |  \__/ |  \ 

===============================================================================  

Script Name   : PVE VM Generator
Description   : Automate the creation process of PVE VM.
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

# Convert previous function to generic one with package function parameter
check_and_install_package() {
  local package_name="$1"

  # Store a Camelcase version of the package name
  local package_name_camelcase=$(echo "$package_name" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')

  if ! command -v "$package_name" &> /dev/null; then
    log "$package_name_camelcase is not installed. Installing now..."
    apt-get update && apt-get install -y "$package_name"
  else
    log "$package_name_camelcase is installed, continue..."
  fi
}

# Network variables
ip_address_start="192.168.0" # The first three octets of the IP address
ip_address_gateway="192.168.0.1" # The gateway IP address
ip_address_cidr="24" # The CIDR notation of the IP address

# Virtual machine variables
vm_template_name="ubuntu-2004-cloudinit" #Please use a cloud-init template
vm_template_id="5001" # The ID of the template
vm_name_prefix="kube" # The prefix of the virtual machine name
vm_user="ubuntu" # The user of the virtual machine
vm_password="ubuntu" # The password of the virtual machine
vm_cloudinit_storage="zfs-datapool" # The storage where the cloud-init configuration will be stored
vm_ssh_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMDZHZExjrQnETA/7lMLyPHWOIEf9Y7qcl4YxOFDYLS4 alan.badier@gmail.com" # The SSH key to access the virtual machines

# Cluster configuration
k8s_version="1.28" # The version of Kubernetes
k8s_master_nodes=3 # Number of master nodes (the main node is always the first one and not included in this number, so if you want 3 master nodes, you should put 2 here)
k8s_worker_nodes=2 # Number of worker nodes (recommended 3 or more for production environments)
k8s_storage_nodes=2 # Number of storage nodes (if you don't want storage nodes, put 0 here)
k8s_pod_network_cidr="10.244.0.0" # The CIDR notation of the pod network
metallb_ip_range="192.168.0.160-192.168.0.180" # The IP range for MetalLB

# Load balancer configuration
load_balancer_cpu=2 # Number of CPUs
load_balancer_socket=1 # Number of sockets
load_balancer_memory=2048 # Memory in MB
load_balancer_disk='30G' # Disk size in GB
load_balancer_ip=200 # IP address of the load balancer (this will be 192.168.1.121/24)

# Master node configuration
master_node_cpu=2 # Number of CPUs
master_vm_id=100 # The ID of the master node
master_node_socket=1 # Number of sockets
master_node_memory=4096 # Memory in MB
master_node_disk='30G' # Disk size in GB
master_node_ip_start=20 # IP address of the first master node (this will be 192.168.1.122/24, the next one will be 192.168.1.123/24, and so on)

# Worker node configuration
worker_node_cpu=4 # Number of CPUs
worker_vm_id=200 # The ID of the worker node
worker_node_socket=1 # Number of sockets
worker_node_memory=8192 # Memory in MB
worker_node_disk='30G' # Disk size in GB
worker_node_ip_start=22 # IP address of the first worker node (this will be 192.168.1.130/24, the next one will be 192.168.1.131/24, and so on)

# Storage node configuration
storage_node_cpu=2 # Number of CPUs
storage_vm_id=300 # The ID of the storage node
storage_node_socket=1 # Number of sockets
storage_node_memory=2048 # Memory in MB
storage_node_disk='200G' # Disk size in GB
storage_node_ip_start=24 # IP address of the first storage node (this will be 192.168.1.140/24, the next one will be 192.168.1.131/24, and so on)

# Create temp file with ssh key content
echo "$vm_ssh_key" > id_rsa.pub

# Create master virtual machines from template specified, only if the number of master nodes is greater than 0 and virtual machines doesn't exist
for ((i = 1; i <= k8s_master_nodes; i++)); do
  vm_name="$vm_name_prefix-master-$i"
  vm_ip_address="$ip_address_start.$master_node_ip_start$i/$ip_address_cidr"
  vm_id=$(($master_vm_id + $i))

  log $vm_id

  # Check if the virtual machine already exists
  if qm status $vm_id &> /dev/null; then
    log "The master node $vm_name already exists. Skipping..."
    continue
  fi

  log "Creating master node $vm_name with IP address $vm_ip_address..."
  qm clone $vm_template_id $vm_id --name $vm_name --full --format qcow2 --storage $vm_cloudinit_storage
  qm set $vm_id --ipconfig0 gw=$ip_address_gateway,ip=$vm_ip_address
  qm set $vm_id --sshkeys /root/.ssh/id_rsa.pub
  qm set $vm_id --sshkeys id_rsa.pub
  qm set $vm_id --nameserver $ip_address_gateway
  qm set $vm_id --onboot 1
  qm set $vm_id --agent 1
  qm set $vm_id --balloon 0
  qm set $vm_id --cores $master_node_cpu
  qm set $vm_id --sockets $master_node_socket
  qm set $vm_id --memory $master_node_memory
  qm set $vm_id --scsihw virtio-scsi-pci --scsi0 $vm_cloudinit_storage:vm-$vm_id-disk-0
  qm disk resize $vm_id scsi0 $master_node_disk
  qm set $vm_id --boot c --bootdisk scsi0
  qm set $vm_id --serial0 socket --vga serial0
  qm set $vm_id --ciuser $vm_user --cipassword $vm_password --ciupgrade 1
  qm start $vm_id
done

# Create worker virtual machines from template specified, only if the number of worker nodes is greater than 0 and virtual machines doesn't exist
for ((i = 1; i <= k8s_worker_nodes; i++)); do
  vm_name="$vm_name_prefix-worker-$i"
  vm_ip_address="$ip_address_start.$worker_node_ip_start$i/$ip_address_cidr"
  vm_id=$(($worker_vm_id + $i))

  log $vm_id

  # Check if the virtual machine already exists
  if qm status $vm_id &> /dev/null; then
    log "The worker node $vm_name already exists. Skipping..."
    continue
  fi

  log "Creating worker node $vm_name with IP address $vm_ip_address..."
  qm clone $vm_template_id $vm_id --name $vm_name --full --format qcow2 --storage $vm_cloudinit_storage
  qm set $vm_id --ipconfig0 gw=$ip_address_gateway,ip=$vm_ip_address
  qm set $vm_id --sshkeys /root/.ssh/id_rsa.pub
  qm set $vm_id --sshkeys id_rsa.pub
  qm set $vm_id --nameserver $ip_address_gateway
  qm set $vm_id --onboot 1
  qm set $vm_id --agent 1
  qm set $vm_id --balloon 0
  qm set $vm_id --cores $worker_node_cpu
  qm set $vm_id --sockets $worker_node_socket
  qm set $vm_id --memory $worker_node_memory
  qm set $vm_id --scsihw virtio-scsi-pci --scsi0 $vm_cloudinit_storage:vm-$vm_id-disk-0
  qm disk resize $vm_id scsi0 $worker_node_disk
  qm set $vm_id --boot c --bootdisk scsi0
  qm set $vm_id --serial0 socket --vga serial0
  qm set $vm_id --ciuser $vm_user --cipassword $vm_password --ciupgrade 1
  qm start $vm_id
done