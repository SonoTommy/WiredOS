#!/bin/bash
# OSINT Setup Script for Kali Live
# - Installs various OSINT tools (without requiring API keys)
# - Configures Proxychains to use Tor with Firefox ESR
# - Downloads all tools via Proxychains to help avoid fingerprinting

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (using sudo)."
  exit 1
fi

echo "Updating the system..."
proxychains apt update && proxychains apt upgrade -y

echo "Installing Tor, Proxychains, Firefox ESR, Git, and Python3-Pip..."
proxychains apt install -y tor proxychains firefox-esr git python3-pip

echo "Starting Tor..."
service tor start

echo "Backing up and configuring Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
cp $PROXYCHAINS_CONF ${PROXYCHAINS_CONF}.bak

# Configure Proxychains to use Tor (socks5 on 127.0.0.1:9050)
sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' $PROXYCHAINS_CONF

echo "Installing OSINT tools with Proxychains..."

# theHarvester (available in Kali repositories)
proxychains apt install -y theharvester

# Recon-ng
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
  cd /opt/recon-ng || exit
  proxychains pip3 install -r REQUIREMENTS
  cd -
fi

# Sherlock
if [ ! -d "/opt/sherlock" ]; then
  proxychains git clone https://github.com/sherlock-project/sherlock.git /opt/sherlock
fi

# Holehe
if [ ! -d "/opt/holehe" ]; then
  proxychains git clone https://github.com/megadose/holehe.git /opt/holehe
  cd /opt/holehe || exit
  proxychains pip3 install -r requirements.txt
  cd -
fi

# Amass (an OSINT tool for mapping and discovery)
proxychains apt install -y amass

# Sublist3r (subdomain enumeration tool)
if [ ! -d "/opt/Sublist3r" ]; then
  proxychains git clone https://github.com/aboul3la/Sublist3r.git /opt/Sublist3r
  cd /opt/Sublist3r || exit
  proxychains pip3 install -r requirements.txt
  cd -
fi

# Dmitry (Deepmagic Information Gathering Tool)
proxychains apt install -y dmitry

echo "Installation completed."

echo ""
echo "=== Additional Configurations ==="
echo "1. To run Firefox via Tor, use the following command:"
echo "      proxychains firefox-esr"
echo ""
echo "2. To further reduce fingerprinting in Firefox:"
echo "   - Open about:config and set 'privacy.resistFingerprinting' to 'true'."
echo "   - Consider installing privacy add-ons such as CanvasBlocker."
echo ""
echo "3. You can add more OSINT tools later as needed."
echo ""
echo "Script completed."
