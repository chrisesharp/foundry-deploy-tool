# foundry-deploy-tool — terraform

Terraform configuration to deploy a [Foundry VTT](https://foundryvtt.com/) server as a Docker container on a DigitalOcean droplet, with automatic HTTPS via Let's Encrypt and DNS via DuckDNS.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Local machine                                          │
│                                                         │
│  install.sh                                             │
│    └── worldbundler        (packages world data)        │
│    └── terraform apply     (orchestrates everything)    │
│         ├── logs to terraform-apply.log                 │
└────────────────────────┬────────────────────────────────┘
                         │
          ┌──────────────▼──────────────┐
          │  DigitalOcean Droplet       │
          │  (docker-20-04, lon1)       │
          │                             │
          │  certbot + letsencrypt.tgz  │
          │  felddy/foundryvtt Docker   │
          │  port 30000 (HTTPS)         │
          └──────────────┬──────────────┘
                         │
          ┌──────────────▼──────────────┐
          │  DuckDNS                    │
          │  chrisesharp.duckdns.org    │
          │  → droplet IPv4             │
          └─────────────────────────────┘
```

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| `terraform` | Infrastructure provisioning |
| `worldbundler` | Packages Foundry world data into `foundry-upload.tgz` |
| `jq` | Parses Terraform JSON output in `install.sh` |
| `dig` | DNS polling during deployment (part of `dnsutils` / macOS default) |
| A DigitalOcean account + API token | Droplet and DNS hosting |
| A DuckDNS account + token | Dynamic DNS for the domain |
| An SSH key registered in DigitalOcean | Remote provisioning access |

### Environment file

All secrets are read from `../.env` (one directory above `terraform/`). The following variables must be set:

```sh
DO_KEY=<DigitalOcean API token>
PVT_KEY=<path to your SSH private key>
FOUNDRY_USERNAME=<Foundry VTT username>
FOUNDRY_PASSWORD=<Foundry VTT password>
DNS_TOKEN=<DuckDNS token>
DNS_DOMAIN=<DuckDNS subdomain, e.g. chrisesharp>
CERTS=<path to letsencrypt.tgz>
```

---

## Deployment

```sh
cd terraform
./install.sh
```

[`install.sh`](install.sh) performs these steps in order:

1. Sources `../.env` and exports all secrets as `TF_VAR_*` environment variables.
2. Runs `worldbundler` to package your Foundry world data. Aborts if this fails.
3. Runs `terraform apply -auto-approve` (with `SSH_AUTH_SOCK=` and `</dev/null`) to provision the infrastructure. All output is logged to `terraform-apply.log`.
4. If terraform succeeds, reads the droplet's IPv4 address from Terraform state and opens the Foundry URL in your browser.

### Why `SSH_AUTH_SOCK=` and `</dev/null`?

Both are needed together to prevent the local terminal from being corrupted during deployment.

**`</dev/null`** redirects terraform's stdin from `/dev/null`, telling the SSH client there is no interactive terminal to manage.

**`SSH_AUTH_SOCK=`** unsets the macOS SSH agent socket for the terraform process. Even with `</dev/null`, Terraform's embedded SSH client will still consult the SSH agent via `$SSH_AUTH_SOCK` (a Unix socket, independent of stdin). The agent handshake is what puts the terminal into raw mode and fails to restore it when the SSH session ends. Since both `connection` blocks in [`foundryvtt.tf`](foundryvtt.tf) supply `private_key` directly, the agent is never needed for authentication.

> ⚠️ **Always use the scripts** when running terraform commands that use `remote-exec` provisioners. Never call `terraform` directly in your terminal. For manual `taint`+`apply` operations, use the full invocation:
> ```sh
> SSH_AUTH_SOCK= terraform apply -auto-approve </dev/null 2>&1 | tee terraform-apply.log
> ```

If your terminal does become corrupted despite the above, run:
```sh
stty sane
```

---

## How provisioning works

Terraform creates and configures all resources in dependency order:

### 1. Droplet creation (`digitalocean_droplet.foundryvtt`)

- Creates an Ubuntu 20.04 + Docker droplet in the `lon1` region.
- Uploads `foundry-upload.tgz`, `.env`, and `letsencrypt.tgz` to the droplet.
- Runs a remote provisioner that:
  - Installs `certbot`.
  - Extracts the bundled Let's Encrypt certificates from [`letsencrypt.tgz`](letsencrypt.tgz) into `/etc/letsencrypt` — this seeds certbot with valid (if potentially stale) certs so the container can start immediately with HTTPS.
  - Opens UFW firewall rules for HTTP (80) and HTTPS (443).
  - Extracts and installs the Foundry VTT data.
  - Copies `.env` to `/mnt/FoundryVTT/.env` (mode 600) for use by both the initial container start and any subsequent restart after cert renewal.
  - Pulls and starts the `felddy/foundryvtt` Docker image on port 30000.

### 2. DNS record creation (`digitalocean_record.foundryvttv4` / `foundryvttv6`)

- Creates A and AAAA records in DigitalOcean DNS pointing `chrisesharp.duckdns.org` at the new droplet's IPv4 and IPv6 addresses.

### 3. DuckDNS update (`null_resource.update_duckdns`)

- Runs a `local-exec` curl command on the **local machine** to update DuckDNS so the domain resolves to the new droplet IP.
- Depends on the droplet being fully provisioned.

### 4. DNS propagation wait (`null_resource.wait_for_dns`)

- Runs a `local-exec` poll loop on the **local machine** (no SSH connection).
- Every 5 seconds, runs `dig chrisesharp.duckdns.org +short` and compares the result to the new droplet IP.
- Exits as soon as they match — typically 10–30 seconds.
- Falls through with a warning after 5 minutes maximum so the deploy does not hang indefinitely.
- This replaces the old fixed `sleep 60` and is more reliable: it confirms the exact DNS state that Let's Encrypt's validators will see, rather than guessing a safe wait time.

### 5. Certificate renewal (`null_resource.renew_cert`)

- Runs a `remote-exec` on the droplet **after** DNS has propagated.
- Runs `certbot renew --force-renewal --standalone` on port 80.
  - Let's Encrypt uses an HTTP-01 challenge: it fetches a token from `http://chrisesharp.duckdns.org/.well-known/acme-challenge/...` — this only succeeds once the domain resolves to the correct IP.
  - If certbot fails (e.g. Let's Encrypt rate limit), the failure is logged as a warning and provisioning continues — the container is still restarted and the browser still opens.
- If certbot succeeds, copies `fullchain.pem` (not just `cert.pem` — browsers need the full chain) and `privkey.pem` into the Foundry VTT config directory.
- Always stops and restarts the Docker container so it picks up any cert changes, using `/mnt/FoundryVTT/.env` for environment variables.

This ordering is critical. Running `certbot renew` before the DuckDNS record points at the new droplet causes the Let's Encrypt CA to time out trying to reach the challenge endpoint at the old (wrong) IP address.

> ⚠️ **Let's Encrypt rate limit**: only 5 certificates may be issued per exact domain per 168 hours. Repeated failed deploy attempts consume this quota. If rate-limited, the deploy will still complete (the browser will open) but the cert will be the seeded one from `letsencrypt.tgz` rather than a fresh one.

---

## Tearing down

```sh
cd terraform
./delete.sh
```

This runs `SSH_AUTH_SOCK= terraform destroy -auto-approve </dev/null 2>&1 | tee terraform-destroy.log` after loading secrets from `../.env`. The same tty-safe flags apply.

---

## Forcing certificate renewal on an existing deployment

Because `null_resource.renew_cert` only re-runs when the droplet IP changes, it will be
skipped on a re-apply if the droplet already exists. To force it to run again:

```sh
terraform taint null_resource.renew_cert
SSH_AUTH_SOCK= terraform apply -auto-approve </dev/null 2>&1 | tee terraform-apply.log
```

---

## Refreshing `letsencrypt.tgz` after renewal

`letsencrypt.tgz` is the seed bundle uploaded to every new droplet. It should be kept
up to date so that future deploys start with a valid cert (avoiding any window where
the site runs on an expired cert before renewal completes).

The easiest way is to run [`backup-vol.sh`](backup-vol.sh) before tearing down — it pulls
the current `/etc/letsencrypt` from the droplet, saves the old bundle as `letsencrypt.tgz.old`,
and writes the fresh one as `letsencrypt.tgz`:

```sh
./backup-vol.sh do
```

It will then prompt you to destroy the droplet.

Alternatively, do it manually:

```sh
# On the droplet
cd / && tar czf /tmp/le-fresh.tgz etc/letsencrypt

# On your local machine
scp root@<droplet-ip>:/tmp/le-fresh.tgz ./letsencrypt.tgz
```

The updated `letsencrypt.tgz` is picked up automatically on the next `./install.sh` run
via the `var.certs` variable (set from `$CERTS` in `.env`).

> ⚠️ Let's Encrypt certs expire every **90 days**. Always refresh `letsencrypt.tgz` after
> a successful deployment. The provisioner uses `--force-renewal` so it will always attempt
> a fresh cert regardless of the seed bundle's age — but a valid seed means the container
> is immediately usable while renewal runs.

---

## Building a custom Docker image

[`build.sh`](build.sh) builds and pushes a custom Foundry VTT Docker image to a container registry. Specify the target cloud:

```sh
./build.sh do    # DigitalOcean registry
./build.sh ibm   # IBM Container Registry
./build.sh gke   # Google Container Registry
```

Update `var.docker_image` in [`variables.tf`](variables.tf) to use the custom image.

---

## Key files

| File | Purpose |
|------|---------|
| [`foundryvtt.tf`](foundryvtt.tf) | Main infrastructure: droplet, DNS records, DuckDNS update, DNS poll, cert renewal |
| [`variables.tf`](variables.tf) | All input variable declarations and defaults |
| [`provider.tf`](provider.tf) | DigitalOcean provider configuration |
| [`outputs.tf`](outputs.tf) | Output values (droplet IP, FQDN) |
| [`install.sh`](install.sh) | End-to-end deploy script (logs to `terraform-apply.log`) |
| [`delete.sh`](delete.sh) | Teardown script (logs to `terraform-destroy.log`) |
| [`backup-vol.sh`](backup-vol.sh) | Backs up Foundry data and refreshes `letsencrypt.tgz` from running droplet |
| [`build.sh`](build.sh) | Docker image build script |
| [`letsencrypt.tgz`](letsencrypt.tgz) | Bundled Let's Encrypt certs (seeded on every deploy — keep this fresh) |
