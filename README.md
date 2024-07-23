<h1>Kubernetes Cluster setup and Nginx app deployment using Helm and Terraform</h1>
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
<pre><code>
#edit hosts files using vim or nano editors
sudo vim /etc/hosts
#Add master and workers dns entries
192.168.50.10  master
192.168.50.11  worker1
192.168.50.12  worker2
#save and quit
</code></pre>
<h4>Follow instructions to setup the cluster</h4>
<pre>
<code>
# Disable swap:
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  
#Create config file for modules:
sudo tee /etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
<br>
#Load modules:
sudo modprobe overlay
sudo modprobe br_netfilter
#Create another config file for sysctl:
sudo tee /etc/sysctl.d/kubernetes.conf<br><<EOF                                       
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
<br>
#Apply sysctl parameters:
sudo sysctl --system
<br>
#Update apt source list:
sudo apt-get update
<br>
#Install containerd (or Docker which contains containerd):
sudo apt-get install docker.io -y
<br>
#Configure containerd for the cgroup driver used by kubeadm (systemd):
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
<br>
#Restart and enable containerd:
sudo systemctl restart containerd
sudo systemctl enable containerd
<br>
#Install helper tools:
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
<br>
#Download the public signing key for the Kubernetes package repositories:
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
<br>
#Add the Kubernetes apt repository for v1.29:
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
#Initialize the cluster:
#This will take some minutes
#If you use master node and workers with 192.168.X.X subnets use pod CIDR as following:(our case)
sudo kubeadm init --apiserver-advertise-address=192.168.50.10 --pod-network-cidr=10.244.0.0/16
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
#don't forget sudo
kubeadm token create --print-join-command
<br>
#Use the generated command on worker nodes to join the cluster.
# something like that
# sudo kubeadm join 192.168.50.10:6443 --token zbgmvn.oc1keoodyvdqrnko \
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
<pre>
 <code>
nginx-chart
|-- Chart.yaml
|-- charts
|-- templates
|   |-- NOTES.txt
|   |-- _helpers.tpl
|   |-- deployment.yaml
|   |-- ingress.yaml
|   `-- service.yaml
`-- values.yaml
 </code>
</pre>
<h3>Here remove all files under templates/ </h3>
<pre>
 <code>
cd nginx-chart
rm -rf templates/*
 </code>
</pre>
<h3>Update with the below files in templates folder</h3>
<h4>deployment.yaml
</h4>
<pre>
 <code>
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    {{- include "nginx-chart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "nginx-chart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "nginx-chart.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default "latest" }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
 </code>
</pre>
<h4>service.yaml
</h4>
<pre>
 <code>
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-svc
  labels:
    {{- include "nginx-chart.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "nginx-chart.selectorLabels" . | nindent 4 }}
 </code>
</pre>
<h4>_helper.tpl</h4>
<pre>
 <code>
{{/*
Expand the name of the chart.
*/}}
{{- define "nginx-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nginx-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nginx-chart.labels" -}}
helm.sh/chart: {{ include "nginx-chart.chart" . }}
{{ include "nginx-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nginx-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nginx-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ .Release.Name }}
{{- end }}
 </code>
</pre>

<h3>Now override the values.yaml file with below content: </h3>

<pre>
<code>
  replicaCount: 1
  image:
    repository: nginx
    pullPolicy: IfNotPresent
    tag: ""
  service:
    type: NodePort
    port: 80
 </code>
</pre>

<h3>Now helm chart is ready to deploy</h3>


<h2>Final Step:Deploy nginx chart with terraform</h2>

<h3>Create a new directory for your Terraform project:
</h3>
<pre>
 <code>
mkdir terraform-helm-nginx
cd terraform-helm-nginx
 </code>
</pre>
<h3>Copy.kube config folder from master node to terraform-helm-nginx folder
</h3>
<pre>
 <code>
#SSH to master node
vagrant ssh master
cat ~/.kube/config
   #copy the output
   #On terraform-helm-nginx folder create folder with name .kube
   mkdir .kube
   cd .kube
   vim config
   #put the output here and save file
 </code>
</pre>
<h3>Create the main.tf file in terraform-helm-nginx folder with the following configuration:
</h3>

<pre>
 <code>
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0"
}

provider "kubernetes" {
  config_path = var.kube_config_path
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_path
  }
}

