# ================================
# RHCE LAB ONE-COMMAND SETUP
# ================================

Write-Host "Creating RHCE lab environment..."

# Create lab directory
$labPath = "$PWD\rhce-lab"
New-Item -ItemType Directory -Force -Path $labPath | Out-Null
Set-Location $labPath

# Create scripts folder
New-Item -ItemType Directory -Force -Path scripts | Out-Null

# ================================
# COMMON SCRIPT
# ================================
@'
#!/usr/bin/env bash
set -eux

id ansi_user || useradd -m -G wheel ansi_user
echo "ansi_user:redhat" | chpasswd

dnf install -y sudo curl

echo "ansi_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansi_user
chmod 440 /etc/sudoers.d/ansi_user
'@ | Set-Content -Encoding ascii scripts/common.sh


# ================================
# CONTROLLER SCRIPT
# ================================
@'
#!/usr/bin/env bash
set -eux

dnf install -y ansible-core

sudo -u ansi_user ssh-keygen -t rsa -N "" \
-f /home/ansi_user/.ssh/id_rsa -q || true

mkdir -p /vagrant/keys
cp /home/ansi_user/.ssh/id_rsa.pub /vagrant/keys/

cat > /etc/ansible/hosts <<EOF
[all]
servera.example.com
serverb.example.com
serverc.example.com
serverd.example.com
EOF
'@ | Set-Content -Encoding ascii scripts/controller.sh


# ================================
# REPO SERVER SCRIPT
# ================================
@'
#!/usr/bin/env bash
set -eux

dnf install -y httpd createrepo dnf-plugins-core

mkdir -p /var/www/html/repo

dnf download --resolve --destdir /var/www/html/repo \
vim-enhanced wget tree

createrepo /var/www/html/repo

cp /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9 \
/var/www/html/RPM-GPG-KEY-myrepo

systemctl enable --now httpd
'@ | Set-Content -Encoding ascii scripts/repo.sh


# ================================
# TARGET SCRIPT
# ================================
@'
#!/usr/bin/env bash
set -eux

mkdir -p /etc/pki/rpm-gpg

curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo \
http://repo.example.com/RPM-GPG-KEY-myrepo

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo || true

cat > /etc/yum.repos.d/lab.repo <<EOF
[lab]
name=Lab Repo
baseurl=http://repo.example.com/repo/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-myrepo
EOF

dnf clean all
'@ | Set-Content -Encoding ascii scripts/target.sh


# ================================
# VAGRANTFILE
# ================================
@'
Vagrant.configure("2") do |config|
  config.vm.box = "generic/rocky9"

  machines = ["controller","repo","servera","serverb","serverc","serverd"]

  machines.each do |name|
    config.vm.define name do |node|
      node.vm.hostname = "#{name}.example.com"
      node.vm.network "public_network"

      node.vm.provider "virtualbox" do |vb|
        vb.memory = 1536
      end

      node.vm.provision "shell", path: "scripts/common.sh"

      if name == "controller"
        node.vm.provision "shell", path: "scripts/controller.sh"
      elsif name == "repo"
        node.vm.provision "shell", path: "scripts/repo.sh"
      else
        node.vm.provision "shell", path: "scripts/target.sh"
      end
    end
  end
end
'@ | Set-Content -Encoding ascii Vagrantfile


# ================================
# START LAB
# ================================
Write-Host ""
Write-Host "Starting Vagrant lab..."
Write-Host "This may take several minutes on first run..."
Write-Host ""

vagrant up

Write-Host ""
Write-Host "==================================="
Write-Host "LAB READY ✅"
Write-Host "==================================="
Write-Host ""
Write-Host "Access controller:"
Write-Host "vagrant ssh controller"
Write-Host ""
Write-Host "Cleanup lab:"
Write-Host "vagrant destroy -f"
Write-Host ""
