#!/bin/bash
# WiredOS
# Improved OSINT Configuration for Anonymity and Security
#
# This script performs the following operations:
# 1. Downloads wallpapers into /home/kali/wallpapers.
# 2. Updates and installs essential packages (including tor, proxychains, iptables-persistent, and OSINT tools).
# 3. Configures Tor to use DNSPort (9053) and TransPort (9040).
# 4. Configures Proxychains to use socks5 on Tor.
# 5. Sets up iptables to force all traffic (DNS, HTTP, and HTTPS) through Tor.
# 6. Configures the DNS resolver to use 127.0.0.1.
# 7. Installs and isolates Recon-ng in a virtual environment.
# 8. Installs Holehe via pipx and Sherlock via apt (both using proxychains).
# 9. Installs xwinwrap and configures the dynamic wallpaper.
# 10. Creates a script to change the wallpaper and adds the alias "cw2".
#
# Run this script as root (e.g. sudo ./OSINT_SAFE_SETUP.sh)

set -e  # Stops the script on error

###############################################################################
# 1. Check if running as root
###############################################################################
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g. sudo ./OSINT_SAFE_SETUP.sh)."
  exit 1
fi

###############################################################################
# 2. Create wallpapers directory and download the wallpapers
###############################################################################
echo "[*] Creating the directory /home/kali/wallpapers and downloading wallpapers..."
mkdir -p /home/kali/wallpapers
for i in {1..7}; do
  echo "[*] Downloading wallpaper_n${i}.gif..."
  wget -O /home/kali/wallpapers/wallpaper_n${i}.gif \
    "https://github.com/JustSouichi/WiredOS/releases/download/v0.1/wallpaper_n${i}.gif"
done

###############################################################################
# 3. Update repositories and install essential packages
###############################################################################
echo "[*] Updating repositories and installing necessary packages..."
apt-get update
apt-get install -y tor proxychains git python3-pip python3-venv theharvester dmitry iptables-persistent \
                   build-essential xorg-dev libx11-dev x11proto-xext-dev libxrender-dev libxext-dev mpv

###############################################################################
# 4. Configure Tor to force DNS and traffic through TransPort
###############################################################################
echo "[*] Configuring Tor..."
# Add DNSPort and TransPort to /etc/tor/torrc if not already present
if ! grep -q "^DNSPort 9053" /etc/tor/torrc; then
  echo "DNSPort 9053" >> /etc/tor/torrc
fi
if ! grep -q "^TransPort 9040" /etc/tor/torrc; then
  echo "TransPort 9040" >> /etc/tor/torrc
fi
echo "[*] Restarting Tor service..."
service tor restart

###############################################################################
# 5. Configure Proxychains
###############################################################################
echo "[*] Configuring Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak"
sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' "$PROXYCHAINS_CONF"
# If you prefer to use dynamic_chain mode, uncomment the following lines:
# sed -i 's/^strict_chain/#strict_chain/' "$PROXYCHAINS_CONF"
# sed -i 's/^#dynamic_chain/dynamic_chain/' "$PROXYCHAINS_CONF"

###############################################################################
# 6. Set up iptables to force traffic through Tor
###############################################################################
echo "[*] Configuring iptables to force traffic through Tor..."
# Warning: the following configuration might interrupt existing connections.
iptables -F
iptables -t nat -F

# Redirect DNS requests (UDP 53) to Tor DNSPort (9053)
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 9053

# Redirect HTTP (port 80) and HTTPS (port 443) traffic to Tor TransPort (9040)
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 9040
iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-ports 9040

# Save the rules persistently
netfilter-persistent save

###############################################################################
# 7. Configure the DNS resolver to prevent DNS leaks
###############################################################################
echo "[*] Configuring the DNS resolver to use 127.0.0.1..."
echo "nameserver 127.0.0.1" > /etc/resolv.conf
# Note: if you use NetworkManager, you may need to make this configuration permanent.

###############################################################################
# 8. Install Recon-ng in /opt/recon-ng with an isolated virtual environment
###############################################################################
echo "[*] Installing Recon-ng..."
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
fi

cd /opt/recon-ng || exit
if [ ! -d ".venv" ]; then
  echo "    -> Creating virtual environment in /opt/recon-ng/.venv"
  python3 -m venv .venv
fi
source .venv/bin/activate
if [ -f "REQUIREMENTS" ]; then
  echo "    -> Installing dependencies from REQUIREMENTS"
  proxychains pip install -r REQUIREMENTS
