# Yêu cầu 2: Xây dựng K8S Cluster

## Khuyến nghị chính thức cho môi trường hiện tại

Với điều kiện hiện tại là **2 máy Windows, mỗi máy chạy 1 WSL2**, lựa chọn khuyến nghị chính thức là:

- **Dùng `k3s`**
- **1 WSL trên máy A làm `master` (control-plane)**
- **1 WSL trên máy B làm `worker`**

Đây là phương án phù hợp nhất để:

- Đúng yêu cầu bài: có **1 master + 1 worker**
- Dễ triển khai hơn `kubeadm` trên WSL
- Nhẹ tài nguyên hơn `kubeadm`
- Dễ chứng minh kết quả để nộp bài và đạt điểm tối đa

> Kết luận: với môi trường lab chạy trên WSL, **ưu tiên `k3s`** thay vì `kubeadm`. `Minikube` chỉ nên dùng khi không thể dựng cluster 2 node.

---

## Vì sao chọn k3s thay vì kubeadm

### `k3s` phù hợp hơn trên WSL vì:

- Cài đặt ngắn gọn, ít bước hơn
- Nhẹ hơn, ổn định hơn với tài nguyên laptop
- Ít lỗi hơn khi chạy trên WSL2
- Vẫn là cluster thật gồm **control-plane** và **worker**

### `kubeadm` không phải lựa chọn tốt nhất trên WSL vì:

- Cần cấu hình nhiều hơn
- Dễ vướng `swap`, `containerd`, `cgroup`, `CNI`, `systemd`
- Tốn thời gian debug, rủi ro cao trước lúc demo hoặc nộp bài

---

## Kiến trúc triển khai đề xuất

| Máy | WSL | Vai trò | Ghi chú |
|---|---|---|---|
| Windows máy A | Ubuntu WSL2 | `master` | Chạy `k3s server` |
| Windows máy B | Ubuntu WSL2 | `worker` | Join vào cluster |

### Yêu cầu tối thiểu đề xuất

| Node | RAM khả dụng | CPU | Disk |
|---|---|---|---|
| master | 2 GB | 2 core | 20 GB |
| worker | 4 GB | 2 core | 20–30 GB |

> Nếu còn chạy thêm Jenkins, image build hoặc nhiều pod ứng dụng, nên cấp dư RAM cho WSL.

---

## Điều kiện cần trước khi cài

Thực hiện trên **cả 2 máy Windows**:

- Đã cài **WSL2**
- Dùng Ubuntu `22.04` hoặc `24.04`
- WSL có kết nối mạng giữa 2 máy
- Khuyến nghị bật **WSL mirrored networking**
- Biết **IP của WSL node master** và **IP của WSL node worker**

### Khuyến nghị bắt buộc về network

Để dựng **cluster 2 node trên 2 máy Windows khác nhau**, nên dùng:

- **WSL mirrored networking** trên cả 2 máy

Lý do:

- `k3s` multi-node cần các node nhìn thấy nhau trực tiếp
- Overlay network của cluster cần giao tiếp qua mạng thật
- Cách này ổn định hơn nhiều so với NAT mặc định của WSL2

### Bật mirrored networking trên Windows

Trên **mỗi máy Windows**, sửa file:

```text
%UserProfile%\.wslconfig
```

Thêm nội dung:

```ini
[wsl2]
networkingMode=mirrored
```

Sau đó chạy:

```powershell
wsl --shutdown
```

Mở lại WSL rồi kiểm tra IP của node:

```bash
hostname -I
```

Ghi lại:

- IP của WSL trên **máy A**: dùng làm địa chỉ `master`
- IP của WSL trên **máy B**: dùng để kiểm tra node `worker`

### Nếu không bật được mirrored networking

Không khuyến nghị dựng cluster 2 node trên 2 máy WSL khác nhau bằng NAT mặc định, vì dễ lỗi giao tiếp node-to-node và pod network. Khi đó nên:

- Chuyển sang mirrored networking trước
- Hoặc đổi môi trường sang VM/Linux thật

### Kiểm tra IP node trong WSL

Mở terminal trong **WSL**:

```bash
hostname -I
```

Ghi lại địa chỉ IP dùng cho cluster:

- **node master**: dùng để worker kết nối tới master
- **node worker**: dùng để xác nhận cluster và debug khi cần

> Trong tài liệu bên dưới, ký hiệu `<MASTER_NODE_IP>` là IP của **WSL master** sau khi đã bật mirrored networking.

---

## Bước 1: Bật `systemd` trong WSL

Thực hiện trên **cả master và worker**:

```bash
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF
```

Từ Windows PowerShell:

```powershell
wsl --shutdown
```

Sau đó mở lại WSL và kiểm tra:

```bash
systemctl is-system-running
```

Nếu chưa báo `running` nhưng các service khởi động được thì vẫn có thể tiếp tục.

