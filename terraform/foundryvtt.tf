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
      "echo '>>>>> Setting up LetsEnrypt'",
      "sudo apt update && sudo apt install -y certbot",
      "cd / && tar xf /tmp/le.tgz",
      "ufw allow http && ufw allow https",
      "certbot renew -n",
      "echo '>>>>> Installing FoundryVTT'",
      "cd /mnt && tar xf /mnt/foundry-upload.tgz",
      "cp /etc/letsencrypt/live/${var.domain_name}/cert.pem /mnt/FoundryVTT/Config/example.crt",
      "cp /etc/letsencrypt/live/${var.domain_name}/privkey.pem /mnt/FoundryVTT/Config/example.key",
      "chown -R 421:421 /mnt/FoundryVTT; chmod -R 777 /mnt/FoundryVTT",
      "cd ~",
      "mkdir .config",
      # "wget https://github.com/digitalocean/doctl/releases/download/v1.52.0/doctl-1.52.0-linux-amd64.tar.gz",
      # "tar xf ~/doctl-1.52.0-linux-amd64.tar.gz",
      # "sudo mv ~/doctl /usr/local/bin",
      # "doctl auth init -t ${var.do_token}",
      # "doctl registry login",
      "docker pull ${var.docker_image}",
      "docker run -d -v /mnt/FoundryVTT:/data -p 30000:30000 --env-file /tmp/.env ${var.docker_image}",
      "rm /tmp/.env"
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
resource "digitalocean_record" "foundryvttv6" {
  domain = data.digitalocean_domain.main.id
  type   = "AAAA"
  name   = var.subdomain
  value  = digitalocean_droplet.foundryvtt.ipv6_address
  ttl    = 300  # 5 minutes, adjust as needed
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

# data "digitalocean_volume_snapshot" "foundryvtt" {
#   name_regex = "^foundryvtt-backup"
#   region = "lon1"
# }

# resource "digitalocean_volume" "foundryvtt" {
#   region      = "lon1"
#   name        = "FoundryVTT"
#   size        = data.digitalocean_volume_snapshot.foundryvtt.min_disk_size
#   snapshot_id = data.digitalocean_volume_snapshot.foundryvtt.id
# }

# resource "digitalocean_volume_attachment" "foundryvtt" {
#   droplet_id = digitalocean_droplet.foundryvtt.id
#   volume_id  = digitalocean_volume.foundryvtt.id
# }