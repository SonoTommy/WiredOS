#!/bin/bash
# WiredOS - Persistent OSINT Configuration with Animated Background at Reboot
# This version sets up the OSINT environment and ensures the animated background
# runs automatically on reboot via both an autostart entry and a systemd user service.
# NOTE: Run this script as root (e.g., sudo ./OSINT_SAFE_SETUP_PERSISTENT.sh)

set -e  # Exit immediately if a command exits with a non-zero status

###############################################################################
# 1. Check if running as root
###############################################################################
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g., sudo ./OSINT_SAFE_SETUP_PERSISTENT.sh)."
  exit 1
fi

###############################################################################
# 2. Create wallpapers directory and download wallpapers
###############################################################################
echo "[*] Creating directory /home/kali/wallpapers and downloading wallpapers..."
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
# 4. Configure Tor (set DNSPort and TransPort)
###############################################################################
echo "[*] Configuring Tor..."
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
# If you prefer dynamic_chain mode, uncomment the following lines:
# sed -i 's/^strict_chain/#strict_chain/' "$PROXYCHAINS_CONF"
# sed -i 's/^#dynamic_chain/dynamic_chain/' "$PROXYCHAINS_CONF"

###############################################################################
# 6. Set up iptables to force traffic through Tor
###############################################################################
echo "[*] Configuring iptables..."
iptables -F
iptables -t nat -F
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 9053
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 9040
iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-ports 9040
netfilter-persistent save

###############################################################################
# 7. Configure DNS resolver to prevent DNS leaks
###############################################################################
echo "[*] Configuring DNS resolver to use 127.0.0.1..."
echo "nameserver 127.0.0.1" > /etc/resolv.conf
# Note: Depending on your network manager, you may need to make this configuration permanent.

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

echo "[*] Ensuring pipx's bin directory is in PATH..."
proxychains pipx ensurepath

echo "[*] Installing Sherlock via apt..."
proxychains apt-get install -y sherlock

###############################################################################
# 10. Install xwinwrap for dynamic wallpapers
###############################################################################
echo "[*] Installing xwinwrap..."
cd /home/kali
git clone https://github.com/mmhobi7/xwinwrap.git
cd xwinwrap
make
make install
make clean
cd ~
echo "✅ xwinwrap installed successfully!"

# Set the default wallpaper using xwinwrap and mpv (wallpaper_n1.gif)
echo "[*] Setting default wallpaper (wallpaper_n1.gif)..."
DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  /home/kali/wallpapers/wallpaper_n1.gif &

###############################################################################
# 11. Create the wallpaper change script and alias "cw2"
###############################################################################
echo "[*] Creating script /usr/local/bin/change_wallpaper2.sh..."
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
    echo "Error: DISPLAY variable is not set. Ensure you are in an X session."
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
# 12. Create autostart entry for the dynamic wallpaper
###############################################################################
echo "[*] Creating autostart file for the dynamic wallpaper..."
AUTOSTART_DIR="/home/kali/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat << 'EOF' > "$AUTOSTART_DIR/dynamic-wallpaper.desktop"
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/change_wallpaper2.sh 1
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Dynamic Wallpaper
Comment=Sets the dynamic wallpaper using xwinwrap and mpv
EOF

###############################################################################
# 13. Create systemd user service for the animated background
###############################################################################
echo "[*] Creating systemd user service for the dynamic wallpaper..."
SYSTEMD_USER_DIR="/home/kali/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

cat << 'EOF' > "$SYSTEMD_USER_DIR/dynamic-wallpaper.service"
[Unit]
Description=Dynamic Wallpaper Service
After=graphical.target

[Service]
Type=simple
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/change_wallpaper2.sh 1
Restart=on-failure

[Install]
WantedBy=default.target
EOF

# Reload and enable the systemd user service (run as user kali)
su - kali -c "systemctl --user daemon-reload && systemctl --user enable dynamic-wallpaper.service && systemctl --user start dynamic-wallpaper.service"

###############################################################################
# 14. Final cleanup
###############################################################################
echo "[*] Cleaning up unused packages..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

echo "====================================================="
echo "Persistent OSINT configuration with animated background completed!"
echo "Installed tools:"
echo "  - OSINT: theHarvester, Dmitry, Sherlock, Recon-ng (in /opt/recon-ng with venv), Holehe (pipx)"
echo "  - Anonymous environment: traffic forced through Tor (via iptables and Proxychains), DNS set to 127.0.0.1"
echo "  - Dynamic wallpaper: xwinwrap and mpv (default: wallpaper_n1.gif, persistent via autostart and systemd service)"
echo ""
echo "To change the wallpaper manually, use:"
echo "  sudo /usr/local/bin/change_wallpaper2.sh [number from 1 to 7]"
echo "Or open a new shell to use the alias 'cw2'"
echo "====================================================="
