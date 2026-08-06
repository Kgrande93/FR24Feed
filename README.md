# ADS-B Feeder - grandedata.no

**Made by love in Norway 🇳🇴**

A self-hosted ADS-B receiver station that sends flight data to both
FlightRadar24 and OpenSky Network via a single RTL2832U USB dongle
connected to a Debian 13 VM on Proxmox.

---

## How it works

1. **readsb** — Decodes the ADS-B signal from the RTL2832U and exposes it as a Beast stream on port 30005.
2. **fr24feed** — Fetches data from readsb and sends it to FlightRadar24 via UDP.
3. **opensky-feeder** — Also fetches data from readsb (same Beast stream, port 30005) and sends it to OpenSky Network.
4. **qemu-guest-agent** — Proxmox integration for IP reporting and proper shutdown.

## Requirements

- Proxmox 8.x with Debian 13 (Trixie) VM — 1 core, 1 GB RAM, 16 GB disk
- RTL2832U USB dongle with R820T tuner (USB passthrough to VM) <https://www.aliexpress.com/item/1005005466363998.html>
- Antenna <https://www.aliexpress.com/item/1005001423944489.html>
- FR24 key from flightradar24.com
- Free OpenSky Network account from opensky-network.org

## Installation

1. Add the RTL2832U as USB passthrough in Proxmox (Use USB Device, not Use USB Port)

2. Install dependencies:

```
sudo apt update && sudo apt upgrade -y
sudo apt install qemu-guest-agent rtl-sdr git curl -y
sudo systemctl enable --now qemu-guest-agent
sudo udevadm control --reload-rules && sudo udevadm trigger
```
> `curl` must be installed before step 3 — the tar1090 install step that runs
> as part of `readsb-install.sh` depends on it to fetch the aircraft
> database. If it's missing, tar1090 fails partway through with `command not found: curl` and the webinterface is left half-installed
> (service running, but no files under `/usr/local/share/tar1090`).

3. Install readsb (this also installs tar1090 automatically):

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

## Feeding OpenSky Network

Runs alongside fr24feed, sharing the same readsb Beast stream on port 30005 — no conflict, no second antenna needed.

1. Register a free account at https://opensky-network.org/ if you haven't already.

2. Add the OpenSky apt repository and install the feeder:

```
sudo apt-get install apt-transport-https ca-certificates -y
sudo wget -O /etc/apt/trusted.gpg.d/opensky.gpg https://opensky-network.org/files/firmware/opensky.gpg.pub
sudo bash -c "echo deb https://opensky-network.org/repos/debian opensky custom > /etc/apt/sources.list.d/opensky.list"
sudo apt-get update
sudo apt-get install opensky-feeder -y
```

3. During setup you'll be prompted for several values:

   - **Dump1090 branch:** `default` (only pick `hptoa` if you're running the openskynetwork/dump1090-hptoa fork — readsb/wiedehopf setups use `default`)
   - **Beast port:** `30005`
   - **Beast host:** `localhost` — readsb runs on this same VM, same source fr24feed already uses, not a second receiver
   - **Position:** sent automatically from readsb's configured location (set earlier via `readsb-set-location`) — no manual lat/lon/altitude entry needed
   - **Username:** your OpenSky Network account username only. No `client_id`/`client_secret` here — that OAuth2 pair is only needed for apps that *read* data from the OpenSky REST API (e.g. Skywatch), not for feeding.

4. Enable and start:

```
sudo systemctl enable opensky-feeder
sudo systemctl restart opensky-feeder
```

5. Verify:

```
sudo systemctl status opensky-feeder
```

> ⚠️ Feeding actively (receiver online ≥30% of the current month) unlocks
> 8,000 OpenSky API credits/day, versus 4,000 for a registered non-feeder
> and 400 anonymous. Worth doing even beyond the FR24 feed.

## (Optional but recommended) Aircraft database for readsb

Give readsb its own aircraft database, so `aircraft.json` includes
registration/type directly for every aircraft it knows about — richer and
more complete than most free lookup APIs, with no extra network calls
needed:

```
sudo wget -O /usr/local/share/tar1090/aircraft.csv.gz https://github.com/wiedehopf/tar1090-db/raw/csv/aircraft.csv.gz
sudo nano /etc/default/readsb
```

Add `--db-file /usr/local/share/tar1090/aircraft.csv.gz` **inside** the `DECODER_OPTIONS` quotes, e.g.:

```
DECODER_OPTIONS="--max-range 450 --write-json-every 1 --db-file /usr/local/share/tar1090/aircraft.csv.gz"
```
> ⚠️ It must be inside the same quoted string as the other options. Putting
> it outside the quotes (`DECODER_OPTIONS="..." --db-file ...`) means
> systemd silently ignores it.

Then restart:

```
sudo systemctl restart readsb
```

Verify it worked — aircraft entries should now include `r` (registration)
and `t` (type) fields:

```
wget -qO- http://127.0.0.1/tar1090/data/aircraft.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
sample = [a for a in d['aircraft'] if 'r' in a or 't' in a][:3]
print(json.dumps(sample, indent=2))
"
```

## Files

| File           | Description                 |
| -------------- | --------------------------- |
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

Restart the OpenSky feed:

```
sudo systemctl restart opensky-feeder
```

Check the tar1090 webinterface / data feed:

```
wget -S -O - http://127.0.0.1/tar1090/data/aircraft.json
```

## Important

> ⚠️ The FR24 installer sets up its own dump1090, which does not work on Debian 13. `fr24feed.ini` must always point to readsb at `127.0.0.1:30005` — never skip step 5.
> ⚠️ `curl` is a hard dependency for the tar1090 install step. Install it up front (see step 2) to avoid a half-finished webinterface install.

## Security

- `fr24feed.ini` contains the FR24 key — do not push this to a public repo
- Add `fr24feed.ini` to `.gitignore` or remove the key before pushing
- OpenSky feeder config (`/etc/opensky-feeder/...`) contains your OpenSky username/serial — not committed to this repo, same treatment as the FR24 key

## Infrastructure

Runs as a VM on Proxmox with 1 core, 1 GB RAM, and 16 GB disk. The RTL2832U is USB passthrough directly to the VM.

---

*Confirmed working on Proxmox 8.x with Debian 13 (Trixie) and RTL2832U (R820T tuner)*

## Want a live display?

Once this is feeding data, check out [github.com/Kgrande93/skywatch](https://github.com/Kgrande93/skywatch) — a
small web page that shows the last aircraft your antenna picked up, built to
run full-screen on a spare display.
