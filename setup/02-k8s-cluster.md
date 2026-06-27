# Yêu cầu 2: Xây dựng K8S Cluster

## Tóm tắt yêu cầu

Xây dựng **Kubernetes cluster** gồm:
- **1 Master node** (control plane)
- **1 Worker node**

Hoặc có thể dùng **Minikube** / **k3s** / **Kind** nếu tài nguyên hạn chế.

---

## Lựa chọn mô hình

### Option A: Kubeadm (2 VM — khuyến nghị cho môi trường lab)

**Yêu cầu tối thiểu:**

| Node | RAM | CPU | Disk | Role |
|---|---|---|---|---|
| master | 2 GB | 2 core | 20 GB | Control Plane |
| worker | 4 GB | 2 core | 30 GB | Worker |

> Nếu chạy YAS services trên worker: cần tối thiểu 8–16 GB RAM.

### Option B: Minikube (1 máy, phù hợp laptop)

**Yêu cầu:**
- RAM: 8 GB trở lên (cấp 4–6 GB cho Minikube)
- CPU: 4 core
- Docker hoặc VirtualBox

### Option C: k3s (lightweight, phù hợp VPS nhỏ)

**Yêu cầu:**
- 1 GB RAM cho master (k3s rất nhẹ)
- Worker tùy theo workload

---

## Option A: Cài đặt với Kubeadm

### Bước 1: Chuẩn bị cả 2 node (chạy trên TỪNG node)

```bash
# Tắt swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Cấu hình sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
```

### Bước 2: Cài containerd (runtime)

```bash
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
# Sửa SystemdCgroup = true
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### Bước 3: Cài kubeadm, kubelet, kubectl

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Bước 4: Khởi tạo cluster (chỉ trên MASTER node)

```bash
# Thay <MASTER_IP> bằng IP thực của node master
sudo kubeadm init \
  --apiserver-advertise-address=<MASTER_IP> \
  --pod-network-cidr=10.244.0.0/16

# Sau khi init thành công, setup kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Bước 5: Cài CNI plugin — Flannel

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

### Bước 6: Join worker node

Lệnh `kubeadm join` được in ra sau bước init. Chạy trên **worker node**:

```bash
sudo kubeadm join <MASTER_IP>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

> Nếu mất token, tạo lại trên master: `kubeadm token create --print-join-command`

### Bước 7: Xác nhận cluster

```bash
kubectl get nodes
# Expected:
# NAME     STATUS   ROLES           AGE   VERSION
# master   Ready    control-plane   2m    v1.29.x
# worker   Ready    <none>          1m    v1.29.x
```

---

## Option B: Cài đặt Minikube

```bash
# Cài Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Khởi động với đủ tài nguyên
minikube start --cpus=4 --memory=6144 --driver=docker

# Bật addons cần thiết
minikube addons enable ingress
minikube addons enable metrics-server

# Lấy IP của cluster (dùng cho NodePort)
minikube ip
```

---

## Option C: Cài đặt k3s

```bash
# Master node
curl -sfL https://get.k3s.io | sh -

# Lấy token để join worker
sudo cat /var/lib/rancher/k3s/server/node-token

# Worker node (thay <MASTER_IP> và <NODE_TOKEN>)
curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<NODE_TOKEN> sh -

# Trên master, copy kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

---

## Cấu hình Namespace

Sau khi cluster up, tạo các namespace cần thiết:

```bash
kubectl create namespace yas-dev
kubectl create namespace yas-staging
# Namespace cho developer build (tạo dynamically trong job hoặc pre-create)
# kubectl create namespace yas-user-<developer-id>
```

---

## Kết nối Jenkins với K8S

### Lấy kubeconfig

```bash
# Trên master node
cat ~/.kube/config
# hoặc k3s
cat /etc/rancher/k3s/k3s.yaml
```

### Thêm vào Jenkins

1. Jenkins → Manage Jenkins → Credentials → System → Global → **Add Credentials**
2. Kind: **Secret file**
3. ID: `kubeconfig-file`
4. File: upload file `~/.kube/config`

### Cài kubectl và helm trên Jenkins agent

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## Lưu ý NodePort cho developer access

- Với **kubeadm / k3s**: dùng **IP của Worker node** để truy cập NodePort.
- Với **Minikube**: dùng `minikube ip`.
- NodePort range mặc định: `30000–32767`.
- Developer thêm vào `/etc/hosts`:
  ```
  <WORKER_IP>   yas.local
  ```
  Rồi truy cập `http://yas.local:<NodePort>`.

---

## Checklist xác nhận

- [ ] `kubectl get nodes` hiển thị đủ Master + Worker, status `Ready`
- [ ] `kubectl version --client` trả về version
- [ ] `helm version` trả về version
- [ ] Jenkins credential `kubeconfig-file` đã tạo
- [ ] Jenkins agent có thể chạy `kubectl get ns` thành công
- [ ] Namespace `yas-dev` và `yas-staging` đã tạo
- [ ] Worker node IP đã xác định (dùng cho NodePort)
