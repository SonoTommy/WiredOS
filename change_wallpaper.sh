#!/bin/bash
# Minimal OSINT Setup + Xwinwrap Installer + Wallpaper Setter for Kali
#
# Note:
#  - Ora vengono scaricati tutti i wallpaper_nx.gif dove x da 1 a 7, con default n1.
#  - Viene creato uno script in /usr/local/bin/change_wallpaper.sh e un alias "cw"
#    per cambiare il background di xwinwrap.
#
# Run this script as root (sudo).
# Make sure you're logged into an X session if you want the wallpaper to appear immediately.

set -e  # Exit on error

###############################################################################
# 1. Check if running as root
###############################################################################
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (e.g., sudo ./osint_xwinwrap_setup.sh)."
  exit 1
fi

###############################################################################
# 2. Create wallpapers directory & download wallpapers (n1 to n7)
###############################################################################
echo "[*] Creating /home/kali/wallpapers directory..."
mkdir -p /home/kali/wallpapers

for i in {1..7}; do
  echo "[*] Downloading wallpaper_n${i}.gif..."
  wget -O /home/kali/wallpapers/wallpaper_n${i}.gif \
    "https://github.com/JustSouichi/WiredOS/releases/download/v0.1/wallpaper_n${i}.gif"
done

###############################################################################
# 3. Update and install essential OSINT packages
###############################################################################
echo "[*] Updating package lists..."
apt-get update

echo "[*] Installing essential OSINT packages..."
apt-get install -y tor proxychains firefox-esr git python3-pip python3-venv theharvester dmitry

echo "[*] Starting Tor service..."
service tor start

###############################################################################
# 4. Install pipx and Holehe via pipx
###############################################################################
echo "[*] Installing Holehe with pipx (via Proxychains)..."
proxychains pipx install holehe

###############################################################################
# 5. Configure Proxychains
###############################################################################
echo "[*] Backing up and configuring Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak"
sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' "$PROXYCHAINS_CONF"
# Uncomment these lines if you prefer 'dynamic_chain' instead of 'strict_chain'
# sed -i 's/^strict_chain/#strict_chain/' "$PROXYCHAINS_CONF"
# sed -i 's/^#dynamic_chain/dynamic_chain/' "$PROXYCHAINS_CONF"

###############################################################################
# 6. Helper function to create a venv and install requirements
###############################################################################
create_venv_and_install() {
  local repo_dir="$1"
  local requirements_file="$2"
  
  cd "$repo_dir" || exit
  if [ ! -d ".venv" ]; then
    echo "    -> Creating virtual environment in $repo_dir/.venv"
    python3 -m venv .venv
  fi
  source .venv/bin/activate
  if [ -f "$requirements_file" ]; then
    echo "    -> Installing dependencies from $requirements_file"
    proxychains pip install -r "$requirements_file"
  fi
  deactivate
  cd - >/dev/null || exit
}

###############################################################################
# 7. Install Recon-ng from GitHub (with local venv)
###############################################################################
echo "[*] Installing recon-ng..."
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
else
  echo "    -> /opt/recon-ng already exists, skipping clone."
  create_venv_and_install "/opt/recon-ng" "REQUIREMENTS"
fi

###############################################################################
# 8. Install Sherlock via apt
###############################################################################
echo "[*] Installing Sherlock via apt (with Proxychains)..."
proxychains apt-get install -y sherlock

###############################################################################
# 9. Clean up OSINT environment
###############################################################################
echo "[*] Cleaning up unused packages..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

echo ""
echo "[*] Minimal OSINT environment installed!"
echo "[*] Tools installed system-wide: theHarvester, Dmitry, Sherlock"
echo "[*] Tools installed via pipx: Holehe (check 'pipx list')"
echo "[*] Recon-ng cloned in /opt/recon-ng with a local Python venv (.venv)."
echo ""

###############################################################################
# 10. Xwinwrap Installation
###############################################################################
echo "[*] Installing xwinwrap dependencies..."
apt-get update
apt-get install -y xorg-dev build-essential libx11-dev x11proto-xext-dev libxrender-dev libxext-dev mpv

echo "[*] Cloning xwinwrap repository into /home/kali..."
cd /home/kali
git clone https://github.com/mmhobi7/xwinwrap.git

echo "[*] Compiling and installing xwinwrap..."
cd xwinwrap
make
sudo make install

echo "[*] Cleaning up xwinwrap build files..."
make clean

cd ~
echo "✅ Xwinwrap installation completed!"

###############################################################################
# 11. Set the default wallpaper using xwinwrap + mpv (using wallpaper_n1.gif)
###############################################################################
echo "[*] Setting the default wallpaper with xwinwrap (wallpaper_n1.gif)..."
DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf="scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  /home/kali/wallpapers/wallpaper_n1.gif &

###############################################################################
# 12. Create the wallpaper changer script and alias
###############################################################################
echo "[*] Creating wallpaper changer script /usr/local/bin/change_wallpaper.sh..."

cat << 'EOF' > /usr/local/bin/change_wallpaper.sh
#!/bin/bash
# Script per cambiare il wallpaper di xwinwrap.
# Uso: change_wallpaper.sh [1-7]
WALLPAPER_DIR="/home/kali/wallpapers"

if [ -z "$1" ]; then
  echo "Usage: change_wallpaper.sh [1-7]"
  exit 1
fi

WP_NUM="$1"
if [[ "$WP_NUM" -lt 1 || "$WP_NUM" -gt 7 ]]; then
  echo "Errore: Scegli un numero tra 1 e 7."
  exit 1
fi

WALLPAPER_FILE="$WALLPAPER_DIR/wallpaper_n${WP_NUM}.gif"

if [ ! -f "$WALLPAPER_FILE" ]; then
  echo "Errore: Il file $WALLPAPER_FILE non esiste."
  exit 1
fi

echo "Cambiando il wallpaper in wallpaper_n${WP_NUM}.gif..."

# Termina eventuali istanze di xwinwrap in esecuzione
pkill xwinwrap || true

# Avvia xwinwrap con il nuovo wallpaper
DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf="scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  "$WALLPAPER_FILE" &

echo "Wallpaper cambiato in wallpaper_n${WP_NUM}.gif"
EOF

chmod +x /usr/local/bin/change_wallpaper.sh

echo "[*] Aggiungo l'alias 'cw' al file .bashrc di root..."
if ! grep -q "alias cw=" /root/.bashrc; then
  echo "alias cw='/usr/local/bin/change_wallpaper.sh'" >> /root/.bashrc
fi

echo "====================================================="
echo "Tutte le operazioni sono state completate."
echo "Di default viene usato wallpaper_n1.gif."
echo "Per cambiare il wallpaper, apri una nuova shell (o esegui 'source /root/.bashrc') e usa:"
echo "   cw [numero da 1 a 7]"
echo "Ad esempio:"
echo "   cw 3"
echo "Cambia il background di xwinwrap al wallpaper scelto."
echo "====================================================="
