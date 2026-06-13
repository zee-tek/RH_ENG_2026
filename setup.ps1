powershell -NoProfile -ExecutionPolicy Bypass -Command "
mkdir rhce-lab -Force | Out-Null;
cd rhce-lab;

# --- Create scripts folder ---
mkdir scripts -Force | Out-Null;

# --- COMMON SCRIPT ---
@'
#!/usr/bin/env bash
set -eux
id ansi_user || useradd -m -G wheel ansi_user
echo 'ansi_user:redhat' | chpasswd
dnf install -y sudo curl
echo 'ansi_user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansi_user
chmod 440 /etc/sudoers.d/ansi_user
'@ | Out-File scripts/common.sh -Encoding ascii

# --- CONTROLLER SCRIPT ---
@'
#!/usr/bin/env bash
set -eux
dnf install -y ansible-core

sudo -u ansi_user ssh-keygen -t rsa -N '' -f /home/ansi_user/.ssh/id_rsa -q || true

mkdir -p /vagrant/keys
cp /home/ansi_user/.ssh/id_rsa.pub /vagrant/keys/

cat > /etc/ansible/hosts <<EOF
[all]
servera.example.com
serverb.example.com
serverc.example.com
serverd.example.com
EOF
'@ | Out-File scripts/controller.sh -Encoding ascii

# --- REPO SERVER SCRIPT ---
@'
#!/usr/bin/env bash
set -eux
dnf install -y httpd createrepo dnf-plugins-core

mkdir -p /var/www/html/repo

dnf download --resolve --destdir /var/www/html/repo \
vim-enhanced wget tree

createrepo /var/www/html/repo

cp /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9 /var/www/html/RPM-GPG-KEY-myrepo

systemctl enable --now httpd
'@ | Out-File scripts/repo.sh -Encoding ascii

# --- TARGET SCRIPT ---
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
'@ | Out-File scripts/target.sh -Encoding ascii

# --- VAGRANTFILE ---
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
'@ | Out-File Vagrantfile -Encoding ascii

# --- MAKE EXECUTABLE ---
bash -c 'chmod +x scripts/*.sh' 2>$null

# --- START LAB ---
vagrant up
"
