resource "digitalocean_droplet" "foundryvtt" {
  # image = "ubuntu-18-04-x64"
  image = "docker-20-04"
  name = "foundryvtt"
  region = "lon1"
  size = "s-2vcpu-4gb"
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

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      "cd /mnt && tar xf /mnt/foundry-upload.tgz",
      "chown -R 421:421 /mnt/FoundryVTT; find /mnt/FoundryVTT/ -type d -print -exec chmod u=+rwx,g=+rx {} \\;",
      "cd ~",
      "mkdir .config",
      "wget https://github.com/digitalocean/doctl/releases/download/v1.52.0/doctl-1.52.0-linux-amd64.tar.gz",
      "tar xf ~/doctl-1.52.0-linux-amd64.tar.gz",
      "sudo mv ~/doctl /usr/local/bin",
      "doctl auth init -t ${var.do_token}",
      "doctl registry login",
      "docker pull ${var.docker_image}",
      "docker run -d -v /mnt/FoundryVTT:/data -p 30000:30000 --env-file /tmp/.env ${var.docker_image}",
      "rm /tmp/.env"
    ]
  }
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