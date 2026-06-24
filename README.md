# FR24 ADS-B Feeder - grandedata.no

A self-hosted ADS-B receiver station that sends flight data to FlightRadar24 via an RTL2832U USB dongle connected to a Debian 13 VM on Proxmox.

---

## How it works

1. **readsb** — Decodes the ADS-B signal from the RTL2832U and exposes it as a Beast stream on port 30005.
2. **fr24feed** — Fetches data from readsb and sends it to FlightRadar24 via UDP.
3. **qemu-guest-agent** — Proxmox integration for IP reporting and proper shutdown.

## Requirements

- Proxmox 8.x with Debian 13 (Trixie) VM — 1 core, 1 GB RAM, 16 GB disk
- RTL2832U USB dongle with R820T tuner (USB passthrough to VM) https://www.aliexpress.com/item/1005005466363998.html?spm=a2g0o.order_list.order_list_main.25.68481802hszz4l
- Antenna https://www.aliexpress.com/item/1005001423944489.html?spm=a2g0o.order_list.order_list_main.30.68481802hszz4l
- FR24 key from flightradar24.com

## Installation

1. Add the RTL2832U as USB passthrough in Proxmox (Use USB Device, not Use USB Port)

2. Install dependencies:

```
sudo apt update && sudo apt upgrade -y
sudo apt install qemu-guest-agent rtl-sdr git -y
sudo systemctl enable --now qemu-guest-agent
sudo udevadm control --reload-rules && sudo udevadm trigger
```

3. Install readsb:

```
git clone https://github.com/wiedehopf/adsb-scripts.git
cd adsb-scripts
sudo bash readsb-install.sh
```

4. Remove old FlightAware repos and install FR24:

```
cd ~
sudo rm -f /etc/apt/sources.list.d/piaware.list
sudo rm -f /etc/apt/trusted.gpg.d/flightaware.gpg
sudo apt update
wget -qO- https://fr24.com/install.sh | sudo bash -s
```

During installation: receiver type `1`, decoder arguments empty, RAW `no`, Basestation `no`, MLAT `yes`.

5. Fill in the key in `fr24feed.ini` and copy it to `/etc/fr24feed.ini`:

```
sudo nano /etc/fr24feed.ini
```

6. Start the services:

```
sudo systemctl enable fr24feed
sudo systemctl restart fr24feed
```

7. Verify:

```
fr24feed-status
```

Expected output: `FR24 Link: connected [UDP]` and `Receiver: connected`.

## Files

| File           | Description                  |
| -------------- | ----------------------------- |
| `fr24feed.ini` | FR24 configuration (no key)   |
| `README.md`    | This file                     |

## Useful commands

Check FR24 feed status:
```
fr24feed-status
```

Restart the ADS-B decoder:
```
sudo systemctl restart readsb
```

Restart the FR24 feed:
```
sudo systemctl restart fr24feed
```

## Important

> ⚠️ The FR24 installer sets up its own dump1090, which does not work on Debian 13. `fr24feed.ini` must always point to readsb at `127.0.0.1:30005` — never skip step 5.

## Security

- `fr24feed.ini` contains the FR24 key — do not push this to a public repo
- Add `fr24feed.ini` to `.gitignore` or remove the key before pushing

## Infrastructure

Runs as a VM on Proxmox with 1 core, 1 GB RAM, and 16 GB disk. The RTL2832U is USB passthrough directly to the VM.

---

*Confirmed working on Proxmox 8.x with Debian 13 (Trixie) and RTL2832U (R820T tuner)*
