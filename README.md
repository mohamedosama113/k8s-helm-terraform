<h1>Kubernetes Cluster Setup with NGINX Deployment</h1>
<h2>Introduction</h2>
<p>This project aims to set up a Kubernetes cluster using kubeadm, Flannel, and Vagrant, followed by deploying an NGINX server using Helm and Terraform.</p>

<h2>Prerequisites</h2>
  <ul>
  <li><a href="https://developer.hashicorp.com/vagrant/install">Vagrant</a> and <a href="https://www.virtualbox.org/wiki/Downloads"> VirtualBox</a> installed on your system</li>
  <li><a href="https://helm.sh/docs/intro/install/">Helm</a> and <a href="https://developer.hashicorp.com/terraform/install">Terraform</a> installed on your system</li>
  <li>Basic knowledge of Kubernetes, Helm, and Terraform</li>
  </ul>

  <h2>Section 1: Create Kubernetes Cluster using kubeadm and Flannel with Vagrant
</h2>
  <h3>1) Setting up Vagrant Environment
</h3>
  <h4>-Create a new directory for your Vagrant project:
  </h4>
      <pre><code>mkdir k8s-vagrant
cd k8s-vagrant</code></pre>
  <h4>-Creating Vagrantfile:</h4>
<pre>
<code>
Vagrant.configure("2") do |config|
  config.vm.define "master" do |master|
    master.vm.box = "ubuntu/bionic64"
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.50.10"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
    end
  end

  (1..2).each do |i|
   config.vm.define "worker#{i}" do |worker|
      worker.vm.box = "ubuntu/bionic64"
      worker.vm.hostname = "worker#{i}"
      worker.vm.network "private_network", ip: "192.168.50.1#{i + 0}"
      worker.vm.provider "virtualbox" do |vb|
        vb.memory = "2048"
        vb.cpus = 2
      end
    end
  end
end
</code>
</pre>

<h4>-Start the Vagrant machines:</h4>
  <pre><code>vagrant up</code></pre>

  <h2>Kubeadm Cluster Installation</h2>
  <h3>On Master Node and All Worker Nodes:
</h3>
<h4>SSH using vagrant</h4>
<pre><code>vagrant ssh master</code></pre>
<pre><code>vagrant ssh worker1</code></pre>
<pre><code>vagrant ssh worker2</code></pre>

<h4>Edit /etc/hosts file in master and 2 workers VMs </h4>
<pre><code>#Add master and workers dns entries
192.168.50.10  master
192.168.50.11  worker1
192.168.50.12  worker2
</code></pre>
<h4>Follow instructions to setup the cluster</h4>
<pre>
<code>
# Disable swap:
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
<br>
#Create config file for modules:
sudo tee /etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
<br>
#Load modules:
sudo modprobe overlay
sudo modprobe br_netfilter
<br>
#Create another config file for sysctl:
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
<br>
# Apply sysctl parameters:
sudo sysctl --system
<br>
#Update apt source list:
sudo apt-get update
<br>
#Install containerd (or Docker which contains containerd):
sudo apt-get install docker.io -y
<br>
# Configure containerd for the cgroup driver used by kubeadm (systemd):
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
<br>
# Restart and enable containerd:
sudo systemctl restart containerd
sudo systemctl enable containerd
<br>
# Install helper tools:
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
<br>
# Download the public signing key for the Kubernetes package repositories:
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
<br>
# Add the Kubernetes apt repository for v1.29:
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
<br>
# Update apt source list, install kubelet, kubeadm and kubectl and hold them at the current version:
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
</code>
</pre>
  <h3>On Master Node only:
</h3>
 
<pre>
 <code>
# Initialize the cluster:
# If you use master node and workers with 192.168.X.X subnets use pod CIDR as following:
sudo kubeadm init --apiserver-advertise-address=192.168.50.20 --pod-network-cidr=110.244.0.0/16
   <br>
# If you use any subnets (ex:10.10.X.X) use pod CIDR as following:
sudo kubeadm init --apiserver-advertise-address=10.10.X.X --pod-network-cidr=192.168.0.0/16
    <br>
#Copy the kubeconfig file to the user's home directory and change ownership:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
    <br>
# Apply network plugin:
# If you use master node and workers with 192.168.X.X subnets, apply Flannel:
kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml
    <br>
# If you use any subnets (ex:10.10.X.X), apply Calico:
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
    <br>
</code>
</pre>
  <h3>On Worker Nodes:

</h3>
 
<pre>
 <code>
#Use the kubeadm join command generated when you initialize the cluster. If you miss it, use this command to generate it:
kubeadm token create --print-join-command
<br>
#Use the generated command on worker nodes to join the cluster.
# something like that
# kubeadm join 192.168.50.10:6443 --token zbgmvn.oc1keoodyvdqrnko \
        --discovery-token-ca-cert-hash sha256:acbc86ffda15234ceb3493a81d10ef5d9601eee59c548303c7251a90336031fe
</code>
</pre>
<h2>Prepare helm chart for nginx befor deploy it</h2>
<h3>Create a Helm Chart for Nginx using below command:</h3>
<pre>
 <code>
helm create nginx-chart
 </code>
</pre>
<h3>Helm will create a new directory in your project called nginc-hart with the structure shown below.</h3>



