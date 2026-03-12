#!/bin/bash
set -euo pipefail

# Variables passed from Jenkins
ACCOUNT_NAME="${AZ_ACCOUNT_NAME}"
ACCOUNT_KEY="${AZ_ACCOUNT_KEY}"
CONTAINER_NAME="${AZ_CONTAINER_NAME}"

BLOB_MOUNT="$HOME/blobdrive"
BLOB_CACHE="$HOME/blobfuse2tmp"

update_timezone() {
    echo "=== Update Time Zone to Asia/Kolkata ==="
    sudo timedatectl set-timezone Asia/Kolkata
}

update_system() {
    echo "=== Updating system ==="
    sudo apt-get update -y
}

install_packages() {
    echo "=== Installing necessary packages ==="
    sudo apt-get install -y \
        ffmpeg \
        wget \
        sysstat \
        net-tools \
        htop \
        python3-pip \
        libfuse3-dev \
        fuse3 \
        git
}

install_blobfuse() {
    echo "=== Installing Blobfuse2 ==="

    # Detect Ubuntu version
    UBUNTU_VERSION=$(lsb_release -rs)

    echo "Ubuntu version detected: $UBUNTU_VERSION"

    wget -q https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm -f packages-microsoft-prod.deb

    sudo apt-get update
    sudo apt-get install -y blobfuse2

    echo "=== Creating mount directories ==="
    mkdir -p "$BLOB_MOUNT"
    mkdir -p "$BLOB_CACHE"

    echo "=== Creating blobfuse2 config ==="

    cat <<EOF > ~/config.yaml
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
  path: $BLOB_CACHE
  timeout-sec: 120

azstorage:
  type: block
  account-name: $ACCOUNT_NAME
  account-key: $ACCOUNT_KEY
  endpoint: https://$ACCOUNT_NAME.blob.core.windows.net/
  mode: key
  container: $CONTAINER_NAME
EOF

    echo "=== Enabling allow_other in fuse ==="
    sudo sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf || true

    echo "=== Updating fstab if not exists ==="
    if ! grep -q "$BLOB_MOUNT" /etc/fstab; then
        echo "blobfuse2 $BLOB_MOUNT fuse defaults,_netdev,--config-file=$HOME/config.yaml,allow_other 0 0" | sudo tee -a /etc/fstab
    fi

    echo "=== Mounting Blob Storage ==="
    sudo blobfuse2 mount "$BLOB_MOUNT" --config-file="$HOME/config.yaml"

    echo "=== Blob Storage Mounted ==="
}

setup_nms() {
    echo "=== Setting up NodeMediaServer ==="

    cd $HOME

    wget -q -O nms9.tar.gz http://pro.ambicam.com:8080/nms9.tar.gz
    tar -xf nms9.tar.gz
    rm -f nms9.tar.gz

    cd nms-linux-amd64

    echo "=== Creating html directory ==="
    mkdir -p html

    echo "=== Linking blob storage ==="
    ln -sf "$BLOB_MOUNT/live-record" ./html/live-record

    echo "=== Updating config ==="
    sed -i 's/record_filetype = mp4/record_filetype = flv/' config.ini

    echo "=== Installing NMS service ==="
    sudo bash service.sh install

    echo "=== NMS installation completed ==="
}

main() {

    echo "===== NMS INSTALLATION STARTED ====="

    update_timezone
    update_system
    install_packages
    install_blobfuse
    setup_nms

    echo "===== INSTALLATION COMPLETED ====="
}

main
