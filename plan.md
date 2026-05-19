# Family Photo Migration Plan — Google Photos → Immich (self-hosted)

> **Goal:** Move the whole family off Google One / Google Photos to a self-hosted
> **Immich** server running on a home Linux laptop, with photos stored on an SSD,
> each family member having their own private account, phones auto-backing up, and
> remote access from anywhere via **port-forwarding + a reverse proxy (Caddy)**.
>
> Read this top to bottom. Do the phases **in order**. Do not skip Phase 6 (backups).

---

## 0. Key facts to understand first

- **Immich** is free, open-source, self-hosted. You run the server; nothing is in any cloud.
- The **server** = your Linux laptop. The **storage** = your SSD. The **clients** = phone apps + web browser.
- Immich does **NOT** back itself up. Hardware failure = data loss unless *you* set up backups.
- The first account created becomes **admin**. Each user's library is **private** by default.
- Remote-access route chosen here: **port-forward + Caddy reverse proxy** under your own domain.
  - ✅ No app needed on phones, your own domain, **50 GB+ upload size** (big videos work).
  - ⚠️ Your laptop becomes **publicly reachable** — security (Phase 9) is mandatory, not optional.

---

## Phase 1 — Hardware & OS prep

- [ ] **1.1** Confirm laptop specs meet requirements:
  - `free -h` → RAM: **6 GB min, 8 GB recommended**
  - `nproc` → CPU: **2 cores min, 4 recommended**
  - CPU must be **x86-64-v2** (any CPU from ~2012 onward).
- [ ] **1.2** Set the laptop to **never sleep on AC power** and stay awake with lid closed.
- [ ] **1.3** Give the laptop a **fixed local IP** via a DHCP reservation in the router (e.g. `192.168.1.50`).
- [ ] **1.4** Check the SSD filesystem: `lsblk -f`
  - Must be **EXT4 / ZFS** (a Unix filesystem). **exFAT / NTFS will corrupt the database — do not use them.**
  - If the SSD is exFAT/NTFS → **back up its contents elsewhere, then reformat as EXT4.**
- [ ] **1.5** Mount the SSD at a fixed path, e.g. `/mnt/ssd`, and ensure it auto-mounts on boot (`/etc/fstab`).

**Decide now:**
- SSD mount path: `__________________` (this plan assumes `/mnt/ssd`)
- Number of family members / accounts: `__________________`
- Your domain name: `__________________` (this plan assumes `photos.example.com`)

---

## Phase 2 — Install Docker

- [ ] **2.1** Install Docker Engine + Compose plugin (official packages, not the distro version):
  ```bash
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
  ```
- [ ] **2.2** Log out and back in (so `docker` works without `sudo`).
- [ ] **2.3** Verify: `docker compose version` (must be the **`docker compose`** plugin — the old `docker-compose` is unsupported).

---

## Phase 3 — Install Immich (Docker Compose method — official)

- [ ] **3.1** Create the app directory and download the official files:
  ```bash
  mkdir ~/immich-app && cd ~/immich-app
  wget https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
  wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env
  ```
- [ ] **3.2** Edit `~/immich-app/.env`:
  | Variable | Set to | Notes |
  |---|---|---|
  | `UPLOAD_LOCATION` | `/mnt/ssd/immich` | Photo storage — on the SSD |
  | `DB_DATA_LOCATION` | `/mnt/ssd/immich/postgres` | DB — local SSD, **EXT4 only**, never a network share |
  | `DB_PASSWORD` | a strong password | **Letters + numbers only** (`A-Za-z0-9`), no symbols |
  | `TZ` | e.g. `Asia/Kolkata` | Uncomment and set your timezone |
  | `IMMICH_VERSION` | leave as `release` | Pin a version later if you want |
- [ ] **3.3** Start it:
  ```bash
  cd ~/immich-app
  docker compose up -d
  ```
- [ ] **3.4** Open `http://<laptop-ip>:2283` in a browser. You should see the setup screen.
- [ ] **3.5** **Create the admin account FIRST — make it YOURS.** The first registered user is the admin.

> Note: changing any `.env` value later requires `docker compose up -d` again to recreate
> containers — a plain restart does **not** apply new env values.

---

## Phase 4 — Post-install configuration (as admin)

- [ ] **4.1** **Storage Template** — Administration → Settings → Storage Template.
  Default `Year/Year-Month-Day/Filename.ext` is fine. Enable it before importing lots of photos.
