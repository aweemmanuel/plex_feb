# 🎬 Plex + rclone + WebDAV on Railway

A production-ready Docker template that runs **Plex Media Server** with **FebBox / WebDAV** storage via **rclone**, deployed on [Railway](https://railway.app).

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/new?template=https://github.com/YOUR_USERNAME/plex-railway)

---

## 🏗️ Architecture

```
WebDAV (FebBox)
      ↓
   rclone (sync or mount)
      ↓
/data/media  ←──── local Railway volume
      ↓
Plex Media Server
      ↓
VIDAA TV / Plex App
```

---

## 🚀 One-Click Deploy

1. Click the **Deploy on Railway** button above
2. Fill in the required environment variables (see table below)
3. Railway provisions volumes and starts the container
4. Visit `https://YOUR-APP.railway.app:32400/web` to access Plex

---

## ⚙️ Environment Variables

Set these in your Railway service → **Variables** tab:

| Variable | Required | Default | Description |
|---|---|---|---|
| `WEBDAV_URL` | ✅ | — | WebDAV server URL (e.g. `https://webdav.febbox.com/dav`) |
| `WEBDAV_USER` | ✅ | — | Your FebBox email / username |
| `WEBDAV_PASS` | ✅ | — | Your FebBox password or token |
| `WEBDAV_VENDOR` | | `other` | WebDAV vendor type |
| `PLEX_CLAIM` | ⚠️ | — | Plex claim token ([get one here](https://www.plex.tv/claim)) — needed on first deploy |
| `PLEX_TOKEN` | | — | Plex auth token for library refresh API calls |
| `SYNC_MODE` | | `sync` | `sync` (stable) or `mount` (real-time) |
| `SYNC_INTERVAL` | | `10` | Minutes between syncs (sync mode only) |
| `TZ` | | `Africa/Lagos` | Your timezone |
| `RCLONE_REMOTE_NAME` | | `febbox` | rclone remote name |
| `LOCAL_MEDIA_PATH` | | `/data/media` | Local path where media is stored |

---

## 📁 Volumes

Railway must have these volumes mounted:

| Mount Path | Purpose |
|---|---|
| `/data` | Media files |
| `/config` | Plex config & metadata |
| `/transcode` | Transcoding temp files |

In Railway: **Service → Settings → Volumes → Add Volume**

---

## 🔄 Sync Modes

### `SYNC_MODE=sync` ✅ Recommended
- rclone copies files from WebDAV to `/data/media` every N minutes
- Most stable on Railway
- No buffering or stream interruptions
- Works like a local library

### `SYNC_MODE=mount`
- rclone mounts WebDAV as a live filesystem at `/mnt/febbox`
- Real-time access — no waiting for sync
- Can disconnect on Railway's network; use for testing

---

## 🎟️ Getting Your Plex Claim Token

1. Go to [https://www.plex.tv/claim](https://www.plex.tv/claim)
2. Copy the `claim-XXXXXX` token
3. Paste it as `PLEX_CLAIM` in Railway **before first deploy**
4. It expires in 4 minutes — deploy quickly!

You only need this once. Remove it from ENV after first successful boot.

---

## 🔑 Getting Your Plex Token (for library refresh)

1. Sign in to Plex Web
2. Open any media item → `⋮` → **Get Info** → **View XML**
3. The URL contains `X-Plex-Token=XXXXXXXX`
4. Copy that value into `PLEX_TOKEN`

---

## 📡 Ports

| Port | Use |
|---|---|
| `32400` | Plex Web UI + streaming |

Railway auto-assigns a public HTTPS URL that proxies to port 32400.

---

## 🧱 File Structure

```
plex-railway/
├── Dockerfile
├── railway.toml
├── .env.example
├── .gitignore
├── README.md
└── scripts/
    ├── entrypoint.sh          # Main startup logic
    ├── generate-rclone-config.sh  # Builds rclone.conf from ENV
    ├── sync-media.sh          # Runs rclone sync
    ├── refresh-plex.sh        # Calls Plex API to refresh library
    └── healthcheck.sh         # Docker healthcheck
```

---

## 🔍 Logs

Logs are written to `/var/log/plex-railway/`:

| File | Contents |
|---|---|
| `startup.log` | Container startup output |
| `sync.log` | rclone sync history |
| `rclone-mount.log` | rclone mount output (mount mode only) |

To view from Railway: **Service → Deployments → View Logs**

---

## ⚠️ Railway Limitations

- No permanent storage guarantee on free plans — use **paid volumes**
- Heavy transcoding may crash free tier (Plex direct play is fine)
- Mount mode may disconnect; `sync` mode is more stable
- Max 500MB RAM on free tier — upgrade for large libraries

---

## 🧩 Optional Upgrades

- **Cloudflare Tunnel** — secure remote access without exposing Railway URL
- **Bazarr** — auto subtitle downloads
- **Sonarr/Radarr** — media management & auto-download
- **Overseerr** — request management for friends/family

---

## 📜 License

MIT — use freely, fork, contribute!
