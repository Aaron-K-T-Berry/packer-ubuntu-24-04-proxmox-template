# Packer Ubuntu 24.04 Proxmox template

This repo has a Packer HCL template that creates a cloud-init enabled Ubuntu Server 24.04 Proxmox template using live-server autoinstall.

This repo has [Taskfile](https://taskfile.dev/#/) support to make running some of the common commands easier.

**See also:** [Ubuntu 18.04](https://github.com/Aaron-K-T-Berry/packer-ubuntu-proxmox-template) (legacy preseed) · [Ubuntu 20.04](https://github.com/Aaron-K-T-Berry/packer-ubuntu-20-04-proxmox-template) — see [Sibling templates](#sibling-templates) and [Differences from 20.04](#differences-from-2004).

This is a working example of a Packer Proxmox build that follows the same autoinstall architecture as the 20.04 sibling.

## How installation works

- Uses the **Ubuntu live-server ISO** with **Subiquity autoinstall** (NoCloud). Packer templates [`http/user-data.pkrtpl`](./http/user-data.pkrtpl) and serves it as `/user-data` (exact path), plus [`http/meta-data`](./http/meta-data).
- Autoinstall needs a **SHA-512** password hash in `ssh_password_hash`, plus matching plaintext in `ssh_password` for Packer SSH. See [Autoinstall password hash](#autoinstall-password-hash).
- The builder sets **`cloud_init = true`**. You do **not** need a `qm set` post-processor. [`files/99-pve.cfg`](./files/99-pve.cfg) prefers ConfigDrive/NoCloud for Proxmox.
- Autoinstall installs a one-shot **`packer-firstboot-ready`** helper ([`http/packer-firstboot-ready.sh`](./http/packer-firstboot-ready.sh) / [`.service`](./http/packer-firstboot-ready.service)) so qemu-guest-agent and SSH come up earlier than cloud-init runcmd alone. Packer removes that helper after it connects.
- Example defaults: **4096 MiB** RAM (minimum for 24.04 live-server autoinstall), **20G** disk, `local-lvm` for disk and cloud-init storage.

### Differences from 20.04

Compared with [packer-ubuntu-20-04-proxmox-template](https://github.com/Aaron-K-T-Berry/packer-ubuntu-20-04-proxmox-template):

- Memory default/minimum is **4096** MiB (20.04 used about 2G)
- Longer `boot_wait` and GRUB key waits; `ssh_handshake_attempts` default is **50** (20.04 used 20)
- Optional **`http_interface`** so Packer can advertise the correct HTTP IP for autoinstall
- **`packer-firstboot-ready`** oneshot installed in autoinstall late-commands, then stripped by the provisioner
- Autoinstall also installs **`python3`**

## Sibling templates

Other Ubuntu Proxmox Packer templates in this family:

| Version | Install path | Repository |
| --- | --- | --- |
| [18.04](https://github.com/Aaron-K-T-Berry/packer-ubuntu-proxmox-template) | Classic server ISO + debian-installer preseed; cloud-init via `qm set` | [packer-ubuntu-proxmox-template](https://github.com/Aaron-K-T-Berry/packer-ubuntu-proxmox-template) |
| [20.04](https://github.com/Aaron-K-T-Berry/packer-ubuntu-20-04-proxmox-template) | live-server + Subiquity autoinstall; builder-native cloud-init | [packer-ubuntu-20-04-proxmox-template](https://github.com/Aaron-K-T-Berry/packer-ubuntu-20-04-proxmox-template) |
| **24.04 (this repo)** | Same autoinstall pattern as 20.04, with 4G RAM and a firstboot helper | [packer-ubuntu-24-04-proxmox-template](https://github.com/Aaron-K-T-Berry/packer-ubuntu-24-04-proxmox-template) |

## Creating an Ubuntu Proxmox template

You can run the template with the following methods:

- [The simple way](#the-simple-way)
- [The manual way](#the-manual-way)

This template has required configuration variables in `example-vars.pkrvars.hcl`. Copy that file, fill in the values for your environment, and pass it to Packer with `-var-file`.

You need the [`Ubuntu 24.04 live server ISO`](https://releases.ubuntu.com/24.04/) already available on the PVE host. If you have [`task`](https://taskfile.dev/#/) installed you can download it locally with `task ubuntu-24-iso` and then upload it to the PVE host.

The ISO on the node must match the `iso` variable, for example `local:iso/ubuntu-24.04.3-live-server-amd64.iso`.

### The simple way

This repo uses a [Taskfile](https://taskfile.dev/#/) for common commands. You can find installation instructions for `task` [here](https://taskfile.dev/#/installation).

1. Configure template variables for your setup

   ```shell
   $ task init
   cp ./example-vars.pkrvars.hcl ./config.pkrvars.hcl
   ```

   After the task has completed, fill out `config.pkrvars.hcl` for your environment. See the [variables](#variables) section for more details.

2. Check your template file is valid

   ```shell
   $ task validate
   packer init .
   packer validate -var-file="./config.pkrvars.hcl" .
   The configuration is valid.
   ```

3. Build your Proxmox template

   ```shell
   $ task build
   packer init .
   packer build -var-file="./config.pkrvars.hcl" .
   ubuntu-server-noble.proxmox-iso.ubuntu-server-noble: output will be in this color.

   ==> ubuntu-server-noble.proxmox-iso.ubuntu-server-noble: Creating VM
   ==> ubuntu-server-noble.proxmox-iso.ubuntu-server-noble: Starting VM
   ==> ubuntu-server-noble.proxmox-iso.ubuntu-server-noble: Starting HTTP server on port 8000

   ...

   Build 'ubuntu-server-noble.proxmox-iso.ubuntu-server-noble' finished.

   ==> Builds finished. The artifacts of successful builds are:
   --> ubuntu-server-noble.proxmox-iso.ubuntu-server-noble: A template was created: 4000
   ```

4. Your template should now be available on your PVE host

### The manual way

1. Configure template variables for your setup

   ```shell
   cp ./example-vars.pkrvars.hcl ./config.pkrvars.hcl
   ```

   After copying, fill out `config.pkrvars.hcl` for your environment. See the [variables](#variables) section for more details.

2. Check your template file is valid

   ```shell
   $ packer init .
   $ packer validate -var-file="./config.pkrvars.hcl" .
   The configuration is valid.
   ```

3. Build your Proxmox template

   ```shell
   $ packer build -var-file="./config.pkrvars.hcl" .
   ubuntu-server-noble.proxmox-iso.ubuntu-server-noble: output will be in this color.

   ==> ubuntu-server-noble.proxmox-iso.ubuntu-server-noble: Creating VM
   ==> ubuntu-server-noble.proxmox-iso.ubuntu-server-noble: Starting VM
   ==> ubuntu-server-noble.proxmox-iso.ubuntu-server-noble: Starting HTTP server on port 8000

   ...

   Build 'ubuntu-server-noble.proxmox-iso.ubuntu-server-noble' finished.

   ==> Builds finished. The artifacts of successful builds are:
   --> ubuntu-server-noble.proxmox-iso.ubuntu-server-noble: A template was created: 4000
   ```

4. Your template should now be ready on your PVE host

If you had no errors building your image you should now have a Proxmox template that is cloud-init enabled. The template name is the `template_name` value plus a timestamp.

## Variables

| Variable | Description | Example |
| --- | --- | --- |
| `proxmox_host` | Hostname and port of the PVE API, without a scheme | `100.0.0.100:8006`, `pve.example.com:8006` |
| `proxmox_node_name` | Node the template will be created on | `pve-01` |
| `proxmox_api_user` | API user plus login realm | `root@pam` |
| `proxmox_api_password` | Password for that API user | `password` |
| `proxmox_insecure_skip_tls_verify` | Skip TLS verification for the Proxmox API | `true` |
| `template_name` | Base name for the VM and resulting template. Packer appends a timestamp | `ubuntu-24-04` |
| `template_description` | Description applied to the Proxmox template | `Ubuntu 24.04, generated by Packer` |
| `ssh_username` | Default guest user created by autoinstall. Packer SSH uses the same user | `packer` |
| `ssh_password` | Plaintext password Packer uses for SSH. Must match `ssh_password_hash` | `packer` |
| `ssh_password_hash` | SHA-512 hash of `ssh_password` for autoinstall identity | see `example-vars.pkrvars.hcl` |
| `hostname` | Hostname set during autoinstall | `ubuntu-24-04-cloudinit` |
| `vmid` | ID of the VM used to build the template | `4000` |
| `locale` | Installer locale | `en_US` |
| `timezone` | Guest timezone | `UTC` |
| `cores` | vCPU cores | `2` |
| `sockets` | CPU sockets | `1` |
| `memory` | RAM in MiB. Ubuntu 24.04 live-server autoinstall needs at least 4G | `4096` |
| `disk_size` | OS disk size | `20G` |
| `datastore` | Storage pool for the OS disk | `local-lvm` |
| `cloud_init_storage_pool` | Storage pool for the cloud-init drive | `local-lvm` |
| `network_bridge` | Linux bridge attached to the template NIC | `vmbr0` |
| `iso` | PVE path to the Ubuntu 24.04 live-server ISO | `local:iso/ubuntu-24.04.3-live-server-amd64.iso` |
| `ssh_timeout` | How long Packer waits for SSH after autoinstall | `90m` |
| `ssh_handshake_attempts` | SSH handshake retry attempts | `50` |
| `http_bind_address` | Address Packer's autoinstall HTTP server binds to | `0.0.0.0` |
| `http_interface` | Optional NIC Packer uses to choose the advertised HTTP IP | `eth0` |

### Autoinstall password hash

Subiquity autoinstall needs a hashed password, not the plaintext value. The example hash is for the password `packer`. Generate a replacement with:

```shell
mkpasswd -m sha-512 packer
# or
openssl passwd -6 packer
```

Put the hash in `ssh_password_hash` and keep `ssh_password` as the matching plaintext so Packer can SSH after install.

You can also change the guest user by updating `ssh_username` in your var file. The autoinstall `user-data` template reads those variables.

## Troubleshooting

### The installer stays on the language screen, or Packer times out waiting for SSH

The guest must be able to download autoinstall files from Packer's HTTP server. The boot command uses Packer's advertised `{{ .HTTPIP }}:{{ .HTTPPort }}`. If that address is not reachable from the PVE node (container IP, VPN interface, firewall), autoinstall never starts.

- Confirm `http_bind_address` is `0.0.0.0` so Packer listens on all interfaces
- Open the HTTP port Packer prints at start (`Starting HTTP server on port ...`) from the PVE node to the machine running Packer
- If Packer picked an IP the VM cannot route to, set `http_interface` to the LAN NIC Packer should advertise, or run Packer on a host the PVE bridge can reach

### The ISO is missing on the node

Upload `ubuntu-24.04.3-live-server-amd64.iso` to the storage referenced by `iso` before building. This template does not download the ISO onto PVE for you.

### SSH never comes up after install

Confirm `ssh_password` matches `ssh_password_hash`, that `memory` is at least `4096`, and that the live-server ISO is 24.04 (Subiquity autoinstall). Autoinstall installs a one-shot first-boot helper that restarts qemu-guest-agent and SSH; Packer removes that helper after it connects.

## Notes

- This template is intended for `ubuntu-24.04.3-live-server-amd64.iso` (live-server only; classic debian-installer ISOs will not work)
- You can change the OS install by editing [`http/user-data.pkrtpl`](./http/user-data.pkrtpl)
- The builder enables cloud-init on the Proxmox template directly. You do not need a separate `qm set` post-processor
- Keep `memory` at least **4096** for 24.04 live-server autoinstall
- Autoinstall installs **`packer-firstboot-ready`** for earlier QGA/SSH; the provisioner removes it after Packer connects. Optional **`http_interface`** helps when Packer's advertised HTTP IP is wrong
- `config.pkrvars.hcl` is gitignored. Keep real API passwords out of git
