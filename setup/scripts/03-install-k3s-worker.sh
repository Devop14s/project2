#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <MASTER_NODE_IP> <NODE_TOKEN>"
  exit 1
fi

master_node_ip="$1"
node_token="$2"

sudo hostnamectl set-hostname k3s-worker

curl -sfL https://get.k3s.io | \
  sudo K3S_URL="https://${master_node_ip}:6443" \
  K3S_TOKEN="${node_token}" \
  INSTALL_K3S_EXEC="agent --node-name k3s-worker" \
  sh -

echo
echo "k3s worker đã join xong."
echo "Kiểm tra:"
echo "  sudo systemctl status k3s-agent --no-pager"
