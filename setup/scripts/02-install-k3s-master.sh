#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <MASTER_NODE_IP>"
  exit 1
fi

master_node_ip="$1"

sudo hostnamectl set-hostname k3s-master

curl -sfL https://get.k3s.io | \
  sudo INSTALL_K3S_EXEC="server --node-name k3s-master --bind-address 0.0.0.0 --advertise-address ${master_node_ip}" \
  sh -

echo
echo "k3s master đã cài xong."
echo "Kiểm tra:"
echo "  sudo systemctl status k3s --no-pager"
echo "  sudo kubectl get nodes -o wide"
echo
echo "Lấy token join worker:"
echo "  sudo cat /var/lib/rancher/k3s/server/node-token"
