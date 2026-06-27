#!/usr/bin/env bash
set -euo pipefail

sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF

echo "Đã ghi /etc/wsl.conf."
echo "Chạy 'wsl --shutdown' từ Windows PowerShell, rồi mở lại WSL."
