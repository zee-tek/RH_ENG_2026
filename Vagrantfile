# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/rockylinux-9"
  
  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.linked_clone = true
  end

  # ==========================================
  # 1. CONTROLLER NODE (Ansible Control Plane)
  # ==========================================
  config.vm.define "controller" do |cntl|
    cntl.vm.hostname = "controller.example.com"
    cntl.vm.network "public_network", use_dhcp_assigned_default_route: true
    
    cntl.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
    end

    cntl.vm.provision "shell", inline: <<-SHELL
      echo "=== Configuring Controller ==="
      # Standard ansi_user setup (with keys)
      useradd -m -s /bin/bash ansi_user
      echo 'ansi_user:redhat' | chpasswd
      echo "ansi_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansi_user
      sudo -u ansi_user ssh-keygen -t ed25519 -N "" -f /home/ansi_user/.ssh/id_ed25519
      mkdir -p /vagrant/.ssh_keys
      cp /home/ansi_user/.ssh/id_ed25519.pub /vagrant/.ssh_keys/controller.pub
      chmod 644 /vagrant/.ssh_keys/controller.pub

      # NEW: test_user setup (NO SSH keys generated or exported)
      useradd -m -s /bin/bash test_user
      echo 'test_user:redhat' | chpasswd
      echo "test_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/test_user

      echo -e "\n# --- RHCE LAB SERVERS START ---" >> /etc/hosts
      echo "# --- RHCE LAB SERVERS END ---" >> /etc/hosts
    SHELL
  end

  # ==========================================
  # 2. REPO SERVER NODE
  # ==========================================
  config.vm.define "reposerver" do |repo|
    repo.vm.hostname = "reposerver.example.com"
    repo.vm.network "public_network"
    
    repo.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus = 1
    end

    repo.vm.provision "shell", inline: <<-SHELL
      echo "=== Starting Curated Repo Server Provisioning ==="
      useradd -m -s /bin/bash ansi_user
      echo 'ansi_user:redhat' | chpasswd
      echo "ansi_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansi_user

      # NEW: Add test_user here (Password only)
      useradd -m -s /bin/bash test_user
      echo 'test_user:redhat' | chpasswd
      echo "test_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/test_user

      dnf install -y httpd createrepo_c
      mkdir -p /var/www/html/repo/baseos /var/www/html/repo/appstream /var/www/html/repo/keys

      if [ -f /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9 ]; then
          cp /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9 /var/www/html/repo/keys/
      fi

      dnf download -y --destdir=/var/www/html/repo/baseos wget
      dnf download -y --destdir=/var/www/html/repo/appstream tmux
      createrepo_c /var/www/html/repo/baseos
      createrepo_c /var/www/html/repo/appstream
      systemctl enable --now httpd
      chmod -R 755 /var/www/html/repo/

      mkdir -p /home/ansi_user/.ssh && chmod 700 /home/ansi_user/.ssh
      if [ -f /vagrant/.ssh_keys/controller.pub ]; then
          cp /vagrant/.ssh_keys/controller.pub /home/ansi_user/.ssh/authorized_keys
          chmod 600 /home/ansi_user/.ssh/authorized_keys
          chown -R ansi_user:ansi_user /home/ansi_user/.ssh
      fi
    SHELL
  end

  # ==========================================
  # 3. STORAGE LAB NODE
  # ==========================================
  config.vm.define "storage-lab" do |stg|
    stg.vm.hostname = "storage-lab.example.com"
    stg.vm.network "public_network"
    
    stg.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus = 1
      disk_path = File.join(File.dirname(__FILE__), 'storage_disk.vdi')
      unless File.exist?(disk_path)
        vb.customize ["createmedium", "disk", "--filename", disk_path, "--size", 1024, "--format", "VDI"]
      end
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1, "--device", 0, "--type", "hdd", "--medium", disk_path]
    end

    stg.vm.provision "shell", inline: <<-SHELL
      echo "=== Configuring Storage Lab Target ==="
      useradd -m -s /bin/bash ansi_user
      echo 'ansi_user:redhat' | chpasswd
      echo "ansi_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansi_user

      # NEW: Add test_user here (Password only)
      useradd -m -s /bin/bash test_user
      echo 'test_user:redhat' | chpasswd
      echo "test_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/test_user

      mkdir -p /home/ansi_user/.ssh && chmod 700 /home/ansi_user/.ssh
      while [ ! -f /vagrant/.ssh_keys/controller.pub ]; do sleep 2; end
      cp /vagrant/.ssh_keys/controller.pub /home/ansi_user/.ssh/authorized_keys
      chmod 600 /home/ansi_user/.ssh/authorized_keys
      chown -R ansi_user:ansi_user /home/ansi_user/.ssh
    SHELL
  end

  # ==========================================
  # 4. MANAGED LAB TARGETS (servera to servere)
  # ==========================================
  servers = {
    "servera" => "servera.example.com",
    "serverb" => "serverb.example.com",
    "serverc" => "serverc.example.com",
    "serverd" => "serverd.example.com",
    "servere" => "servere.example.com"
  }

  servers.each do |vm_name, hostname|
    config.vm.define vm_name do |node|
      node.vm.hostname = hostname
      node.vm.network "public_network"
      
      node.vm.provider "virtualbox" do |vb|
        vb.memory = 1024
        vb.cpus = 1
      end

      node.vm.provision "shell", inline: <<-SHELL
        echo "=== Configuring #{hostname} ==="
        useradd -m -s /bin/bash ansi_user
        echo 'ansi_user:redhat' | chpasswd
        echo "ansi_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansi_user

        # NEW: Add test_user here (Password only)
        useradd -m -s /bin/bash test_user
        echo 'test_user:redhat' | chpasswd
        echo "test_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/test_user

        mkdir -p /home/ansi_user/.ssh && chmod 700 /home/ansi_user/.ssh
        while [ ! -f /vagrant/.ssh_keys/controller.pub ]; do sleep 2; end
        cp /vagrant/.ssh_keys/controller.pub /home/ansi_user/.ssh/authorized_keys
        chmod 600 /home/ansi_user/.ssh/authorized_keys
        chown -R ansi_user:ansi_user /home/ansi_user/.ssh
      SHELL
    end
  end
end
