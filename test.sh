#!/bin/bash
# OSINT_SAFE_SETUP.sh
# Configurazione OSINT migliorata per anonimato e sicurezza
#
# Questo script esegue le seguenti operazioni:
# 1. Scarica wallpapers in /home/kali/wallpapers.
# 2. Aggiorna e installa pacchetti essenziali (inclusi tor, proxychains, iptables-persistent e tool OSINT).
# 3. Configura Tor per usare DNSPort (9053) e TransPort (9040).
# 4. Configura Proxychains per usare socks5 su Tor.
# 5. Imposta iptables per forzare tutto il traffico (DNS, HTTP e HTTPS) attraverso Tor.
# 6. Configura il resolver DNS per utilizzare 127.0.0.1.
# 7. Installa e isola Recon-ng in un ambiente virtuale.
# 8. Installa Holehe tramite pipx e Sherlock tramite apt (entrambi con proxychains).
# 9. Installa xwinwrap e configura il wallpaper dinamico.
# 10. Crea uno script per cambiare il wallpaper e aggiunge l’alias "cw2".
#
# Esegui questo script come root (es. sudo ./OSINT_SAFE_SETUP.sh)

set -e  # Interrompe lo script in caso di errore

###############################################################################
# 1. Verifica se eseguito come root
###############################################################################
if [ "$EUID" -ne 0 ]; then
  echo "Per favore esegui questo script come root (es. sudo ./OSINT_SAFE_SETUP.sh)."
  exit 1
fi

###############################################################################
# 2. Creazione directory wallpapers e download dei wallpapers
###############################################################################
echo "[*] Creazione della directory /home/kali/wallpapers e download dei wallpapers..."
mkdir -p /home/kali/wallpapers
for i in {1..7}; do
  echo "[*] Scaricamento di wallpaper_n${i}.gif..."
  wget -O /home/kali/wallpapers/wallpaper_n${i}.gif \
    "https://github.com/JustSouichi/WiredOS/releases/download/v0.1/wallpaper_n${i}.gif"
done

###############################################################################
# 3. Aggiornamento e installazione dei pacchetti essenziali
###############################################################################
echo "[*] Aggiornamento dei repository e installazione dei pacchetti necessari..."
apt-get update
apt-get install -y tor proxychains git python3-pip python3-venv theharvester dmitry iptables-persistent \
                   build-essential xorg-dev libx11-dev x11proto-xext-dev libxrender-dev libxext-dev mpv

###############################################################################
# 4. Configurazione di Tor per forzare DNS e traffico tramite TransPort
###############################################################################
echo "[*] Configurazione di Tor..."
# Aggiunge DNSPort e TransPort in /etc/tor/torrc se non già presenti
if ! grep -q "^DNSPort 9053" /etc/tor/torrc; then
  echo "DNSPort 9053" >> /etc/tor/torrc
fi
if ! grep -q "^TransPort 9040" /etc/tor/torrc; then
  echo "TransPort 9040" >> /etc/tor/torrc
fi
echo "[*] Riavvio del servizio Tor..."
service tor restart

###############################################################################
# 5. Configurazione di Proxychains
###############################################################################
echo "[*] Configurazione di Proxychains..."
PROXYCHAINS_CONF="/etc/proxychains.conf"
cp "$PROXYCHAINS_CONF" "${PROXYCHAINS_CONF}.bak"
sed -i 's/^socks4.*/socks5\t127.0.0.1\t9050/' "$PROXYCHAINS_CONF"
# Se preferisci usare la modalità dynamic_chain, decommenta le seguenti righe:
# sed -i 's/^strict_chain/#strict_chain/' "$PROXYCHAINS_CONF"
# sed -i 's/^#dynamic_chain/dynamic_chain/' "$PROXYCHAINS_CONF"

###############################################################################
# 6. Impostazione del firewall (iptables) per forzare il traffico attraverso Tor
###############################################################################
echo "[*] Configurazione di iptables per forzare il traffico attraverso Tor..."
# Attenzione: la seguente configurazione potrebbe interrompere le connessioni esistenti.
iptables -F
iptables -t nat -F

# Reindirizza le richieste DNS (UDP 53) a Tor DNSPort (9053)
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 9053

# Reindirizza traffico HTTP (porta 80) e HTTPS (porta 443) a Tor TransPort (9040)
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 9040
iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-ports 9040

# Salva le regole in modo persistente
netfilter-persistent save

###############################################################################
# 7. Configurazione del resolver DNS per prevenire perdite DNS
###############################################################################
echo "[*] Configurazione del resolver DNS per utilizzare 127.0.0.1..."
echo "nameserver 127.0.0.1" > /etc/resolv.conf
# Nota: se usi NetworkManager, potresti dover rendere permanente questa configurazione.

###############################################################################
# 8. Installazione di Recon-ng in /opt/recon-ng con ambiente virtuale isolato
###############################################################################
echo "[*] Installazione di Recon-ng..."
if [ ! -d "/opt/recon-ng" ]; then
  proxychains git clone https://github.com/lanmaster53/recon-ng.git /opt/recon-ng
fi

cd /opt/recon-ng || exit
if [ ! -d ".venv" ]; then
  echo "    -> Creazione dell'ambiente virtuale in /opt/recon-ng/.venv"
  python3 -m venv .venv