### Cách nhanh bằng script trong repo

Chạy trong WSL:

```bash
chmod +x setup/scripts/01-enable-systemd.sh
./setup/scripts/01-enable-systemd.sh
```

---

## Bước 2: Chuẩn bị firewall và network

Để `worker` join được `master`, cần đảm bảo:

- Windows firewall cho phép inbound `TCP 6443`
- Windows firewall cho phép `UDP 8472`
- Windows firewall cho phép `TCP 10250`

### Tóm tắt port quan trọng

| Port | Giao thức | Mục đích |
|---|---|---|
| 6443 | TCP | Kubernetes API server |
| 8472 | UDP | Flannel VXLAN |
| 10250 | TCP | Kubelet API |

> Nếu đang bật Windows Defender Firewall, cần tạo rule cho các port trên để tránh lỗi node không `Ready`.

Ví dụ mở rule trên Windows PowerShell (Run as Administrator):

```powershell
New-NetFirewallRule -DisplayName "k3s-6443" -Direction Inbound -Protocol TCP -LocalPort 6443 -Action Allow
New-NetFirewallRule -DisplayName "k3s-8472" -Direction Inbound -Protocol UDP -LocalPort 8472 -Action Allow
New-NetFirewallRule -DisplayName "k3s-10250" -Direction Inbound -Protocol TCP -LocalPort 10250 -Action Allow
```

Hoặc dùng script:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup\scripts\windows-open-firewall.ps1
```

---

## Bước 3: Cài `k3s server` trên master

Thực hiện trên **WSL của máy A**.

### 3.1 Đặt hostname dễ nhận biết

```bash
sudo hostnamectl set-hostname k3s-master
```

### 3.2 Cài k3s server

Thay `<MASTER_NODE_IP>` bằng IP của **WSL master**.

```bash
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="server --node-name k3s-master --bind-address 0.0.0.0 --advertise-address <MASTER_NODE_IP>" \
  sh -
```

Hoặc dùng script:

```bash
chmod +x setup/scripts/02-install-k3s-master.sh
./setup/scripts/02-install-k3s-master.sh <MASTER_NODE_IP>
```

### 3.3 Kiểm tra service

```bash
sudo systemctl status k3s --no-pager
```

### 3.4 Kiểm tra node trên master

```bash
sudo kubectl get nodes -o wide
```

Kỳ vọng ban đầu:

```text
NAME         STATUS   ROLES                  AGE   VERSION
k3s-master   Ready    control-plane,master   ...   ...
```

---

## Bước 4: Lấy token để worker join

Trên **master**:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Copy giá trị token này để dùng ở worker.

---

## Bước 5: Cài `k3s agent` trên worker

Thực hiện trên **WSL của máy B**.

### 5.1 Đặt hostname

```bash
sudo hostnamectl set-hostname k3s-worker
```

### 5.2 Join vào cluster

Thay:

- `<MASTER_NODE_IP>` bằng IP của **WSL master**
- `<NODE_TOKEN>` bằng token lấy từ master

```bash
curl -sfL https://get.k3s.io | \
  K3S_URL=https://<MASTER_NODE_IP>:6443 \
  K3S_TOKEN=<NODE_TOKEN> \
  INSTALL_K3S_EXEC="agent --node-name k3s-worker" \
  sh -
```

Hoặc dùng script:

```bash
chmod +x setup/scripts/03-install-k3s-worker.sh
./setup/scripts/03-install-k3s-worker.sh <MASTER_NODE_IP> <NODE_TOKEN>
```

### 5.3 Kiểm tra service trên worker

```bash
sudo systemctl status k3s-agent --no-pager
```

---

## Bước 6: Xác nhận cluster 2 node

Trên **master**:

```bash
sudo kubectl get nodes -o wide
```

Kết quả mong đợi:

```text
NAME         STATUS   ROLES                  AGE   VERSION   INTERNAL-IP
k3s-master   Ready    control-plane,master   ...   ...       ...
k3s-worker   Ready    <none>                 ...   ...       ...
```

Kiểm tra thêm system pods:

```bash
sudo kubectl get pods -A
```

Cluster đạt yêu cầu khi:

- Có đủ **2 node**
- Cả 2 đều ở trạng thái `Ready`
- Các pod hệ thống như `coredns`, `metrics-server`, `local-path-provisioner`, `helm-install-traefik` hoặc `traefik` chạy ổn định

---

## Bước 7: Thiết lập `kubectl` cho user hiện tại

Trên **master**:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sed -i 's/127.0.0.1/<MASTER_NODE_IP>/g' $HOME/.kube/config
```

Hoặc dùng script:

```bash
chmod +x setup/scripts/04-configure-kubectl.sh
./setup/scripts/04-configure-kubectl.sh <MASTER_NODE_IP>
```