- [ ] **4.2** **Database backups** — Administration → Settings → Backup. Immich auto-dumps the DB
  **daily at 02:00**, keeps **14**, stored in `UPLOAD_LOCATION/backups`. Confirm it's enabled.
- [ ] **4.3** **Trash retention** — default 30 days. Leave as-is.
- [ ] **4.4** (Later, after Phase 8) Set **External Domain** to `https://photos.example.com`
  so shared links use the right address.
- [ ] **4.5** (Optional) Enable Hardware Transcoding / ML acceleration if the laptop supports it.

---

## Phase 5 — Create family accounts

- [ ] **5.1** Administration → Users → create **one account per family member** (email + temp password).
- [ ] **5.2** (Optional) Set a **storage quota** per user so one person can't fill the SSD.
- [ ] **5.3** For **each** user account, generate an **API key**
  (log in as them, or have them do it: Account Settings → API Keys). Needed for Phase 6.
- [ ] **5.4** Do **not** install the phone apps yet — migrate the old library first.

---

## Phase 6 — Migrate existing Google Photos (one member at a time)

Use **`immich-go`** — the community tool the Immich docs recommend for Google Takeout.
It correctly reads Takeout's JSON metadata (dates, GPS, albums). Do NOT use the built-in CLI for Takeout.

- [ ] **6.1** Each family member requests their **Google Takeout**:
  takeout.google.com → deselect all → select **Google Photos** only → export as
  `.zip`, 50 GB chunks. Google takes hours/days, then emails download links.
- [ ] **6.2** Download all that person's zip files onto the laptop.
- [ ] **6.3** Install `immich-go` (download the latest Linux release binary from
  `github.com/simulot/immich-go` releases, or its successor repo).
- [ ] **6.4** **Dry run first** (no changes — just checks):
  ```bash
  immich-go upload from-google-photos \
    --server=http://localhost:2283 \
    --api-key=<THAT_USERS_API_KEY> \
    --dry-run --sync-albums \
    /path/to/their/takeout-*.zip
  ```
- [ ] **6.5** Real import (drop `--dry-run`):
  ```bash
  immich-go upload from-google-photos \
    --server=http://localhost:2283 \
    --api-key=<THAT_USERS_API_KEY> \
    --sync-albums \
    /path/to/their/takeout-*.zip
  ```
- [ ] **6.6** Log into the web UI **as that user** and verify photo **count, dates, albums**.
- [ ] **6.7** Repeat 6.1–6.6 for **every** family member, each into their own account.
- [ ] **6.8** Keep the Takeout zips until everything is verified AND backed up (Phase 7).

---

## Phase 7 — Server backups (3-2-1) — DO NOT SKIP

Immich does not protect your data. Target: **3 copies, 2 media, 1 off-site.**

- [ ] **7.1** Get a **second drive** (Drive B) — any external HDD.
- [ ] **7.2** What to back up:
  - The whole `UPLOAD_LOCATION` (`/mnt/ssd/immich`) — at minimum the
    `upload/`, `library/`, `profile/`, and `backups/` folders.
  - The `backups/` folder already contains the daily DB dumps.
- [ ] **7.3** Backup rules:
  - **Never** manually edit files inside the Immich folders — use the app only.
  - Back up **database first, then files** (or stop the server during backup).
- [ ] **7.4** Nightly copy to Drive B (example — schedule with `cron`):
  ```bash
  rsync -av --delete /mnt/ssd/immich/ /mnt/driveB/immich-backup/
  ```
- [ ] **7.5** **Off-site copy:** keep Drive B at a relative's house, or sync to a cheap
  cloud bucket. One house fire must not destroy everything.
- [ ] **7.6** **Test a restore once** so you know it works. DB restore requires a
  **fresh Immich install** — never restore onto a running/used instance.

---

## Phase 8 — Remote access: port-forward + Caddy reverse proxy

This makes Immich reachable from anywhere as `https://photos.example.com`.

> ⚠️ Check first: if your ISP uses **CGNAT**, port-forwarding will not work — you'd
> have to switch to Tailscale or Cloudflare Tunnel. Test by comparing your router's
> WAN IP to whatismyip.com — if they differ, you're behind CGNAT.

- [ ] **8.1** **DNS:** create an `A` record for `photos.example.com` pointing to your
  home's public IP. If your home IP changes, set up **Dynamic DNS** (router DDNS, or a
  DDNS updater script) so the record stays current.
