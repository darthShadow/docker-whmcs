WHMCS Docker Image
==================

Ready to use docker image for WHMCS environment.

## Features
-----------

* Using latest php version 7.4
* Ioncube loader ready
* Nginx server configuration for WHMCS
* Installed default cron for WHMCS
* Custom mapping volume for WHMCS installation & configuration at `/config`
* Multi-arch image supporting both `x86-64` & `arm64`
* (Optional) htpasswd-protected `/admin` pages for easy protection from bots

## Supported Architectures
--------------------------

We utilise the docker manifest for multi-platform awareness. More information is available from docker [here](https://github.com/docker/distribution/blob/master/docs/spec/manifest-v2-2.md#manifest-list).

Simply pulling `ghcr.io/darthshadow/whmcs:latest` should retrieve the correct image for your arch.

The architectures supported by this image are:

| Architecture | Available |
| :----: | :----: |
| x86-64 | ✅ |
| arm64 | ✅ |

## Usage
--------

Here are some example snippets to help you get started creating a container.

### docker-compose (recommended, [click here for more info](https://docs.docker.com/compose/compose-file/deploy/))

```yaml
---
version: "3.8"
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
    volumes:
      - /path/to/whmcs:/config
    ports:
      - 8043:80
    restart: unless-stopped
```

### docker cli ([click here for more info](https://docs.docker.com/engine/reference/commandline/cli/))

```bash
docker run -d \
  --name=whmcs \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=UTC \
  -e AUTH_USER=whmcs \
  -e AUTH_PASS=whmcs@server:2022 \
  -e WHMCS_SERVER_IP=1.1.1.1 \
  -p 8043:80 \
  -v /path/to/whmcs:/config \
  --restart unless-stopped \
  ghcr.io/darthshadow/whmcs:latest
```

## Parameters
-------------

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Function |
| :----: | --- |
| `-p 80` | WHMCS webUI (can be proxied via Nginx/Traefik/Caddy for SSL) |
| `-e PUID=1000` | for UserID |
| `-e PGID=1000` | for GroupID |
| `-e TZ=UTC` | Specify a timezone to use. Ex: UTC |
| `-e AUTH_USER=whmcs` (optional) | Username for the `/admin` pages |
| `-e AUTH_USER=whmcs@server:2022` (optional) | Password for the `/admin` pages |
| `-e WHMCS_SERVER_IP=1.1.1.1` | Required to validate your WHMCS licence (use your docker host public IP address) |
| `-v /config` | WHMCS data storage location |
