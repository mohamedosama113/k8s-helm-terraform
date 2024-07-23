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

  <h3></h3>

