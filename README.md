# NTRIP Caster

A containerized [BKG Professional NtripCaster](https://igs.bkg.bund.de/ntrip/bkgcaster) (v2.0.48).

The BKG Professional NtripCaster is developed by the German Federal Agency for Cartography and Geodesy (BKG). It distributes GNSS correction data streams via the NTRIP protocol, supporting both NTRIP v1 and v2, TLS, LDAP authentication, Prometheus metrics, and up to 2000 simultaneous clients.

## Quick Start

```bash
docker build -t ntrip-caster .
docker run -d -p 2101:2101 --name caster ntrip-caster
```

The sourcetable is now available at `http://localhost:2101/` and the web admin interface at `http://localhost:2101/admin`.

## Docker Compose

Create a `docker-compose.yml`:

```yaml
services:
  caster:
    build: .
    ports:
      - "2101:2101"
    volumes:
      - ./conf:/usr/local/ntripcaster/conf
      - caster-logs:/usr/local/ntripcaster/logs
    restart: unless-stopped

volumes:
  caster-logs:
```

```bash
# Copy default configs to edit locally
docker run --rm ntrip-caster tar -cf - -C /usr/local/ntripcaster conf | tar xf -

# Edit the configs, then start
docker compose up -d
```

### With TLS Termination via Nginx

```yaml
services:
  caster:
    build: .
    volumes:
      - ./conf:/usr/local/ntripcaster/conf
      - caster-logs:/usr/local/ntripcaster/logs
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "443:443"
      - "2101:2101"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - caster
    restart: unless-stopped

volumes:
  caster-logs:
```

Example `nginx.conf` for TLS termination:

```nginx
events {}
stream {
    upstream caster {
        server caster:2101;
    }
    server {
        listen 443 ssl;
        listen 2101;
        ssl_certificate     /etc/nginx/certs/fullchain.pem;
        ssl_certificate_key /etc/nginx/certs/privkey.pem;
        proxy_pass caster;
    }
}
```

## Configuration

All configuration lives in `/usr/local/ntripcaster/conf/` inside the container. Mount a local directory to customize:

```bash
docker run -d -p 2101:2101 \
  -v ./conf:/usr/local/ntripcaster/conf \
  ntrip-caster
```

### ntripcaster.conf

Main configuration file. Key settings:

```conf
# Server identity
server_name caster.example.com   # Must be a resolvable hostname
location MyCompany, MyCity
name myCaster

# Listening ports
port 2101

# Passwords
encoder_password <source-upload-password>   # Used by NTRIP v1 sources
admin_password <admin-password>
oper_password <operator-password>

# Capacity limits
max_clients 1000
max_clients_per_source 1000
max_sources 40
max_admins 2

# Logging (0=errors only, 1=warnings, 2=info, 3=debug)
logfiledebuglevel 0
```

### sourcetable.dat

Defines the streams advertised in the NTRIP sourcetable. Each line is a `CAS`, `NET`, or `STR` record:

```
CAS;<host>;<port>;<identifier>;<operator>;<nmea>;<country>;<lat>;<lon>;<fallback_host>
NET;<identifier>;<operator>;<auth>;<fee>;<url>;<stream_url>;<contact>;<misc>
STR;<mount>;<city>;<format>;<format-details>;<carrier>;<system>;<network>;<country>;<lat>;<lon>;<nmea>;<solution>;<generator>;<compression>;<auth>;<fee>;<bitrate>;<misc>
```

Example for a single base station:

```
CAS;caster.example.com;2101;MyCaster;MyCompany;0;USA;40.0;-74.0;
NET;MyNetwork;MyCompany;B;N;https://example.com;none;admin@example.com;none
STR;BASE1;NewYork;RTCM 3.3;1005(30),1077(1),1087(1),1097(1),1127(1),1230(1);2;GPS+GLO+GAL+BDS;MyNetwork;USA;40.71;-74.01;0;0;Trimble Alloy;none;B;N;7000;none
ENDSOURCETABLE
```

**Note:** Do _not_ include `ENDSOURCETABLE` in the file itself -- the caster appends it automatically.

### users.aut

User credentials, one per line:

```
# username:password
admin:secretpass
source1:srcpass123
client1:clientpass
```

### groups.aut

Group definitions with optional connection limits:

```
# group:user1,user2,...[:max_connections]
admins:admin
sources:source1
clients:client1:100
```

The optional third field limits simultaneous connections for that group. Use `ip<N>` to limit per IP instead (e.g. `:ip5`).

### clientmounts.aut

Controls which groups can access which mountpoints as clients:

```
# mountpoint:group1,group2,...
/admin:admins
/oper:admins
default:clients
```

- `/admin` and `/oper` control access to the web admin interface
- `default` applies to all mountpoints without explicit rules
- `all` grants access to every mountpoint

### sourcemounts.aut

Controls which groups can push data to which mountpoints:

```
# mountpoint:group1,group2,...
default:sources
```

## Relay Streams

To relay streams from another caster, add to `ntripcaster.conf`:

```conf
relay pull -i user:pass -m /MOUNT remote-caster.example.com:2101/MOUNT
```

## Monitoring

Prometheus metrics are available at:

```
http://<host>:2101/admin?mode=stats&argument=prom&nohtml=1
```

## Volumes

| Path | Purpose |
|------|---------|
| `/usr/local/ntripcaster/conf` | Configuration files |
| `/usr/local/ntripcaster/logs` | Log files |
| `/usr/local/ntripcaster/templates` | HTML templates for web interface |

## Ports

| Port | Purpose |
|------|---------|
| 2101 | Default NTRIP caster port |

## License

The BKG Professional NtripCaster is released under the [GNU GPL v2+](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).
