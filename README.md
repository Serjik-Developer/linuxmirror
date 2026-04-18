# linuxmirror.host

Decoy website + authenticated reverse proxy for Linux distribution repositories.  
The static site poses as a public mirror; actual proxying requires credentials.

## How it works

```
browser / apt / pacman / VLESS client
        │
        │ TCP :443
        ▼
  Nginx stream  ──── tcp passthrough ──────────────► Xray Reality :3050
  (no TLS)                                                  │
                                                ├── VLESS → tunnel
                                                │
                                                └── non-VLESS (fallback)
                                                         │
                                                         ▼
                                                   Nginx HTTP :8080
                                                         │
                                                 ├── /           → static site
                                                 ├── /ubuntu/    ┐ Basic Auth
                                                 ├── /debian/    ├► proxy upstream
                                                 └── ...         ┘
```

Nginx stream не трогает TLS — передаёт сырой TCP в Xray.  
Xray сам различает VLESS от обычного HTTPS и делает fallback на nginx :8080.

The `Authorization` header is stripped before forwarding to upstream — credentials never leave your server.

---

## Project structure

```
linuxmirror/
├── index.html              # public website
├── style.css
├── app.js
├── add-user.sh             # credential management
└── nginx/
    ├── stream.conf         # include inside stream {} — tcp proxy :443 → Xray :3050
    ├── linuxmirror.conf    # include inside http {}  — website + mirror on :8080
    └── .htpasswd           # created by add-user.sh, never commit this
```

---

## Setup

### 1. Nginx — stream block (tcp proxy on 443)

В главном `nginx.conf` добавить блок `stream` на том же уровне что и `http`:

```nginx
stream {
    include /etc/nginx/stream.conf;
}
```

Убедиться что модуль есть:
```bash
nginx -V 2>&1 | grep -- --with-stream
```

### 2. Nginx — http block (website + mirror on 8080)

```bash
cp nginx/linuxmirror.conf /etc/nginx/conf.d/linuxmirror.conf
cp index.html style.css app.js /var/www/linuxmirror/
nginx -t && systemctl reload nginx
```

### 3. Xray inbound config

```json
{
  "port": 3050,
  "listen": "127.0.0.1",
  "protocol": "vless",
  "settings": {
    "clients": [{ "id": "...", "flow": "xtls-rprx-vision" }],
    "decryption": "none",
    "fallbacks": [
      { "dest": "127.0.0.1:8080" }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "dest": "127.0.0.1:8080",
      "serverNames": ["linuxmirror.host"],
      "privateKey": "...",
      "shortIds": ["..."]
    }
  }
}
```

> `dest` в `realitySettings` — откуда Xray берёт TLS-ответ для маскировки (наш nginx :8080).  
> `fallbacks.dest` — куда идёт не-VLESS трафик (тот же nginx :8080).

### 4. Create the first user

```bash
./add-user.sh myuser
nginx -s reload
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
# website accessible (200)
curl -I https://linuxmirror.host/

# mirror returns 401 without credentials
curl -I https://linuxmirror.host/ubuntu/dists/noble/Release

# mirror returns 200 with credentials
curl -I https://USER:PASS@linuxmirror.host/ubuntu/dists/noble/Release

# check nginx sees correct dest port
ss -tlnp | grep 3050
```
