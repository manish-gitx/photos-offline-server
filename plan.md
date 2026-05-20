# Family Photo Migration Plan — Google Photos → Immich (self-hosted)

> **Goal:** Move the whole family off Google One / Google Photos to a self-hosted
> **Immich** server running on a home Linux laptop. **Photos are stored on an HDD**
> (bulk capacity), the **database on an SSD** (speed + integrity). Each family member
> gets their own private account, phones auto-back up, and the server is reached on
> the **home network** at `http://<laptop-ip>:2283`.
>
> Read this top to bottom. Do the phases **in order**.

---

## 0. Key facts to understand first

- **Immich** is free, open-source, self-hosted. You run the server; nothing is in any cloud.
- The **server** = your Linux laptop. **Photo storage** = your HDD. **Database** = your SSD.
  The **clients** = phone apps + web browser.
- Immich does **NOT** back itself up. Hardware failure = data loss unless *you* set up
  backups. **(Deferred — see "Deferred for later" below.)** Until then, the SSD + HDD
  are your only copies, so don't delete from Google/phones yet.
- The first account created becomes **admin**. Each user's library is **private** by default.
- **Remote access is out of scope for now — this setup is LAN-only.** The server is
  reachable only from your home network. **(Deferred — see below.)**

### Deferred for later (intentionally not in this plan yet)

- **Server backups (3-2-1):** a second drive + an off-site copy. Strongly recommended —
  add this before you trust the server as your only photo store.
- **Remote access:** a reverse proxy (Caddy) + port-forwarding, or a VPN like Tailscale,
  to reach the server from outside the house. Plan to add this once the basics are solid.

---

## Phase 1 — Hardware & OS prep

- [ ] **1.1** Confirm laptop specs meet requirements:
  - `free -h` → RAM: **6 GB min, 8 GB recommended**
  - `nproc` → CPU: **2 cores min, 4 recommended**
  - CPU must be **x86-64-v2** (any CPU from ~2012 onward).
- [ ] **1.2** Set the laptop to **never sleep on AC power** and stay awake with lid closed.
- [ ] **1.3** Give the laptop a **fixed local IP** via a DHCP reservation in the router (e.g. `192.168.1.50`).
- [ ] **1.4** Check both drives' filesystems: `lsblk -f`
  - **SSD (database):** on this laptop the SSD is the **OS disk** — root `/` is already
    EXT4 with ~188 GB free. The database lives in `~/immich-app/postgres` on it; no
    separate SSD mount is needed. **exFAT / NTFS will corrupt the database — never use them.**
  - **HDD (photos):** the 2 TB HDD is wiped and reformatted as a **single EXT4** partition.
- [ ] **1.5** Mount the HDD at a fixed path and ensure it auto-mounts on boot (`/etc/fstab`):
  - HDD → `/mnt/hdd` (holds the photos)

**Decided:**
- SSD (database): OS disk, root `/` (EXT4) — DB at `~/immich-app/postgres`
- HDD mount path: `/mnt/hdd` (photos)
- Number of family members / accounts: `__________________`

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
  | `UPLOAD_LOCATION` | `/mnt/hdd/immich` | Photo storage — on the **HDD** |
  | `DB_DATA_LOCATION` | `/home/manish/immich-app/postgres` | Database — on the **SSD** (OS disk, EXT4), never a network share |
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
  **daily at 02:00**, keeps **14**, stored in `UPLOAD_LOCATION/backups`
  (i.e. `/mnt/hdd/immich/backups`). Confirm it's enabled.
- [ ] **4.3** **Trash retention** — default 30 days. Leave as-is.
- [ ] **4.4** (Optional) Enable Hardware Transcoding / ML acceleration if the laptop supports it.

---

## Phase 5 — Create family accounts

- [ ] **5.1** Administration → Users → create **one account per family member** (email + temp password).
- [ ] **5.2** (Optional) Set a **storage quota** per user so one person can't fill the HDD.
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
- [ ] **6.8** Keep the Takeout zips until everything is verified.

---

## Phase 7 — Phone backup & reclaiming space

- [ ] **7.1** Each member installs the **Immich app** (Play Store / App Store / F-Droid).
- [ ] **7.2** Log in: Server URL = `http://<laptop-ip>:2283`, then their own account.
  (Phones must be on the **home WiFi** — this is a LAN-only setup.)
- [ ] **7.3** In the app: cloud icon → select Camera Roll album → **enable backup**.
  Turn on **background** AND **foreground** backup.
  - Android: set Immich to **Unrestricted** battery usage.
  - iOS: enable **Background App Refresh** for Immich.
- [ ] **7.4** Let each phone finish its **first full backup on home WiFi** — verify on
  the server that counts match.
- [ ] **7.5** Let it run reliably for **2–4 weeks**. Confirm new photos keep appearing.
- [ ] **7.6** Only then: in the app use **"Free up space"** — it deletes already-backed-up
  photos *from the phone* (you review first; keeps favorites/albums; goes to phone trash).
- [ ] **7.7** Only cancel the Google One subscriptions once you are fully confident **and**
  the deferred server backups are in place.

---

## Phase 8 — Ongoing maintenance

- [ ] **8.1** Update Immich regularly:
  ```bash
  cd ~/immich-app
  docker compose pull && docker compose up -d
  ```
  Check the **web UI** for the real version (ignore stray Docker "update" labels).
- [ ] **8.2** Watch HDD free space; raise/lower user quotas as needed.
- [ ] **8.3** Keep the laptop OS patched (`unattended-upgrades`).
- [ ] **8.4** Revisit the **deferred items**: set up server backups (3-2-1) and, if wanted,
  remote access. Don't trust the server as your only copy until backups exist.

---

## Quick reference

| Item | Value |
|---|---|
| Immich web UI (local) | `http://<laptop-ip>:2283` |
| App directory | `~/immich-app` |
| Photo storage | `/mnt/hdd/immich` (`UPLOAD_LOCATION`) — HDD |
| DB storage | `~/immich-app/postgres` (`DB_DATA_LOCATION`) — SSD (OS disk) |
| DB auto-backup | `/mnt/hdd/immich/backups`, daily 02:00, keep 14 |
| Start/stop | `docker compose up -d` / `docker compose down` |
| Update | `docker compose pull && docker compose up -d` |

## Golden rules

1. **Set up real backups soon (deferred).** Until then the SSD/HDD are the only copies —
   don't delete from Google or phones.
2. **Verify before you delete** — never delete from Google or phones until checked.
3. **Never hand-edit Immich's files** — always go through the app.
4. **EXT4 only** for the database (the SSD) — exFAT/NTFS will corrupt it.
