#!/bin/bash
#===============================================================================
#  __        __   __   __        ___               __  
# |__)  /\  |  \ /  \ /  ` |__| |__     |     /\  |__) 
# |__) /~~\ |__/ \__/ \__, |  | |___    |___ /~~\ |__) 
#  
#  __        ___                  __   ___  __         
# |__) \  / |__     |  |\/|  /\  / _` |__  |__)        
# |     \/  |___    |  |  | /~~\ \__> |___ |  \        
#
#===============================================================================  
# 
# Script Name   : PVE Imager
# Description   : Automate the creation of Proxmox VE images.
# Author        : Alan Badier
# Date          : 2024-06-10
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
 
 __        ___                  __   ___  __         
|__) \  / |__     |  |\/|  /\  / _` |__  |__)        
|     \/  |___    |  |  | /~~\ \__> |___ |  \        

===============================================================================  

Script Name   : PVE Imager
Description   : Automate the creation of Proxmox VE images.
Author        : Alan Badier
Date          : 2024-06-10
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

# Function to display the list of OS choices and get user selection
select_os() {
  local os_selection=$(whiptail --title "Select Operating System" --menu "Choose an OS to install:" 15 50 3 \
    "Ubuntu" "Ubuntu Linux" \
    "Debian" "Debian Linux" \
    "Alpine" "Alpine Linux" 3>&1 1>&2 2>&3)
  check_cancel

  echo "$os_selection"
}

# Function to display the list of Ubuntu versions and get user selection
select_ubuntu_version() {
  local ubuntu_versions=(
    "18.04" "Bionic Beaver"
    "20.04" "Focal Fossa"
    "22.04" "Jammy Jellyfish"
    "24.04" "Future Feline"
  )

  local version_selection=$(whiptail --title "Select Ubuntu Version" --menu "Choose an Ubuntu version to install:" 15 50 4 \
    "${ubuntu_versions[@]}" 3>&1 1>&2 2>&3)
  check_cancel

  echo "$version_selection"
}

# Function to prompt the user for a template name
prompt_template_name() {
  local default_name="$1"
  local template_name=$(whiptail --inputbox "Enter the template name:" 10 60 "$default_name" 3>&1 1>&2 2>&3)
  check_cancel

  echo "$template_name"
}

# Function to handle cancellation
function check_cancel {
    if [ $? -ne 0 ]; then
        log "Script cancelled. Exiting..."
        exit 1
    fi
}

# Call the function to display the header
display_header

# Call the function to check and install whiptail
check_and_install_package "whiptail"

# Call the function to check and install jq
check_and_install_package "jq"

# Call the function to check and install wget
check_and_install_package "wget"

log "Starting the PVE Imager process..."

# Call the function to display the list of OS choices and get the selection
selected_os=$(select_os)

# Log the selected OS
if [ -n "$selected_os" ]; then
  log "User selected OS : $selected_os"
else
  log "User cancelled the selection..."
  exit 1
fi

# If the selected OS is Ubuntu, display the list of Ubuntu versions
if [ "$selected_os" == "Ubuntu" ]; then
  selected_version=$(select_ubuntu_version)

  if [ -n "$selected_version" ]; then
    log "User selected OS version : $selected_version"
  else
    log "User cancelled the Ubuntu version selection..."
    exit 1
  fi
fi

# Convert the OS name to lowercase and format the version
formatted_os=$(echo "$selected_os" | tr '[:upper:]' '[:lower:]')
formatted_version=$(echo "$selected_version" | tr -d '.')

# Initialize the default template name
default_template_name="${formatted_os}-${formatted_version}-cloudinit"

# Prompt the user for a template name
template_name=$(prompt_template_name "$default_template_name")

# Log the template name
if [ -n "$template_name" ]; then
  log "User provided template name: $template_name"
else
  log "User cancelled the template name input."
  exit 1
fi

# Get the next available VM ID
ID=$(pvesh get /cluster/nextid)

# Ask user for the VM ID and prefill with the next available ID
ID=$(whiptail --inputbox "Enter the VM ID:" 10 60 "$ID" 3>&1 1>&2 2>&3)
check_cancel

log "Proceeding with the selected OS: $selected_os $selected_version"

# Get available storage options
mapfile -t storages < <(pvesm status -content rootdir | awk 'NR>1 {print $1, $2, $6/1024/1024 "GB free"}')

# Prepare the storage menu
storage_menu=()
for option in "${storages[@]}"; do
    storage_menu+=("$option" "")
done

# Prompt the user to choose a storage
selected_storage=$(whiptail --title "Choose Storage" --menu "Select the storage for your template:" 15 60 6 "${storage_menu[@]}" 3>&1 1>&2 2>&3)
check_cancel

log "User selected storage: $selected_storage"

# selected_storage is in the format "storage_name storage_type storage_free_space free", so we need to extract the storage_name
IFS=' ' read -r storage_name _ <<< "$selected_storage"

# Log the selected storage name
log "Selected storage name: $storage_name"

# Ask user which network interface to use, prefill with vmbr0
selected_network=$(whiptail --inputbox "Enter the network interface to use:" 10 60 "vmbr0" 3>&1 1>&2 2>&3)
check_cancel

log "User selected network interface: $selected_network"

# Start the image creation process
log "Starting the image creation process, please wait..."

# Ubuntu Images URL
# url="https://cloud-images.ubuntu.com/releases/streams/v1/com.ubuntu.cloud:released:download.json"

# Download json data
# json_data=$(curl -s $url)

# Find current system arch
selected_arch=$(dpkg --print-architecture)

# Utilisation de jq pour trouver la dernière image
# latest_image=$(echo $json_data | jq -r --arg version "$selected_version" --arg arch "$selected_arch" '
#     .products[] |
#     select(.version == $version and .arch == $arch) |
#     .versions | 
#     to_entries | 
#     max_by(.key) | 
#     .value.items."disk1.img".path' )

# Latest image URL
latest_image="https://cloud-images.ubuntu.com/releases/$selected_version/release/ubuntu-$selected_version-server-cloudimg-$selected_arch.img"

if [ -n "$latest_image" ]; then
    # Log the latest image
    log "The latest image for $selected_os $selected_version is: $latest_image"
fi

# Download the latest image and save it to the Proxmox VE ISO directory with only the filename and file extension
image_filename=$(basename "$latest_image")
image_path="/var/lib/vz/template/iso/$image_filename"

# Log the image path
log "Downloading the image to $image_path..."

# Download the image with curl
curl -L -o "$image_path" "$latest_image"

# Update and install necessary packages
log "Updating the OS packages..."
apt-get update -y
check_and_install_package "qemu-utils"
check_and_install_package "libguestfs-tools"
apt autoremove -y

# Customize the image
# Install quemu agent
log "Installing qemu-guest-agent..."
virt-customize -a "$image_path" --install qemu-guest-agent
virt-customize -a "$image_path" --run-command "echo -n > /etc/machine-id"

# Generate random password
password=$(openssl rand -base64 12)

# Create the VM template
qm create $ID --name $template_name --memory 512 --net0 virtio,bridge=$selected_network --cores 1 --sockets 1 --description "CloudInit Image"
qm importdisk $ID "$image_path" $storage_name
qm set $ID --scsihw virtio-scsi-pci --scsi0 $storage_name:vm-$ID-disk-0
qm resize $ID scsi0 +15G
qm set $ID --ide2 $storage_name:cloudinit
qm set $ID --boot c --bootdisk scsi0
qm set $ID --agent enabled=1
qm set $ID --ciuser ubuntu --cipassword $password

log "The template $template_name has been created successfully, with the password: $password"

# Convert the VM to a template
qm template $ID

# Ask user if he wants to create a project folder (yes / no)
if (whiptail --title "Create a project folder?" --yesno "Do you want to create a project folder?" 10 60) then
    # Default project folder name
    project_folder=$(hostname)_templates

    # Ask user for the project folder name
    project_folder_name=$(whiptail --inputbox "Enter the project folder name:" 10 60 "$project_folder" 3>&1 1>&2 2>&3)
    check_cancel

    # Create the project folder
    mkdir -p "../../Projects/$project_folder_name"

    # Log the project folder creation
    log "Project folder $project_folder_name created successfully."

    # Ask user if he wants to store the password in a file (yes / no)
    if (whiptail --title "Store the password in a file?" --yesno "Do you want to store the password in a file?" 10 60) then
        # Store the password in a file
        echo "Password: $password" > "../../Projects/$project_folder_name/$template_name.pwd"

        # Log the password storage
        log "Password stored in the file $template_name.pwd in the project folder $project_folder_name."
    fi
fi