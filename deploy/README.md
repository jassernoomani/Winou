# Demo server

The whole stack on one free server: **Oracle Cloud "Always Free"** (ARM, 4 CPUs, 24 GB of
memory), a free **DuckDNS** name, and **Caddy** for HTTPS. Testers install the app from a link
on the same server; there is no Play Store listing.

```
phone ──HTTPS──> Caddy ──> api ──> postgres, minio, qdrant
                   │        worker ──> ml-service
                   └──> /download/winou.apk
```

Takes about an hour the first time, most of it waiting for the first build.

## Or: host it at home (Windows PC)

Like a game server: the stack runs on your PC, the router forwards ports 80 and 443 to it, and
Caddy gets the HTTPS certificate. The PC has to stay on and awake.

1. **DuckDNS** (step 1 below), then save the token, git-ignored, and keep the name pointing here:

   ```powershell
   Set-Content -NoNewline secrets\duckdns-token.txt <token>
   powershell -ExecutionPolicy Bypass -File deploy\windows\install-duckdns-task.ps1 <subdomain>
   ```

2. **Router**: forward TCP **80** and **443** to the PC's local address (`ipconfig`, e.g.
   192.168.1.18). Reserve that address for the PC in the router's DHCP settings so it doesn't change.
3. **Windows firewall**: Docker Desktop's rule covers *Public* networks. On a *Private* one, once in
   an admin PowerShell:
   `New-NetFirewallRule -DisplayName 'Winou HTTPS' -Direction Inbound -Protocol TCP -LocalPort 80,443 -Action Allow`
4. **`.env`**: `WINOU_DOMAIN=<subdomain>.duckdns.org`, strong `JWT_SECRET` and `LOCATION_FUZZ_SECRET`
   (never the defaults: they are public on GitHub), and `POSTGIS_IMAGE=postgis/postgis:18-3.6` if
   the database was created with the official image.
5. **Start**: `docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml up -d`.
   The API stays on `127.0.0.1:8080` for scripts and USB; the internet only reaches Caddy.
6. **Docker Desktop** → Settings → General → *Start Docker Desktop when you sign in*, and Windows
   power settings: never sleep when plugged in.

On the home Wi-Fi itself, the public name works only if the router supports "NAT loopback";
otherwise use the PC's local address there (Server address in the app).

## 1. A free name (DuckDNS)

1. Sign in at <https://www.duckdns.org> (with GitHub or Google).
2. Add a subdomain, e.g. `winou` → `winou.duckdns.org`. Any IP for now; the server updates it.
3. Keep the **token** shown at the top of the page.

## 2. A free server (Oracle Cloud)

1. Sign up at <https://www.oracle.com/cloud/free/>. A card is asked to check your identity; the
   "Always Free" resources below are never charged. Pick a **home region** close to Tunisia
   (e.g. *France South (Marseille)* or *Italy (Milan)*): it can't be changed later.
2. **Compute → Instances → Create instance**:
   - Image: **Ubuntu 24.04** (Canonical).
   - Shape: **Ampere → VM.Standard.A1.Flex**, **4 OCPUs, 24 GB** memory.
   - Networking: keep the defaults (new network, **assign a public IPv4 address**).
   - SSH keys: upload your public key. No key yet? On the laptop: `ssh-keygen -t ed25519`, then
     upload `C:\Users\<you>\.ssh\id_ed25519.pub`.
   - Boot volume: 100 GB (free up to 200 GB).

   *"Out of capacity"* is common for free ARM servers: try another availability domain, or again
   later.
3. Open the web ports: on the instance page, **Subnet → Security list → Add ingress rules**:
   source `0.0.0.0/0`, TCP, destination ports **80** and **443**.
4. Note the instance's **public IP**.

> Oracle may reclaim an Always Free server that stays almost idle for a week. A demo with a
> few users is usually fine; if it happens, recreate it and restore a backup (step 6).

## 3. Set up the server

From the laptop (PowerShell or Git Bash):

```bash
ssh ubuntu@<public IP>
git clone https://github.com/jassernoomani/Winou.git
cd Winou
deploy/setup-server.sh winou <duckdns token>   # Docker, firewall, DuckDNS, nightly backup
exit                                           # log out once, so Docker works without sudo
```

Back in, create the settings with fresh secrets. Use the email you sign into the app with: that
account becomes the admin.

```bash
ssh ubuntu@<public IP>
cd Winou
deploy/make-env.sh winou.duckdns.org you@example.com
```

Push notifications need the Firebase key. From the laptop, in the repo:

```bash
scp secrets/firebase-service-account.json ubuntu@<public IP>:~/Winou/secrets/
```

## 4. Start it

On the server:

```bash
cd Winou
deploy/deploy.sh
```

The first run builds everything on the server (20–30 minutes: PyTorch and the models). When it
says `Up: https://winou.duckdns.org/docs`, open that page: the API answers over HTTPS.

## 5. The app

On the laptop, build the app against the server and put it online:

```bash
cd mobile
flutter build apk --release --target-platform android-arm64 --dart-define=API_URL=https://winou.duckdns.org
scp build/app/outputs/flutter-apk/app-release.apk ubuntu@<public IP>:~/Winou/deploy/download/winou.apk
```

Send testers **https://winou.duckdns.org/download/winou.apk**. Android asks them to allow
installing apps from their browser once. The APK is signed with this laptop's debug key: build
updates on the same laptop, or testers have to uninstall first.

## 6. Day to day

| What | How (on the server, in `~/Winou`) |
|---|---|
| Deploy the latest code | push to GitHub, then `deploy/deploy.sh` |
| Logs | `docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml logs -f api worker` |
| Backups | nightly in `~/backups` (last 7); by hand: `deploy/backup.sh` |
| Restore | `gunzip -c ~/backups/winou-<date>.sql.gz \| docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml exec -T postgres psql -U winou -d winou` |
| Add an admin | add the email to `ADMIN_EMAILS` in `.env`, then `deploy/deploy.sh` |

Keep `.env` safe and never regenerate it: its secrets protect the data (see `make-env.sh`).
