#!/bin/bash
set -euo pipefail

# These variables will be passed by Jenkins
ACCOUNT_NAME="${AZ_ACCOUNT_NAME}"
ACCOUNT_KEY="${AZ_ACCOUNT_KEY}"
CONTAINER_NAME="${AZ_CONTAINER_NAME}"

update_timezone() {
    echo "=== Update Time Zone to Asia/Kolkata ==="
    sudo timedatectl set-timezone "Asia/Kolkata"
}

update_system() {
    echo "=== Updating system ==="
    sudo apt-get update && sudo apt-get upgrade -y
}

install_packages() {
    echo "=== Installing necessary packages ==="
    sudo apt-get install -y ffmpeg wget sysstat net-tools htop python3-pip libfuse3-dev fuse3 blobfuse2
}

install_blobfuse() {
    echo "=== Installing Blobfuse ==="
    wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm -f packages-microsoft-prod.deb
    sudo apt-get update && sudo apt-get install -y blobfuse2

    mkdir -p ~/blobdrive
    mkdir -p ~/blobfuse2tmp
    
    # Create config.yaml using variables
    cat <<EOF > config.yaml
allow-other: true
logging:
  type: syslog
  level: log_debug
components:
  - libfuse
  - file_cache
  - attr_cache
  - azstorage
libfuse:
  attribute-expiration-sec: 120
file_cache:
  path: /home/$USER/blobfuse2tmp
  timeout-sec: 120
azstorage:
  type: block
  account-name: $ACCOUNT_NAME
  account-key: $ACCOUNT_KEY
  endpoint: https://$ACCOUNT_NAME.blob.core.windows.net/
  mode: key
  container: $CONTAINER_NAME
EOF

    sudo sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf || true
    # Avoid duplicate fstab entries
    if ! grep -q "blobdrive" /etc/fstab; then
        echo "blobfuse2 /home/$USER/blobdrive fuse defaults,_netdev,--config-file=$(pwd)/config.yaml,allow_other 0 0" | sudo tee -a /etc/fstab
    fi
    sudo blobfuse2 mount ~/blobdrive --config-file=./config.yaml
}

setup_nms() {
    echo "=== Setting up NodeMediaServer ==="
    wget -q -O nms9.tar.gz http://pro.ambicam.com:8080/nms9.tar.gz
    tar -xf nms9.tar.gz && rm -f nms9.tar.gz
    cd nms-linux-amd64 || exit
    mkdir -p html
    ln -sf ~/blobdrive/live-record ./html/live-record
    
    # Simple configuration updates
    sed -i 's/record_filetype = mp4/record_filetype = flv/' config.ini
    sudo bash service.sh install
}

update_timezone
update_system
install_packages
install_blobfuse
setup_nms
