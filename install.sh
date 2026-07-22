#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash install.sh"
  exit 1
fi

echo "=============================================="
echo " FR24 ADS-B Feeder - automated install"
echo "=============================================="

read -rp "Enter your FlightRadar24 sharing key: " FR24_KEY
if [[ -z "$FR24_KEY" ]]; then
  echo "A sharing key is required. Get one at https://www.flightradar24.com/share-your-data"
  exit 1
fi

echo "--------------------------------------------"
echo "1/6 Installing dependencies"
echo "--------------------------------------------"
apt update && apt upgrade -y
apt install -y qemu-guest-agent rtl-sdr git curl
systemctl enable --now qemu-guest-agent
udevadm control --reload-rules
udevadm trigger

echo "--------------------------------------------"
echo "2/6 Installing readsb + tar1090"
echo "--------------------------------------------"
cd /root
if [[ ! -d adsb-scripts ]]; then
  git clone https://github.com/wiedehopf/adsb-scripts.git
fi
cd adsb-scripts
bash readsb-install.sh

echo "--------------------------------------------"
echo "3/6 Removing conflicting decoder repos"
echo "--------------------------------------------"
rm -f /etc/apt/sources.list.d/piaware.list
rm -f /etc/apt/trusted.gpg.d/flightaware.gpg
apt update

echo "--------------------------------------------"
echo "4/6 Installing fr24feed"
echo "--------------------------------------------"
echo "The FR24 installer will ask a few setup questions."
echo "Answering automatically with the known-good values"
echo "(receiver type 1, empty decoder args, RAW no, Basestation no, MLAT yes)."
echo "The config file gets overwritten with correct values afterwards regardless."
set +e
printf '1\n\nno\nno\nyes\n' | wget -qO- https://fr24.com/install.sh | bash -s
set -e

echo "--------------------------------------------"
echo "5/6 Writing correct fr24feed.ini"
echo "--------------------------------------------"
# The FR24 installer sets up its own dump1090, which doesn't work on Debian 13.
# Force it to point at readsb on 127.0.0.1:30005 instead, regardless of what
# the interactive wizard above landed on.
cat > /etc/fr24feed.ini <<EOF
receiver="beast-tcp"
fr24key="$FR24_KEY"
host="127.0.0.1:30005"
bs="no"
raw="no"
logmode="1"
logpath="/var/log/fr24feed"
mlat="yes"
mlat-without-gps="yes"
EOF

systemctl enable fr24feed
systemctl restart fr24feed

echo "--------------------------------------------"
echo "6/6 Verifying"
echo "--------------------------------------------"
sleep 5
fr24feed-status || true

echo "Checking tar1090 webinterface..."
if wget -qO- http://127.0.0.1/tar1090/data/aircraft.json > /dev/null 2>&1; then
  echo "tar1090 OK - aircraft.json is being served"
else
  echo "tar1090 did NOT respond, retrying the tar1090 install step..."
  bash /usr/local/share/adsb-wiki/readsb-install/tar1090-install.sh /run/readsb
  systemctl restart lighttpd
fi

IP=$(ip route get 1.1.1.1 | grep -m1 -o -P 'src \K[0-9.]*')
echo "=============================================="
echo " Done."
echo " Webinterface: http://$IP/tar1090"
echo " Run 'fr24feed-status' any time to check feed status."
echo "=============================================="
