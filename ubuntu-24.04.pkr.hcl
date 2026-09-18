packer {
  required_plugins {
    proxmox = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_host" {
  type        = string
  description = "PVE hostname:port used for the API, without a scheme"
}

variable "proxmox_node_name" {
  type        = string
  description = "Proxmox node the template will be created on"
}

variable "proxmox_api_user" {
  type        = string
  description = "API user, including the realm"
}

variable "proxmox_api_password" {
  type        = string
  sensitive   = true
  description = "Password for the Proxmox API user"
}

variable "proxmox_insecure_skip_tls_verify" {
  type        = bool
  default     = true
  description = "Skip TLS verification for the Proxmox API"
}

variable "template_name" {
  type        = string
  description = "Base name for the VM and resulting template"
}

variable "template_description" {
  type        = string
  description = "Description applied to the Proxmox template"
}

variable "ssh_username" {
  type        = string
  description = "Default guest user created by autoinstall"
}

variable "ssh_password" {
  type        = string
  sensitive   = true
  description = "Plaintext password Packer uses for SSH; must match ssh_password_hash"
}

variable "ssh_password_hash" {
  type        = string
  sensitive   = true
  description = "SHA-512 hash of ssh_password for autoinstall identity"
}

variable "hostname" {
  type        = string
  description = "Hostname set during autoinstall"
}

variable "vmid" {
  type        = number
  description = "VMID used while the template is being built"
}

variable "locale" {
  type        = string
  default     = "en_US"
  description = "Installer locale"
}

variable "timezone" {
  type        = string
  default     = "UTC"
  description = "Guest timezone"
}

variable "cores" {
  type        = number
  default     = 2
  description = "vCPU cores"
}

variable "sockets" {
  type        = number
  default     = 1
  description = "CPU sockets"
}

variable "memory" {
  type        = number
  default     = 4096
  description = "RAM in MiB. Ubuntu 24.04 live-server autoinstall needs at least 4G"
}

variable "disk_size" {
  type        = string
  default     = "20G"
  description = "OS disk size"
}

variable "datastore" {
  type        = string
  description = "Storage pool for the OS disk"
}

variable "cloud_init_storage_pool" {
  type        = string
  description = "Storage pool for the cloud-init drive"
}

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Linux bridge attached to the template NIC"
}

variable "iso" {
  type        = string
  description = "ISO already present on the PVE node, for example local:iso/ubuntu-24.04.3-live-server-amd64.iso"
}

variable "ssh_timeout" {
  type        = string
  default     = "90m"
  description = "How long Packer waits for SSH after autoinstall"
}

variable "ssh_handshake_attempts" {
  type        = number
  default     = 50
  description = "SSH handshake retry attempts"
}

variable "http_bind_address" {
  type        = string
  default     = "0.0.0.0"
  description = "Address Packer's autoinstall HTTP server binds to"
}

variable "http_interface" {
  type        = string
  default     = null
  description = "Optional network interface Packer uses to determine the HTTP IP advertised to the VM"
}

locals {
  # NoCloud expects GET /user-data (exact path). Serving a .pkrtpl file from
  # http_directory would expose /user-data.pkrtpl instead, which leaves the
  # installer on the interactive language screen.
  autoinstall_user_data = templatefile("${path.root}/http/user-data.pkrtpl", {
    hostname          = var.hostname
    ssh_username      = var.ssh_username
    ssh_password_hash = var.ssh_password_hash
    locale            = var.locale
    timezone          = var.timezone
    firstboot_script  = file("${path.root}/http/packer-firstboot-ready.sh")
    firstboot_unit    = file("${path.root}/http/packer-firstboot-ready.service")
  })
}

source "proxmox-iso" "ubuntu-server-noble" {
  username                 = var.proxmox_api_user
  password                 = var.proxmox_api_password
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  task_timeout             = "10m"

  node                 = var.proxmox_node_name
  vm_id                = var.vmid
  vm_name              = "${var.template_name}-{{timestamp}}"
  template_name        = "${var.template_name}-{{timestamp}}"
  template_description = var.template_description

  boot_iso {
    type     = "scsi"
    iso_file = var.iso
    unmount  = true
  }

  qemu_agent      = true
  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size    = var.disk_size
    format       = "raw"
    storage_pool = var.datastore
    type         = "scsi"
  }

  cores   = var.cores
  sockets = var.sockets
  memory  = var.memory

  network_adapters {
    model    = "virtio"
    bridge   = var.network_bridge
    firewall = false
  }

  cloud_init              = true
  cloud_init_storage_pool = var.cloud_init_storage_pool

  boot_command = [
    "<esc><wait3>",
    "e<wait3>",
    "<down><down><down><end><wait>",
    "<bs><bs><bs><bs><wait>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]
  boot      = "c"
  boot_wait = "20s"

  communicator = "ssh"
  http_content = {
    "/user-data" = local.autoinstall_user_data
    "/meta-data" = file("${path.root}/http/meta-data")
  }
  http_bind_address = var.http_bind_address
  http_interface    = var.http_interface

  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = var.ssh_timeout
  ssh_handshake_attempts = var.ssh_handshake_attempts
}

build {
  name    = "ubuntu-server-noble"
  sources = ["source.proxmox-iso.ubuntu-server-noble"]

  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait --long || echo 'cloud-init status --wait returned non-zero, checking boot-finished file...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo systemctl disable --now packer-firstboot-ready.service 2>/dev/null || true",
      "sudo rm -f /etc/systemd/system/packer-firstboot-ready.service",
      "sudo rm -f /usr/local/sbin/packer-firstboot-ready.sh",
      "sudo rm -rf /var/lib/packer",
      "sudo systemctl daemon-reload",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo cloud-init clean",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo rm -f /etc/netplan/00-installer-config.yaml",
      "sudo sync"
    ]
  }

  provisioner "file" {
    source      = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  provisioner "shell" {
    inline = ["sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"]
  }
}
