variable "do_token" {}
variable "pvt_key" {}
variable "foundry_user" {}
variable "foundry_password" {}
variable "data_dir" {
    type = string
    # default = "~/Dropbox/FoundryVTT"
    default = "foundry-upload.tgz"
}
variable "digitalocean_ssh_keyname" {
    type = string
    default = "mac_token"
}
variable "docker_image" {
    type = string
    default = "registry.digitalocean.com/chrisesharp/foundryvtt:11.315.1"
}
