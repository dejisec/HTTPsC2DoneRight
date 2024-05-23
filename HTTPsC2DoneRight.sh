#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verbosity levels
VERBOSITY=1

info() {
    if [ "$VERBOSITY" -ge 1 ]; then
        echo -e "${YELLOW}$1${NC}"
    fi
}

success() {
    if [ "$VERBOSITY" -ge 1 ]; then
        echo -e "${GREEN}$1${NC}"
    fi
}

error() {
    echo -e "${RED}$1${NC}"
}

debug() {
    if [ "$VERBOSITY" -ge 2 ]; then
        echo -e "${NC}$1${NC}"
    fi
}

# Parse arguments
DOMAIN=""
PASSWORD=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN="$2"; shift ;;
        --password) PASSWORD="$2"; shift ;;
        --verbose) VERBOSITY=1 ;;
        --debug) VERBOSITY=2 ;;
        *) error "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

KEYSTORE_PATH="/etc/letsencrypt/live/$DOMAIN"

if [ "$(id -u)" != "0" ]; then
    error "Oops! This script must be run as root."
    exit 1
fi

if [ -z "$DOMAIN" ] || [ -z "$PASSWORD" ]; then
    error "Usage: $0 --domain <domain> --password <password> [--verbose|--debug]"
    exit 1
fi

if ! [[ $DOMAIN =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    error "Invalid domain format: $DOMAIN. Please enter a valid domain."
    exit 1
fi

install_jdk() {
    if ! command -v java > /dev/null || ! command -v keytool > /dev/null; then
        info "JDK not found. Installing default JDK..."
        debug "Running apt update"
        if [ "$VERBOSITY" -ge 2 ]; then
            apt update
        else
            apt update > /dev/null 2>&1
        fi
        debug "Installing default-jdk"
        if [ "$VERBOSITY" -ge 2 ]; then
            apt install default-jdk -y
        else
            apt install default-jdk -y > /dev/null 2>&1
        fi
        success "JDK installed successfully, including keytool."
    else
        success "JDK (and keytool) is already installed."
    fi
}

install_snap() {
    if ! command -v snap > /dev/null; then
        info "Snap not found. Installing snap..."
        debug "Running apt update"
        if [ "$VERBOSITY" -ge 2 ]; then
            apt update
        else
            apt update > /dev/null 2>&1
        fi
        debug "Installing snapd"
        if [ "$VERBOSITY" -ge 2 ]; then
            apt install snapd -y
        else
            apt install snapd -y > /dev/null 2>&1
        fi
        success "Snap installed successfully."
    else
        success "Snap is already installed."
    fi
}

enable_service() {
    local service=$1
    if ! systemctl is-active --quiet "$service"; then
        info "Enabling $service service..."
        debug "Enabling and starting $service"
        if [ "$VERBOSITY" -ge 2 ]; then
            systemctl enable --now "$service"
        else
            systemctl enable --now "$service" > /dev/null 2>&1
        fi
        success "$service service enabled."
    else
        success "$service service is already active."
    fi
}

install_certbot() {
    if command -v certbot > /dev/null; then
        info "Found certbot installed via apt. Removing it..."
        debug "Removing certbot"
        if [ "$VERBOSITY" -ge 2 ]; then
            apt remove certbot -y
        else
            apt remove certbot -y > /dev/null 2>&1
        fi
        success "Certbot removed from apt."
    fi

    if ! snap list 2>/dev/null | grep -q "^certbot "; then
        info "Installing certbot via snap..."
        debug "Installing core snap"
        if [ "$VERBOSITY" -ge 2 ]; then
            snap install core && snap refresh core
        else
            snap install core > /dev/null 2>&1 && snap refresh core > /dev/null 2>&1
        fi
        debug "Installing certbot snap"
        if [ "$VERBOSITY" -ge 2 ]; then
            snap install --classic certbot
        else
            snap install --classic certbot > /dev/null 2>&1
        fi
        ln -sf /snap/bin/certbot /usr/bin/certbot
        success "Certbot installed via snap."
    else
        success "Certbot is already installed via snap."
    fi
}

run_certbot() {
    if [ -d "$KEYSTORE_PATH" ]; then
        error "Certificate files for $DOMAIN already exist. No action needed."
        exit 1
    fi

    info "Running certbot for $DOMAIN..."
    debug "Running certbot certonly command"
    if [ "$VERBOSITY" -ge 2 ]; then
        certbot certonly -d "$DOMAIN" --register-unsafely-without-email --standalone -n --agree-tos
    else
        certbot certonly -d "$DOMAIN" --register-unsafely-without-email --standalone -n --agree-tos > /dev/null 2>&1
    fi
    if [ $? -ne 0 ]; then
        error "Certbot operation failed for $DOMAIN."
        exit 1
    fi
    success "Certbot operation successful for $DOMAIN."
}

generate_keystore() {
    info "Generating keystore for $DOMAIN in $KEYSTORE_PATH..."
    debug "Changing directory to $KEYSTORE_PATH"
    cd "$KEYSTORE_PATH" || exit
    debug "Running openssl pkcs12 export"
    openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem -out "$DOMAIN.p12" -name "$DOMAIN" -passout pass:"$PASSWORD"
    debug "Running keytool importkeystore"
    if [ "$VERBOSITY" -ge 2 ]; then
        keytool -importkeystore -deststorepass "$PASSWORD" -destkeypass "$PASSWORD" -destkeystore "$DOMAIN.store" -srckeystore "$DOMAIN.p12" -srcstoretype PKCS12 -srcstorepass "$PASSWORD" -noprompt
    else
        keytool -importkeystore -deststorepass "$PASSWORD" -destkeypass "$PASSWORD" -destkeystore "$DOMAIN.store" -srckeystore "$DOMAIN.p12" -srcstoretype PKCS12 -srcstorepass "$PASSWORD" -noprompt > /dev/null 2>&1
    fi
    success "Keystore generated successfully."
}

info "Starting the script for setting up your domain's SSL..."
install_jdk
install_snap
enable_service snapd
enable_service apparmor
install_certbot
run_certbot
generate_keystore

info "Here are the details of the files created for your domain:"
echo -e "  - ${GREEN}Keystore: $KEYSTORE_PATH/$DOMAIN.store${NC}"
echo -e "  - ${GREEN}Certificate: $KEYSTORE_PATH/fullchain.pem${NC}"
echo -e "  - ${GREEN}Private Key: $KEYSTORE_PATH/privkey.pem${NC}"

success "All done! Your domain is now set up with SSL."