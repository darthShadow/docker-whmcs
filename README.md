WHMCS Docker Image
==================

Ready to use Docker image for WHMCS environment, packaging PHP-FPM, nginx,
SourceGuardian, and ionCube on top of `lscr.io/linuxserver/baseimage-ubuntu:noble`.

---

## Features

* PHP `8.3` runtime (see [PHP_VERSION.txt](PHP_VERSION.txt))
* ionCube and SourceGuardian loaders preinstalled
* Nginx server configuration tailored for WHMCS
* WHMCS cron preinstalled
* All persistent state under a single `/config` volume
* Multi-arch image supporting both `linux/amd64` and `linux/arm64`
* Optional `htpasswd` protection for the admin path (requires both `AUTH_USER` *and* `AUTH_PASS`)

---

## Supported Architectures

The published manifest is multi-arch. Pulling `ghcr.io/darthshadow/whmcs:latest`
selects the right image for your host automatically.

| Architecture | Available |
| :----: | :----: |
| x86-64 | yes |
| arm64  | yes |

---

## Usage

### docker-compose

```yaml
---
services:
  whmcs:
    image: ghcr.io/darthshadow/whmcs:latest
    hostname: whmcs
    container_name: whmcs
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
      - AUTH_USER=whmcs
      - AUTH_PASS=whmcs@server:2022
      - WHMCS_SERVER_IP=1.1.1.1
      - WHMCS_SERVER_URL=whmcs.example.com
      - WHMCS_ADMIN_PATH=admin
    volumes:
      - /path/to/whmcs:/config
    ports:
      - 8043:80
    restart: unless-stopped
```

### docker cli

```bash
docker run -d \
  --name=whmcs \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=UTC \
  -e AUTH_USER=whmcs \
  -e AUTH_PASS=whmcs@server:2022 \
  -e WHMCS_SERVER_IP=1.1.1.1 \
  -e WHMCS_SERVER_URL=whmcs.example.com \
  -e WHMCS_ADMIN_PATH=admin \
  -p 8043:80 \
  -v /path/to/whmcs:/config \
  --restart unless-stopped \
  ghcr.io/darthshadow/whmcs:latest
```

---

## Parameters