fi
source .venv/bin/activate
if [ -f "REQUIREMENTS" ]; then
  echo "    -> Installazione delle dipendenze da REQUIREMENTS"
  proxychains pip install -r REQUIREMENTS
fi
deactivate
cd - >/dev/null || exit

###############################################################################
# 9. Installazione di Holehe tramite pipx e Sherlock tramite apt (con proxychains)
###############################################################################
echo "[*] Installazione di Holehe tramite pipx..."
proxychains pipx install holehe

# Aggiunge automaticamente la directory di pipx al PATH
echo "[*] Eseguo pipx ensurepath per aggiungere /root/.local/bin al PATH (se necessario)..."
proxychains pipx ensurepath

echo "[*] Installazione di Sherlock tramite apt..."
proxychains apt-get install -y sherlock

###############################################################################
# 10. Installazione di xwinwrap per wallpaper dinamici
###############################################################################
echo "[*] Installazione delle dipendenze per xwinwrap..."
echo "[*] Clonazione e compilazione di xwinwrap..."
cd /home/kali
git clone https://github.com/mmhobi7/xwinwrap.git
cd xwinwrap
make
make install
make clean
cd ~
echo "✅ xwinwrap installato correttamente!"

# Imposta il wallpaper di default con xwinwrap e mpv (usa wallpaper_n1.gif)
echo "[*] Impostazione del wallpaper di default (wallpaper_n1.gif)..."
DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  /home/kali/wallpapers/wallpaper_n1.gif &

###############################################################################
# 11. Creazione dello script per cambiare il wallpaper e alias associato
###############################################################################
echo "[*] Creazione dello script per cambiare il wallpaper /usr/local/bin/change_wallpaper2.sh..."
cat << 'EOF' > /usr/local/bin/change_wallpaper2.sh
#!/bin/bash
# Script per cambiare il wallpaper utilizzando xwinwrap.
# Uso: change_wallpaper2.sh [1-7]

WALLPAPER_DIR="/home/kali/wallpapers"

if ! command -v xwinwrap &> /dev/null; then
    echo "Errore: xwinwrap non è installato o non è nel PATH."
    exit 1
fi
if ! command -v mpv &> /dev/null; then
    echo "Errore: mpv non è installato o non è nel PATH."
    exit 1
fi
if [ -z "$DISPLAY" ]; then
    echo "Errore: la variabile DISPLAY non è impostata. Assicurati di essere in una sessione X."
    exit 1
fi
if [ -z "$1" ]; then
    echo "Uso: change_wallpaper2.sh [1-7]"
    exit 1
fi

WP_NUM="$1"
if [[ "$WP_NUM" -lt 1 || "$WP_NUM" -gt 7 ]]; then
    echo "Errore: scegli un numero tra 1 e 7."
    exit 1
fi

WALLPAPER_FILE="$WALLPAPER_DIR/wallpaper_n${WP_NUM}.gif"
if [ ! -f "$WALLPAPER_FILE" ]; then
    echo "Errore: il file $WALLPAPER_FILE non esiste."
    exit 1
fi

echo "Cambio del wallpaper in wallpaper_n${WP_NUM}.gif..."
pkill xwinwrap || true
pkill mpv || true

DISPLAY=:0 xwinwrap -fs -fdt -ni -b -nf -- mpv -wid WID --loop --no-audio --vo=x11 \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:-1:-1:color=black" \
  "$WALLPAPER_FILE" &
echo "Wallpaper cambiato in wallpaper_n${WP_NUM}.gif"
EOF

chmod +x /usr/local/bin/change_wallpaper2.sh

BASHRC="/home/kali/.bashrc"
ALIAS_LINE="alias cw2='sudo /usr/local/bin/change_wallpaper2.sh'"
if ! grep -Fxq "$ALIAS_LINE" "$BASHRC"; then
  echo "[*] Aggiunta dell'alias cw2 a $BASHRC..."
  echo "$ALIAS_LINE" >> "$BASHRC"
else
  echo "[*] Alias cw2 già presente in $BASHRC."
fi

###############################################################################
# 12. Pulizia finale
###############################################################################
echo "[*] Pulizia dei pacchetti inutilizzati..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

echo "====================================================="
echo "Configurazione OSINT migliorata completata!"
echo "Strumenti installati:"
echo "  - OSINT: theHarvester, Dmitry, Sherlock, Recon-ng (in /opt/recon-ng con venv), Holehe (pipx)"
echo "  - Ambiente anonimo: traffico forzato tramite Tor con iptables e Proxychains, DNS configurato su 127.0.0.1"
echo "  - Wallpaper dinamici con xwinwrap e mpv (default: wallpaper_n1.gif)"
echo ""
echo "IMPORTANTE: pipx ha aggiunto /root/.local/bin al tuo PATH (se non era già presente)."
echo "            Riapri la sessione o esegui 'source /root/.bashrc' per rendere effettive le modifiche."
echo ""
echo "Per cambiare il wallpaper, usa:"
echo "  sudo /usr/local/bin/change_wallpaper2.sh [numero da 1 a 7]"
echo "Oppure, apri una nuova shell per usare l'alias 'cw2'"
echo "====================================================="
