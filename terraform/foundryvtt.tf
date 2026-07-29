resource "digitalocean_droplet" "foundryvtt" {
  # image = "ubuntu-18-04-x64"
  image = "docker-20-04"
  name = "foundryvtt"
  region = "lon1"
  size = "s-2vcpu-4gb"
  ipv6 = true
  # disk = 32
  private_networking = true
  ssh_keys = [
    data.digitalocean_ssh_key.terraform.id
  ]
  connection {
    host = self.ipv4_address
    user = "root"
    type = "ssh"
    private_key = file(var.pvt_key)
    timeout = "2m"
  }

  provisioner "file" {
    source = var.data_dir
    destination = "/mnt/foundry-upload.tgz"
  }

  provisioner "file" {
    source = "../.env"
    destination = "/tmp/.env"
  }

  provisioner "file" {
    source = var.certs
    destination = "/tmp/le.tgz"
  }

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      "echo '>>>>> Setting up LetsEncrypt'",
      "sudo apt update",
      "sudo apt install -y certbot",
      "cd / && tar xf /tmp/le.tgz",
      "ufw allow http && ufw allow https",
      "echo '>>>>> Installing FoundryVTT'",
      "cd /mnt && tar xf /mnt/foundry-upload.tgz",
      "chown -R 421:421 /mnt/FoundryVTT; chmod -R 777 /mnt/FoundryVTT",
      "cd ~",
      "mkdir .config",
      "docker pull ${var.docker_image}",
      "cp /tmp/.env /mnt/FoundryVTT/.env && chmod 600 /mnt/FoundryVTT/.env && rm /tmp/.env",
      "docker run -d -v /mnt/FoundryVTT:/data -p 30000:30000 --env-file /mnt/FoundryVTT/.env ${var.docker_image}",
    ]
  }
}

# Reference to your existing domain in DigitalOcean
data "digitalocean_domain" "main" {
  name = var.domain_name
}

# Create the A record pointing to the droplet
resource "digitalocean_record" "foundryvttv4" {
  domain = data.digitalocean_domain.main.id
  type   = "A"
  name   = var.subdomain
  value  = digitalocean_droplet.foundryvtt.ipv4_address
  ttl    = 300  # 5 minutes, adjust as needed
}

# Create the AAAA record pointing to the droplet
# depends_on the A record to serialise DO API calls and avoid deadlock (Error 1213)
resource "digitalocean_record" "foundryvttv6" {
  domain = data.digitalocean_domain.main.id
  type   = "AAAA"
  name   = var.subdomain
  value  = digitalocean_droplet.foundryvtt.ipv6_address
  ttl    = 300  # 5 minutes, adjust as needed

  depends_on = [digitalocean_record.foundryvttv4]
}

resource "null_resource" "update_duckdns" {
  triggers = {
    droplet_ip = digitalocean_droplet.foundryvtt.ipv4_address
  }

  provisioner "local-exec" {
    command = "curl 'https://www.duckdns.org/update?domains=${var.duckdns_subdomain}&token=${var.duckdns_token}&ip=${digitalocean_droplet.foundryvtt.ipv4_address}'"
  }

  depends_on = [digitalocean_droplet.foundryvtt]
}

# To force cert renewal on an existing deployment without recreating the droplet, run:
#   terraform taint null_resource.renew_cert && terraform apply -auto-approve </dev/null 2>&1 | tee terraform-apply.log
resource "null_resource" "wait_for_dns" {
  triggers = {
    droplet_ip = digitalocean_droplet.foundryvtt.ipv4_address
  }

  # Poll DNS locally (no SSH connection) until the domain resolves to the new droplet IP,
  # confirming propagation has reached resolvers that Let's Encrypt validators will use.
  # This avoids both the fixed sleep and the macOS tty corruption caused by remote-exec.
  provisioner "local-exec" {
    command = <<-EOF
      TARGET="${digitalocean_droplet.foundryvtt.ipv4_address}"
      echo "Polling DNS until ${var.domain_name} resolves to $TARGET ..."
      for i in $(seq 1 60); do
        RESOLVED=$(dig ${var.domain_name} +short | grep -E '^[0-9]+\.' | head -1)
        echo "  attempt $i: got '$RESOLVED'"
        if [ "$RESOLVED" = "$TARGET" ]; then
          echo "DNS propagated."
          exit 0
        fi
        sleep 5
      done
      echo "WARNING: DNS did not propagate within 5 minutes; proceeding anyway."
      exit 0
    EOF
  }

  depends_on = [null_resource.update_duckdns]
}

resource "null_resource" "renew_cert" {
  triggers = {
    droplet_ip = digitalocean_droplet.foundryvtt.ipv4_address
  }

  connection {
    host        = digitalocean_droplet.foundryvtt.ipv4_address
    user        = "root"
    type        = "ssh"
    private_key = file(var.pvt_key)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      # Attempt cert renewal. On failure (e.g. rate-limited), log the error and
      # continue — the container restart below is unconditional so the site still
      # comes up (on the seeded cert) and the browser still opens.
      "echo '>>>>> Renewing certificate if due (within 30 days of expiry)'",
      "if certbot renew -n --standalone; then",
      "  cp /etc/letsencrypt/live/${var.domain_name}/fullchain.pem /mnt/FoundryVTT/Config/example.crt",
      "  cp /etc/letsencrypt/live/${var.domain_name}/privkey.pem /mnt/FoundryVTT/Config/example.key",
      "  chown 421:421 /mnt/FoundryVTT/Config/example.crt /mnt/FoundryVTT/Config/example.key",
      "  echo '>>>>> Certificate renewed and installed'",
      "else",
      "  echo '>>>>> WARNING: certbot renewal failed — site will use existing cert' >&2",
      "fi",
      # Always restart the container so it picks up any cert changes.
      "CONTAINER=$(docker ps -q --filter ancestor=${var.docker_image})",
      "docker stop $CONTAINER && docker rm $CONTAINER",
      "find /mnt/FoundryVTT -name '*.lock' -delete",
      "docker run -d -v /mnt/FoundryVTT:/data -p 30000:30000 --env-file /mnt/FoundryVTT/.env ${var.docker_image}",
    ]
  }

  depends_on = [null_resource.wait_for_dns]
}