| Parameter | Function |
| :---- | :--- |
| `-p 80` | WHMCS web UI (proxy externally for TLS) |
| `-e PUID=1000` | UID for the in-container `abc` user |
| `-e PGID=1000` | GID for the in-container `abc` user |
| `-e TZ=UTC` | Timezone, e.g. `UTC`, `Europe/London` |
| `-e AUTH_USER=` *(optional)* | Username for the admin-path HTTP-basic challenge (path set by `WHMCS_ADMIN_PATH`) |
| `-e AUTH_PASS=` *(optional)* | Password for the admin-path HTTP-basic challenge |
| `-e WHMCS_SERVER_IP=` | Host public IP — required for WHMCS license validation |
| `-e WHMCS_SERVER_URL=` | Host public hostname — required for WHMCS license validation |
| `-e WHMCS_ADMIN_PATH=admin` *(optional)* | Admin URL path protected by HTTP basic auth |
| `-v /config` | Persistent data root (see [Volume layout](#volume-layout)) |

`AUTH_USER` and `AUTH_PASS` must either both be set or both be empty. Setting
only one will cause the container to refuse to start, since a partial auth
config would otherwise leave the admin path silently unprotected.

---

## Volume layout

Everything stateful lives under `/config`. On first boot the container seeds
defaults. Most seeded files are left untouched on later boots; env-rendered
nginx files are refreshed while their tracked live copy has not been edited.
Edit on the host, then restart the container to pick up changes.

```
/config/
├── whmcs/                 WHMCS configuration.php (canonical copy)
├── www/whmcs/             Extracted WHMCS web root (symlinked to /var/www/whmcs)
├── www/whmcs_storage/     downloads, attachments, templates_c, etc.
├── nginx/
│   ├── nginx.conf         Global nginx config
│   ├── conf.d/php         PHP location block (uses $WHMCS_SERVER_IP)
│   └── sites-available/whmcs   Site config (uses $WHMCS_SERVER_URL, $WHMCS_ADMIN_PATH)
├── php/99-local.ini       PHP overrides (php.ini-style)
├── fpm/99-local.conf      php-fpm pool overrides
├── crontabs/whmcs         WHMCS cron schedule
└── cron/log/              cron job logs
```

`AUTH_USER` / `AUTH_PASS` regenerate `/etc/nginx/.htpasswd` on every start, so
rotating credentials is just an env-var change plus restart. Nginx defaults to
`client_max_body_size 30M;`; override `/config/nginx/nginx.conf` if WHMCS
uploads need a different ceiling.

`WHMCS_*` nginx env vars are re-applied on every restart. If you edit
`/config/nginx/conf.d/php` or `/config/nginx/sites-available/whmcs`, the image
keeps your live file and writes future rendered updates to `.new` until you
accept that overlay.

The image includes a Docker healthcheck that probes `http://127.0.0.1/` after
a 60-second start period.

---

## Tags and branches

| Tag | Meaning |
| :---- | :--- |
| `latest` | Build of `main` on every push and on every weekly run |
| `latest-deps` | Alias for the most recent weekly dependency-update build |
| `weekly-YYYY-MM-DD` | Specific weekly build (kept indefinitely) |
| `v<whmcs>-v<php>` | Pinned WHMCS+PHP combination, e.g. `v9.0.4-v8.3`; weekly builds apply this tag directly |

Branch layout:

* `main` — latest stable WHMCS on the current PHP version
* `version/<whmcs-major>.x-php<php>` — active major-line combinations
* Older `version/<whmcs-minor>-php<php>` branches are historical archives

The canonical versions for any branch live in `WHMCS_VERSION.txt` and
`PHP_VERSION.txt` at the repo root.

---

## Upgrades

### Image upgrade (no WHMCS file changes)

`docker pull` + recreate the container. Base image and PHP/nginx packages get
the latest patches; `/config` is preserved.

### WHMCS upgrade (new WHMCS files)

**By design, pulling a newer image does *not* replace WHMCS files in
`/config/www/whmcs`.** The init script (`60-whmcs`) only extracts the bundled
zip when `/config/www/whmcs/index.php` is missing, so your customisations,
modules, and templates are never overwritten on restart.

To upgrade WHMCS itself when a new image ships a newer version, choose one of:

1. **In-place via WHMCS's built-in updater** (recommended for minor/patch
   bumps). Use Admin → Utilities → Update WHMCS. This is independent of the
   container and works on any image build.

2. **Replace the bundled zip** (recommended after pulling a new image):

   ```bash
   # Stop the container so nothing is mid-write
   docker stop whmcs

   # Back up the current install
   sudo cp -a /path/to/whmcs/www/whmcs /path/to/whmcs/www/whmcs.bak

   # Wipe the web root so init re-extracts the bundled version
   sudo rm -rf /path/to/whmcs/www/whmcs

   # Start fresh — init will extract the image's WHMCS zip and copy
   # /config/whmcs/configuration.php back into place.
   docker start whmcs
   ```

   Your `configuration.php`, `whmcs_storage/`, custom modules in
   `modules/`, and templates need to be re-merged from the `.bak` copy
   afterwards.

3. **Restore from backup** if step 2 doesn't go smoothly:

   ```bash
   docker stop whmcs
   sudo rm -rf /path/to/whmcs/www/whmcs
   sudo mv /path/to/whmcs/www/whmcs.bak /path/to/whmcs/www/whmcs
   docker start whmcs
   ```

### Major version / PHP upgrade

Pin to the matching `version/<whmcs-major>.x-php<php>` branch tag, e.g.
`ghcr.io/darthshadow/whmcs:v9.0.4-v8.3`, before crossing a major version.

---

## Building locally

```bash
# Build for the host architecture, using the version files at repo root
scripts/build-local.sh image-local

# Pin a specific WHMCS/PHP combo
docker buildx bake --set image.args.WHMCS_RELEASE=9.0.4 \
                   --set image.args.PHP_RELEASE=8.3 image-local

# Verify the loader downloads against known-good SHA256s (optional)
docker buildx bake \
  --set image.args.SOURCEGUARDIAN_SHA256_AMD64=<sha> \
  --set image.args.IONCUBE_SHA256_AMD64=<sha> \
  image-local
```

Direct `docker buildx bake` calls must set `WHMCS_RELEASE`; the wrapper reads
`WHMCS_VERSION.txt` and `PHP_VERSION.txt` and forwards any extra bake args.

The first build prints `SHA256:` lines for each loader download; copy those
values into the matching `*_SHA256_*` build args to pin against tamper in
subsequent builds.
