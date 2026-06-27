#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace yas-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace yas-staging --dry-run=client -o yaml | kubectl apply -f -

echo "Đã tạo hoặc cập nhật namespaces:"
kubectl get ns | grep -E 'yas-dev|yas-staging' || true
