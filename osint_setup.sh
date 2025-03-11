#!/bin/bash
# OSINT Setup Script for Kali Live
#
# This script performs the following steps:
# 1. Updates the system.
# 2. Installs the Kali OSINT meta-package along with system tools:
#    - Tor, Proxychains, Firefox ESR, Git, and Python3-Pip.
# 3. Installs additional OSINT tools (recon-ng, Sherlock, Holehe) via Proxychains.
# 4. Configures Proxychains to route traffic through Tor (socks5 on 127.0.0.1:9050).
# 5. Provides instructions to launch Firefox with enhanced privacy settings.
#
# Note: Ensure you run this script as root.

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (using sudo)."
  exit 1
fi

echo "Step 1: Updating the system..."
sudo apt update && sudo apt upgrade -y

echo "Step 2: Installing system tools and OSINT meta-package..."
sudo apt install -y kali-tools-osint tor proxychains firefox-esr git python3-pip

echo "Starting Tor service..."
service tor start

echo "Step 3: Installing additional OSINT tools via Proxychains..."

# Install recon-ng
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
  cd /opt/recon-ng || exit
  proxychains pip3 install -r REQUIREMENTS
  cd -
fi

# Install Sherlock
if [ ! -d "/opt/sherlock" ]; then
  proxychains git clone https://github.com/sherlock-project/sherlock.git /opt/sherlock
fi

# Install Holehe
if [ ! -d "/opt/holehe" ]; then
  proxychains git clone https://github.com/megadose/holehe.git /opt/holehe
  cd /opt/holehe || exit
  proxychains pip3 install -r requirements.txt
  cd -
fi

echo "Step 4: Configuring Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
sudo cp $PROXYCHAINS_CONF ${PROXYCHAINS_CONF}.bak

# Configure Proxychains to use Tor (socks5 on 127.0.0.1:9050)
sudo sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' $PROXYCHAINS_CONF

echo "Step 5: Additional Firefox configurations:"
echo " - To run Firefox through Tor, use:"
echo "       proxychains firefox-esr"
echo " - For further privacy, open about:config in Firefox and set 'privacy.resistFingerprinting' to 'true'."
echo " - You may also install privacy add-ons such as CanvasBlocker."
echo ""
echo "OSINT Setup Script completed."