Sau đó kiểm tra:

```bash
kubectl get nodes
```

> Bước thay `127.0.0.1` là rất quan trọng nếu file `kubeconfig` sẽ được dùng từ Jenkins hoặc từ máy khác.

---

## Bước 8: Tạo namespace đúng yêu cầu

Trên **master**:

```bash
kubectl create namespace yas-dev
kubectl create namespace yas-staging
```

Hoặc dùng script:

```bash
chmod +x setup/scripts/05-create-namespaces.sh
./setup/scripts/05-create-namespaces.sh
```

Kiểm tra:

```bash
kubectl get ns
```

Nếu cần namespace theo developer:

```bash
kubectl create namespace yas-user-demo
```

---

## Bước 9: Kết nối Jenkins với K8S

### 9.1 Lấy kubeconfig từ master

```bash
cat ~/.kube/config
```

Hoặc copy file:

```bash
cp ~/.kube/config /tmp/kubeconfig-k3s
```

### 9.2 Add credential trong Jenkins

1. `Manage Jenkins`
2. `Credentials`
3. `System`
4. `Global credentials`
5. `Add Credentials`

Chọn:

- Kind: **Secret file**
- ID: `kubeconfig-file`
- File: upload file kubeconfig lấy từ master

### 9.3 Kiểm tra Jenkins agent có dùng được kubeconfig

Ví dụ trong pipeline hoặc shell của Jenkins agent:

```bash
export KUBECONFIG=$WORKSPACE/kubeconfig
kubectl get ns
```

---

## Bước 10: Chuẩn bị bằng chứng để nộp bài

Để đạt điểm tối đa, nên chụp màn hình hoặc lưu output của các lệnh sau.

### Bằng chứng bắt buộc

```bash
kubectl get nodes -o wide
kubectl get ns
kubectl get pods -A
kubectl cluster-info
```

### Bằng chứng Jenkins

- Credential `kubeconfig-file` đã tạo
- Pipeline chạy được `kubectl get ns`
- Nếu có deploy app, chụp thêm:

```bash
kubectl get deploy -A
kubectl get svc -A
kubectl get ingress -A
```

---

## Nội dung nên ghi vào báo cáo

Có thể dùng mẫu mô tả ngắn sau:

> Nhóm triển khai Kubernetes cluster theo mô hình 2 node gồm 1 control-plane và 1 worker. Do môi trường thực tế là 2 máy Windows sử dụng WSL2, nhóm chọn `k3s` thay cho `kubeadm` để giảm chi phí tài nguyên, tăng tính ổn định và phù hợp với môi trường lab. Kết quả triển khai cho thấy cluster hoạt động ổn định, 2 node đều ở trạng thái `Ready`, các namespace yêu cầu đã được tạo và Jenkins có thể kết nối đến cluster thông qua `kubeconfig`.

---

## Checklist hoàn thành

- [ ] Có **2 máy Windows** khác nhau
- [ ] Mỗi máy có **1 WSL2 Ubuntu**
- [ ] `systemd` đã bật trên cả 2 WSL
- [ ] `k3s server` chạy trên master
- [ ] `k3s agent` join thành công trên worker
- [ ] `kubectl get nodes` hiển thị đủ **master + worker**
- [ ] Cả 2 node đều `Ready`
- [ ] Đã tạo `yas-dev`
- [ ] Đã tạo `yas-staging`
- [ ] Jenkins đã có credential `kubeconfig-file`
- [ ] Jenkins agent chạy được `kubectl get ns`
- [ ] Đã chụp đủ ảnh màn hình / log để nộp bài

---

## Lưu ý xử lý lỗi thường gặp trên WSL

### Worker không join được master

Kiểm tra:

- Dùng đúng **IP LAN của Windows máy A**
- Port `6443` mở trên Windows máy A
- Hai máy ping thấy nhau
- Token không bị copy thiếu

### Node join rồi nhưng không `Ready`

Kiểm tra:

- Port `8472/UDP` có bị firewall chặn không
- `k3s` hoặc `k3s-agent` có đang chạy không
- `kubectl get pods -A` có pod hệ thống nào lỗi không

### Jenkins không kết nối được cluster

Kiểm tra:

- Trong `kubeconfig`, server không còn là `127.0.0.1`
- Jenkins agent truy cập được `https://<MASTER_NODE_IP>:6443`
- Credential upload đúng file kubeconfig

---

## Phương án dự phòng nếu k3s không chạy được

Chỉ dùng khi thật sự bị chặn bởi môi trường:

1. Dùng **Minikube** trên 1 máy để demo chức năng Kubernetes
2. Ghi rõ trong báo cáo đây là phương án dự phòng do giới hạn môi trường

Tuy nhiên, để đẹp bài và sát yêu cầu hơn, **ưu tiên hoàn thành bằng `k3s` 2 node**.
