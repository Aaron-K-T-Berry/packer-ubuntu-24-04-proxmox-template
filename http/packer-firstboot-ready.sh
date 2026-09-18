#!/bin/bash
set -euxo pipefail
mkdir -p /var/lib/packer
{
  echo "=== PACKER FIRSTBOOT EARLY $(date -Is) ==="
  echo "--- enabled units ---"
  systemctl is-enabled qemu-guest-agent || true
  systemctl is-enabled ssh || true
  echo "--- restarting guest agent and ssh ---"
  systemctl restart qemu-guest-agent || systemctl start qemu-guest-agent || true
  systemctl restart ssh || systemctl start ssh || true
  echo "--- qemu-guest-agent status ---"
  systemctl status qemu-guest-agent --no-pager || true
  echo "--- SSH status ---"
  systemctl status ssh --no-pager || true
  echo "--- network interfaces ---"
  ip -4 addr show || true
  echo "--- default routes ---"
  ip route show || true
  echo "=== END PACKER FIRSTBOOT EARLY ==="
} >> /dev/tty1 2>&1
touch /var/lib/packer/firstboot-ready
