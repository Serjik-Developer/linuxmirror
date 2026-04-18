# linuxmirror.host

Decoy website + authenticated reverse proxy for Linux distribution repositories.  
The static site poses as a public mirror; actual proxying requires credentials.

## How it works

```
client  ──HTTPS──►  nginx (your existing container)
                       │
                       ├── /            → static website (public)
                       │
                       ├── /ubuntu/     ┐
                       ├── /debian/     │  Basic Auth required
                       ├── /archlinux/  ├► proxy_pass → official upstream
                       ├── /alpine/     │
                       └── ...          ┘
```

The `Authorization` header is stripped before forwarding to upstream, so credentials never leave your server.

---

## Project structure

```
linuxmirror/
├── index.html              # public website
├── style.css
├── app.js
├── add-user.sh             # credential management
└── nginx/
    ├── upstreams.conf      # upstream blocks  → include inside http {}
    ├── locations.conf      # location blocks  → include inside server {}
    └── .htpasswd           # created by add-user.sh, never commit this
```

---

## Integration with your existing nginx container

### 1. Mount the files

Add to your existing nginx service in `docker-compose.yml`:

```yaml
services:
  nginx:
    volumes:
      - ./nginx/upstreams.conf:/etc/nginx/upstreams.conf:ro
      - ./nginx/locations.conf:/etc/nginx/locations.conf:ro
      - ./nginx/.htpasswd:/etc/nginx/.htpasswd:ro
      - ./:/var/www/html:ro
```

### 2. Edit your nginx.conf

```nginx
http {
    # ...existing settings...

    include /etc/nginx/upstreams.conf;   # ← add here

    server {
        listen 443 ssl http2;
        server_name linuxmirror.host;

        root /var/www/html;

        # ...your SSL, HSTS, etc...

        include /etc/nginx/locations.conf;  # ← add here
    }
}
```

### 3. Create the first user

```bash
./add-user.sh myuser
```

### 4. Reload nginx

```bash
docker compose exec nginx nginx -t        # verify config
docker compose exec nginx nginx -s reload
```

---

## Managing users

```bash
# add or update a user
./add-user.sh alice

# remove a user
sed -i '/^alice:/d' nginx/.htpasswd
docker compose exec nginx nginx -s reload

# list users
cut -d: -f1 nginx/.htpasswd
```

---

## Client configuration

Replace `USER` and `PASS` with the credentials created above.

### Ubuntu / Debian — apt

`/etc/apt/sources.list` or `/etc/apt/sources.list.d/linuxmirror.list`:

```
# Ubuntu 24.04
deb https://USER:PASS@linuxmirror.host/ubuntu noble main restricted universe multiverse
deb https://USER:PASS@linuxmirror.host/ubuntu noble-updates main restricted universe multiverse
deb https://USER:PASS@linuxmirror.host/ubuntu-security noble-security main restricted universe multiverse

# Ubuntu (arm64 / armhf)
deb https://USER:PASS@linuxmirror.host/ubuntu-ports noble main restricted universe multiverse

# Debian 12
deb https://USER:PASS@linuxmirror.host/debian bookworm main contrib non-free non-free-firmware
deb https://USER:PASS@linuxmirror.host/debian-security bookworm-security main
```

### Arch Linux — pacman

`/etc/pacman.d/mirrorlist`:

```
Server = https://USER:PASS@linuxmirror.host/archlinux/$repo/os/$arch
```

### Fedora — dnf

`/etc/yum.repos.d/linuxmirror.repo`:

```ini
[linuxmirror]
name=linuxmirror.host
baseurl=https://USER:PASS@linuxmirror.host/fedora/releases/$releasever/Everything/$basearch/os/
enabled=1
gpgcheck=1
```

### Alpine Linux — apk

`/etc/apk/repositories`:

```
https://USER:PASS@linuxmirror.host/alpine/v3.20/main
https://USER:PASS@linuxmirror.host/alpine/v3.20/community
```

### Rocky Linux / CentOS — dnf

```ini
[linuxmirror-rocky]
name=linuxmirror.host - Rocky Linux $releasever
baseurl=https://USER:PASS@linuxmirror.host/rocky/$releasever/BaseOS/$basearch/os/
enabled=1
gpgcheck=1
```

---

## Verify it works

```bash
# should return 401 without credentials
curl -I https://linuxmirror.host/ubuntu/dists/noble/Release

# should return 200 with credentials
curl -I https://USER:PASS@linuxmirror.host/ubuntu/dists/noble/Release
```