- [ ] **8.2** **Router:** forward external ports **80** and **443** → laptop's fixed IP
  (`192.168.1.50`). Do **NOT** forward port 2283 directly.
- [ ] **8.3** **Install Caddy** on the laptop (it does automatic HTTPS):
  ```bash
  sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
  sudo apt update && sudo apt install caddy
  ```
- [ ] **8.4** Edit `/etc/caddy/Caddyfile`:
  ```caddy
  photos.example.com {
      reverse_proxy 127.0.0.1:2283
  }
  ```
  Caddy automatically: gets a free HTTPS certificate, handles WebSockets, and
  **streams uploads with no body-size limit** (so 50 GB+ videos upload fine — this is
  the advantage over Cloudflare's free 100 MB cap).
- [ ] **8.5** Reload Caddy: `sudo systemctl reload caddy`
- [ ] **8.6** Test: open `https://photos.example.com` in a browser → Immich login page.
- [ ] **8.7** In Immich: Administration → Settings → set **External Domain** to
  `https://photos.example.com`.

---

## Phase 9 — Security (MANDATORY — the server is now public)

The moment Phase 8 is live, bots will find the server within minutes (internet-wide
scans + certificate transparency logs). These are not optional:

- [ ] **9.1** **Every account** (admin + all family) has a **strong, UNIQUE** password —
  not reused from any other site. The weakest password is your real security level.
- [ ] **9.2** Keep Immich **updated** — see Phase 11. Security fixes ship in updates.
- [ ] **9.3** Install **Fail2ban** (or equivalent) to block repeated login-guessing.
- [ ] **9.4** Keep the laptop OS patched (`unattended-upgrades`).
- [ ] **9.5** Do not create public share links unless intended — they need no login.
- [ ] **9.6** Consider disabling new-user self-registration (admin creates users only).

---

## Phase 10 — Phone backup & reclaiming space

- [ ] **10.1** Each member installs the **Immich app** (Play Store / App Store / F-Droid).
- [ ] **10.2** Log in: Server URL = `https://photos.example.com`, then their own account.
- [ ] **10.3** In the app: cloud icon → select Camera Roll album → **enable backup**.
  Turn on **background** AND **foreground** backup.
  - Android: set Immich to **Unrestricted** battery usage.
  - iOS: enable **Background App Refresh** for Immich.
- [ ] **10.4** Let each phone finish its **first full backup on home WiFi** — verify on
  the server that counts match.
- [ ] **10.5** Let it run reliably for **2–4 weeks**. Confirm new photos keep appearing.
- [ ] **10.6** Only then: in the app use **"Free up space"** — it deletes already-backed-up
  photos *from the phone* (you review first; keeps favorites/albums; goes to phone trash).
- [ ] **10.7** Once fully confident: **cancel the Google One subscriptions.**

---

## Phase 11 — Ongoing maintenance

- [ ] **11.1** Update Immich regularly:
  ```bash
  cd ~/immich-app
  docker compose pull && docker compose up -d
  ```
  Check the **web UI** for the real version (ignore stray Docker "update" labels).
- [ ] **11.2** Periodically confirm the Phase 7 backup actually ran and Drive B has data.
- [ ] **11.3** Watch SSD free space; raise/lower user quotas as needed.
- [ ] **11.4** Keep Caddy and the OS updated.

---

## Quick reference

| Item | Value |
|---|---|
| Immich web UI (local) | `http://<laptop-ip>:2283` |
| Immich (remote) | `https://photos.example.com` |
| App directory | `~/immich-app` |
| Photo storage | `/mnt/ssd/immich` (`UPLOAD_LOCATION`) |
| DB storage | `/mnt/ssd/immich/postgres` (`DB_DATA_LOCATION`) |
| DB auto-backup | `/mnt/ssd/immich/backups`, daily 02:00, keep 14 |
| Backup drive | Drive B — nightly `rsync`, plus 1 off-site copy |
| Start/stop | `docker compose up -d` / `docker compose down` |
| Update | `docker compose pull && docker compose up -d` |

## Golden rules

1. **One SSD = zero backups.** Phase 7 is as important as installing Immich.
2. **Verify before you delete** — never delete from Google or phones until backed up + checked.
3. **Public server = your security responsibility.** Phase 9 is mandatory.
4. **Never hand-edit Immich's files** — always go through the app.
5. **EXT4 only** for the database — exFAT/NTFS will corrupt it.
