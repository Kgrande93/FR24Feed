# FR24 ADS-B Feeder - grandedata.no

A self-hosted ADS-B receiver station that sends flight data to FlightRadar24 via an RTL2832U USB dongle connected to a Debian 13 VM on Proxmox.

---

## How it works

1. **readsb** — Decodes the ADS-B signal from the RTL2832U and exposes it as a Beast stream on port 30005.
2. **fr24feed** — Fetches data from readsb and sends it to FlightRadar24 via UDP.
3. **tar1090** — Web interface showing live aircraft positions and `aircraft.json`, installed automatically by `readsb-install.sh`.
4. **qemu-guest-agent** — Proxmox integration for IP reporting and proper shutdown.

## Requirements

- Proxmox 8.x with Debian 13 (Trixie) VM — 1 core, 1 GB RAM, 16 GB disk
- RTL2832U USB dongle with R820T tuner (USB passthrough to VM) <https://www.aliexpress.com/item/1005005466363998.html?spm=a2g0o.order_list.order_list_main.25.68481802hszz4l>
- Antenna <https://www.aliexpress.com/item/1005001423944489.html?spm=a2g0o.order_list.order_list_main.30.68481802hszz4l>
- FR24 key from flightradar24.com

## Installation

1. Add the RTL2832U as USB passthrough in Proxmox (Use USB Device, not Use USB Port)

2. Clone this repo and run the install script:

```
git clone https://github.com/Kgrande93/FR24Feed.git
cd FR24Feed
sudo bash install.sh
```

You'll be asked for your FlightRadar24 sharing key (get one at
https://www.flightradar24.com/share-your-data if you don't have one yet).
The script installs all dependencies (including `curl`, a hard requirement
for tar1090), readsb, tar1090, and fr24feed, then verifies both the FR24
feed and the tar1090 webinterface at the end.

3. Verify:

```
fr24feed-status
```

Expected output: `FR24 Link: connected [UDP]` and `Receiver: connected`.

### Manual steps (if you'd rather not use the script)

<details>
<summary>Expand</summary>

Install dependencies:

```
sudo apt update && sudo apt upgrade -y
sudo apt install qemu-guest-agent rtl-sdr git curl -y
sudo systemctl enable --now qemu-guest-agent
sudo udevadm control --reload-rules && sudo udevadm trigger
```

> `curl` must be installed before the next step — the tar1090 install that
> runs as part of `readsb-install.sh` depends on it to fetch the aircraft
> database. If it's missing, tar1090 fails partway through with
> `command not found: curl` and the webinterface is left half-installed
> (service running, but no files under `/usr/local/share/tar1090`).

Install readsb (this also installs tar1090 automatically):

```
git clone https://github.com/wiedehopf/adsb-scripts.git
cd adsb-scripts
sudo bash readsb-install.sh
```

Webinterface will be available at `http://<vm-ip>/tar1090` once this completes
without errors. If tar1090 failed earlier due to a missing dependency, re-run
just that part:

```
sudo bash /usr/local/share/adsb-wiki/readsb-install/tar1090-install.sh /run/readsb
sudo systemctl restart lighttpd
```

Remove old FlightAware repos and install FR24:

```
cd ~
sudo rm -f /etc/apt/sources.list.d/piaware.list
sudo rm -f /etc/apt/trusted.gpg.d/flightaware.gpg
sudo apt update
wget -qO- https://fr24.com/install.sh | sudo bash -s
```

During installation: receiver type `1`, decoder arguments empty, RAW `no`, Basestation `no`, MLAT `yes`.

Fill in the key in `fr24feed.ini` and copy it to `/etc/fr24feed.ini`:

```
sudo nano /etc/fr24feed.ini
```

Start the services:

```
sudo systemctl enable fr24feed
sudo systemctl restart fr24feed
```

</details>

## Files

| File           | Description                 |
| -------------- | --------------------------- |
| `install.sh`   | Automated setup script      |
| `fr24feed.ini` | FR24 configuration (no key) |
| `README.md`    | This file                   |
| `LICENSE`      | LICENSE                     |

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

Check the tar1090 webinterface / data feed:

```
wget -S -O - http://127.0.0.1/tar1090/data/aircraft.json
```

## Important

> ⚠️ The FR24 installer sets up its own dump1090, which does not work on Debian 13. `install.sh` always overwrites `fr24feed.ini` afterwards to point at readsb on `127.0.0.1:30005` regardless — if you're doing it manually, don't skip that step.

> ⚠️ `curl` is a hard dependency for the tar1090 install step. `install.sh` installs it up front; if doing it manually, install it before running `readsb-install.sh`.

## Security

- `fr24feed.ini` contains the FR24 key — do not push this to a public repo
- Add `fr24feed.ini` to `.gitignore` or remove the key before pushing

## Infrastructure

Runs as a VM on Proxmox with 1 core, 1 GB RAM, and 16 GB disk. The RTL2832U is USB passthrough directly to the VM.

---

*Confirmed working on Proxmox 8.x with Debian 13 (Trixie) and RTL2832U (R820T tuner)*
