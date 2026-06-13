# ==========================================
# RHCE LAB MANAGER SCRIPT
# ==========================================

$labPath = Join-Path $PWD "rhce-lab"

function Create-Lab {
    Write-Host "Creating RHCE Lab..." -ForegroundColor Cyan

    if (!(Test-Path $labPath)) {
        New-Item -ItemType Directory -Path $labPath | Out-Null
    }

    Set-Location $labPath

    if (!(Test-Path "Vagrantfile")) {

        Write-Host "Generating Vagrantfile..." -ForegroundColor Yellow

@'
Vagrant.configure("2") do |config|
  config.vm.box = "generic/rocky9"

  config.vm.define "controller" do |node|
    node.vm.hostname = "controller.example.com"
    node.vm.network "public_network"
  end

  config.vm.define "repo" do |node|
    node.vm.hostname = "repo.example.com"
    node.vm.network "public_network"
  end

  config.vm.define "servera" do |node|
    node.vm.hostname = "servera.example.com"
    node.vm.network "public_network"
  end

  config.vm.define "serverb" do |node|
    node.vm.hostname = "serverb.example.com"
    node.vm.network "public_network"
  end

  config.vm.define "serverc" do |node|
    node.vm.hostname = "serverc.example.com"
    node.vm.network "public_network"
  end

  config.vm.define "serverd" do |node|
    node.vm.hostname = "serverd.example.com"
    node.vm.network "public_network"
  end
end
'@ | Set-Content -Encoding ascii "Vagrantfile"

    }

    Write-Host ""
    Write-Host "Starting lab in proper order..." -ForegroundColor Green

    vagrant up controller
    vagrant up repo
    vagrant up servera serverb serverc serverd

    Write-Host ""
    Write-Host "✅ LAB CREATED SUCCESSFULLY"
}

function Destroy-Lab {
    if (!(Test-Path $labPath)) {
        Write-Host "No lab found." -ForegroundColor Red
        return
    }

    Set-Location $labPath

    Write-Host "Destroying lab..." -ForegroundColor Red
    vagrant destroy -f

    Write-Host "✅ Lab destroyed"
}

function Show-Menu {
    Write-Host ""
    Write-Host "==== RHCE LAB MENU ====" -ForegroundColor Cyan
    Write-Host "1. Create Lab"
    Write-Host "2. Destroy Lab"
    Write-Host "3. Exit"
    Write-Host ""

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" { Create-Lab }
        "2" { Destroy-Lab }
        "3" { exit }
        default { Write-Host "Invalid option" }
    }
}

# Run menu
while ($true) {
    Show-Menu
}
