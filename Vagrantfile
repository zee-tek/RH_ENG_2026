# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['RH_USER'] ||= ""
ENV['RH_PASS'] ||= ""

Vagrant.configure("2") do |config|

  # ==========================================================
  # 1. AUTOMATED SUBSCRIPTION CLEAN-UP TRIGGER
  # ==========================================================
  config.trigger.before :destroy do |trigger|
    trigger.name = "Unregistering RHEL from Red Hat Portal"
    trigger.warn = "Intercepting destroy command to release Red Hat entitlement seat..."
    trigger.run_remote = { inline: "sudo subscription-manager unregister || true" }
  end

  # ==========================================================
  # 2. GLOBAL VIRTUALBOX CONFIGURATION
  # ==========================================================
  config.vm.box = "roboxes/rhel9"
  config.vm.box_version = "4.3.12" 
  
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 1
    vb.linked_clone = true 
  end

  # ==========================================================
  # 3. GLOBAL CONFIGURATION & ENVIRONMENT PROVISIONER
  # ==========================================================
  config.vm.provision "shell", args: [ENV['RH_USER'], ENV['RH_PASS']], inline: <<-SHELL
    # --------------------------------------------------------
    # Part A: Red Hat Subscription Management
    # --------------------------------------------------------
    if ! subscription-manager status >/dev/null 2>&1; then
      if [ -z "$1" ] || [ -z "$2" ]; then
        echo "======================================================================"
        echo "WARNING: Red Hat credentials not set in terminal session environment."
        echo "Skipping registration. DNF package management will be offline."
        echo "Run: export RH_USER='user' && export RH_PASS='pass' before deploying."
        echo "======================================================================"
      else
        echo "Registering to Red Hat Subscription Manager..."
        sudo subscription-manager register --username="$1" --password="$2" --auto-attach || true
      fi
    fi

    # --------------------------------------------------------
    # Part B: Create Custom Lab Accounts & Configure Passwords
    # --------------------------------------------------------
    echo "Creating lab environment user accounts..."
    
    if ! id "ansi_user" &>/dev/null; then
      sudo useradd -m -s /bin/bash ansi_user
      echo "ansi_user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansi_user
    fi
    echo "ansi_user:redhat" | sudo chpasswd

    if ! id "test_user" &>/dev/null; then
      sudo useradd -m -s /bin/bash test_user
    fi
    echo "test_user:redhat" | sudo chpasswd
    echo "vagrant:redhat" | sudo chpasswd

    # --------------------------------------------------------
    # Part C: Permanent SELinux & SSH Password Configuration
    # --------------------------------------------------------
    echo "Configuring SELinux and SSH defaults for the lab..."
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
    sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo systemctl restart sshd

    # --------------------------------------------------------
    # Part D: Two-Channel Repository Server Construction (BaseOS & AppStream)
    # --------------------------------------------------------
    if [ "$(hostname)" = "reposerver.example.com" ]; then
      echo "======================================================================"
      echo "DETECTED REPOSERVER NODE: Initializing Dual Repository Environment..."
      echo "======================================================================"
      
      # Install HTTP host server and Repository Indexing compiler tools
      sudo dnf install -y httpd createrepo_c
      
      # Create clean sub-repository folder layouts under a common parent path
      sudo mkdir -p /var/www/html/lab_repo/BaseOS
      sudo mkdir -p /var/www/html/lab_repo/AppStream
      
      # Download tmux from the active BaseOS repo channel
      echo "Downloading BaseOS assets (tmux)..."
      sudo dnf download --downloadonly --destdir=/var/www/html/lab_repo/BaseOS --repo=baseos tmux
      
      # Download mariadb-server from the active AppStream repo channel
      echo "Downloading AppStream assets (mariadb-server)..."
      sudo dnf download --downloadonly --destdir=/var/www/html/lab_repo/AppStream --repo=appstream mariadb-server
      
      # Compile independent metadata repositories for both streams
      echo "Compiling metadata indexes..."
      sudo createrepo_c /var/www/html/lab_repo/BaseOS
      sudo createrepo_c /var/www/html/lab_repo/AppStream
      
      # Fire up the firewall interfaces
      sudo systemctl start firewalld
      sudo systemctl enable firewalld
      sudo firewall-cmd --permanent --add-service=http
      sudo firewall-cmd --reload
      
      # Activate the serving engine
      sudo systemctl start httpd
      sudo systemctl enable httpd
      
      echo "Dual-channel local repository online."
      echo "BaseOS URL:     http://192.168.56.20/lab_repo/BaseOS"
      echo "AppStream URL:  http://192.168.56.20/lab_repo/AppStream"
    fi

    echo "Lab system boot configuration complete for $(hostname)."
  SHELL

  # ==========================================================
  # 4. TARGET MACHINE INSTANTIATION LAYOUT
  # ==========================================================
  
  # --- Ansible Controller Node ---
  config.vm.define "controller" do |cntl|
    cntl.vm.hostname = "controller.example.com"
    cntl.vm.network "private_network", ip: "192.168.56.10"
    cntl.vm.provider "virtualbox" do |vb|
      vb.memory = "3072" 
    end
  end

  # --- Local Repository Server ---
  config.vm.define "reposerver" do |repo|
    repo.vm.hostname = "reposerver.example.com"
    repo.vm.network "private_network", ip: "192.168.56.20"
  end

  # --- Specialized Storage Lab Node ---
  config.vm.define "storage-lab" do |stg|
    stg.vm.hostname = "storage-lab.example.com"
    stg.vm.network "private_network", ip: "192.168.56.30"
    
    stg.vm.provider "virtualbox" do |vb|
      disk_file = './storage_disk.vdi'
      unless File.exist?(disk_file)
        vb.customize ["createmedium", "disk", "--filename", disk_file, "--size", 5120]
      end
      vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1, "--device", 0, "--type", "hdd", "--medium", disk_file]
    end
  end

  # --- Managed Production Targets (servera - servere) ---
  vms = {
    "servera" => "192.168.56.11",
    "serverb" => "192.168.56.12",
    "serverc" => "192.168.56.13",
    "serverd" => "192.168.56.14",
    "servere" => "192.168.56.15"
  }

  vms.each do |name, ip|
    config.vm.define name do |machine|
      machine.vm.hostname = "#{name}.example.com"
      machine.vm.network "private_network", ip: ip
    end
  end

end