fi
deactivate
cd - >/dev/null || exit

###############################################################################
# 9. Install Holehe via pipx and Sherlock via apt (with proxychains)
###############################################################################
echo "[*] Installing Holehe via pipx..."
proxychains pipx install holehe

# Automatically add pipx's directory to PATH
echo "[*] Running pipx ensurepath to add /root/.local/bin to PATH (if needed)..."
proxychains pipx ensurepath

echo "[*] Installing Sherlock via apt..."
proxychains apt-get install -y sherlock

###############################################################################
# 10. Install xwinwrap for dynamic wallpapers
###############################################################################
echo "[*] Installing dependencies for xwinwrap..."
echo "[*] Cloning and compiling xwinwrap..."
cd /home/kali
git clone https://github.com/mmhobi7/xwinwrap.git
cd xwinwrap
make
make install
make clean
cd ~
echo "✅ xwinwrap installed correctly!"

# Set the default wallpaper with xwinwrap and mpv (using wallpaper_n1.gif)
echo "[*] Setting the default wallpaper (wallpaper_n1.gif)..."
DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  /home/kali/wallpapers/wallpaper_n1.gif &

###############################################################################
# 11. Create the wallpaper change script and associated alias
###############################################################################
echo "[*] Creating the wallpaper change script /usr/local/bin/change_wallpaper2.sh..."
cat << 'EOF' > /usr/local/bin/change_wallpaper2.sh
#!/bin/bash
# Script to change the wallpaper using xwinwrap.
# Usage: change_wallpaper2.sh [1-7]

WALLPAPER_DIR="/home/kali/wallpapers"

if ! command -v xwinwrap &> /dev/null; then
    echo "Error: xwinwrap is not installed or not in PATH."
    exit 1
fi
if ! command -v mpv &> /dev/null; then
    echo "Error: mpv is not installed or not in PATH."
    exit 1
fi
if [ -z "$DISPLAY" ]; then
    echo "Error: DISPLAY variable is not set. Make sure you are in an X session."
    exit 1
fi
if [ -z "$1" ]; then
    echo "Usage: change_wallpaper2.sh [1-7]"
    exit 1
fi

WP_NUM="$1"
if [[ "$WP_NUM" -lt 1 || "$WP_NUM" -gt 7 ]]; then
    echo "Error: choose a number between 1 and 7."
    exit 1
fi

WALLPAPER_FILE="$WALLPAPER_DIR/wallpaper_n${WP_NUM}.gif"
if [ ! -f "$WALLPAPER_FILE" ]; then
    echo "Error: the file $WALLPAPER_FILE does not exist."
    exit 1
fi

echo "Changing wallpaper to wallpaper_n${WP_NUM}.gif..."
pkill xwinwrap || true
pkill mpv || true

DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  "$WALLPAPER_FILE" &
echo "Wallpaper changed to wallpaper_n${WP_NUM}.gif"
EOF

chmod +x /usr/local/bin/change_wallpaper2.sh

BASHRC="/home/kali/.bashrc"
ALIAS_LINE="alias cw2='sudo /usr/local/bin/change_wallpaper2.sh'"
if ! grep -Fxq "$ALIAS_LINE" "$BASHRC"; then
  echo "[*] Adding alias cw2 to $BASHRC..."
  echo "$ALIAS_LINE" >> "$BASHRC"
else
  echo "[*] Alias cw2 already present in $BASHRC."
fi

###############################################################################
# 12. Final cleanup
###############################################################################
echo "[*] Cleaning up unused packages..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

echo "====================================================="
echo "Improved OSINT configuration completed!"
echo "Installed tools:"
echo "  - OSINT: theHarvester, Dmitry, Sherlock, Recon-ng (in /opt/recon-ng with venv), Holehe (pipx)"
echo "  - Anonymous environment: traffic forced through Tor with iptables and Proxychains, DNS set to 127.0.0.1"
echo "  - Dynamic wallpapers with xwinwrap and mpv (default: wallpaper_n1.gif)"
echo ""
echo "IMPORTANT: pipx has added /root/.local/bin to your PATH (if it wasn't already present)."
echo "           Reopen your session or run 'source /root/.bashrc' to apply the changes."
echo ""
echo "To change the wallpaper, use:"
echo "  sudo /usr/local/bin/change_wallpaper2.sh [number from 1 to 7]"
echo "Or, open a new shell to use the alias 'cw2'"
echo "Install manually holehe with proxychains pipx install hole"
echo "====================================================="