module "nginx" {
  source          = "../terraform-apps/nginx"
  kube_config_path = var.kube_config_path
}

resource "kubernetes_namespace" "nginx-k8s" {
  metadata {
    name = "nginx-k8s"
  }
}
 </code>
</pre>
<h3>This configuration does the following:</h3>
<ul>
<li>Specifies the required Helm and Kubernetes providers.</li>
<li>Configures the Kubernetes provider to use your kubeconfig file.</li>
<li>Configures the Helm provider to use your Kubernetes context.</li>
<li>Defines a Helm release resource to deploy the Nginx chart from the Bitnami repository.</li>
  </ul>
<h3>variables.tf for Kubernetes Cluster</h3>
<pre>
 <code>
variable "kube_config_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "./.kube/config"
}
 </code>
</pre>

<h3>outputs.tf for Kubernetes Cluster</h3>
<pre>
 <code>
output "nginx_release_name" {
  description = "The name of the Nginx Helm release"
  value       = module.nginx.nginx_release_name
}

output "nginx_release_status" {
  description = "The status of the Nginx Helm release"
  value       = module.nginx.nginx_release_status
}
 </code>
</pre>


<h2>Application Module Configuration</h2>
<h3>Create a separate directory for each application you want to deploy ex. terraform-apps</h3>
<h3>Directory Structure</h3>
<pre>
 <code>
terraform-apps/
├── nginx/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf

 </code>
</pre>

<h3>main.tf for Nginx Deployment</h3>
<pre>
 <code>
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_path
  }
}

resource "helm_release" "nginx" {
  name      = "nginx"
  chart     = "../terraform-apps/nginx/nginx-chart"  # Path to your local Helm chart
  version   = "1.16.0"          # Adjust the version if needed

  set {
    name  = "service.type"
    value = "NodePort"
  }
}
 </code>
</pre>


<h3>variables.tf for Nginx Deployment</h3>
<pre>
 <code>
variable "kube_config_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "./.kube/config"
}

 </code>
</pre>

<h3>outputs.tf for Nginx Deployment</h3>
<pre>
 <code>
output "nginx_release_name" {
  description = "The name of the Helm release"
  value       = helm_release.nginx.name
}

output "nginx_release_status" {
  description = "The status of the Helm release"
  value       = helm_release.nginx.status
}


data "kubernetes_service" "nginx" {
  metadata {
    name      = helm_release.nginx.name
    namespace = helm_release.nginx.namespace
  }
}


 </code>
</pre>

<h2>Before deploy move nginx-chart in nginx folder</h2>
<pre>
 <code>
mv nginx-chart/ terraform-app/nginx/
  </code>
</pre>
   
<h2>Deploy the Cluster and Applications</h2>
<h3>The Final Structure should be</h3>
<pre>
 <code>
project 
├── terraform-k8s-cluster/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── terraform-apps/
    └── nginx/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
    </code>
</pre>
<h3>Navigate to your main Kubernetes cluster directory:</h3>

<pre>
 <code>
cd terraform-k8s-cluster
    </code>
</pre>
<h3>Initialize Terraform:</h3>

<pre>
 <code>
terraform init
       </code>
</pre>
<h3>Apply the Terraform configuration:</h3>

<pre>
 <code>
terraform apply
 </code>
</pre>
<h4>Confirm the action by typing yes and pressing Enter.</h4>
<h2>Validate deployment</h2>
<h3>On master node run the following command to get the port of the application</h3>
<pre>
  <code>
    kubectl get svc
  </code>
</pre>
<h3>You should see this output get the port as pointed in this image (31126)</h3>
![Capture1](https://github.com/user-attachments/assets/d0434046-24e8-4001-bdc2-3742c946daad)
<h3>In your browser write the following URL</h3>
<pre><code> 
http://WorkerNodeIP:port
</code></pre>
<h3>In our example</h3>
<pre><code> 
http://192.168.50.11:31126
</code></pre>
<h3>You should see nginx server</h3>
![Capture](https://github.com/user-attachments/assets/2ba38795-72fd-400d-87f1-28e626c326bc)
