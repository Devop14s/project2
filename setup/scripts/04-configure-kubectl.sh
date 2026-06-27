#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <MASTER_NODE_IP>"
  exit 1
fi

master_node_ip="$1"

mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"
sed -i "s/127.0.0.1/${master_node_ip}/g" "$HOME/.kube/config"

echo "Đã cấu hình kubeconfig tại $HOME/.kube/config"
echo "Kiểm tra:"
echo "  kubectl get nodes"
