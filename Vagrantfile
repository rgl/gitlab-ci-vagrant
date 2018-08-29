# link to the gitlab-vagrant environment:
config_gitlab_fqdn  = 'gitlab.example.com'
config_gitlab_ip    = '10.10.9.99'
# runner nodes:
config_ubuntu_fqdn  = "ubuntu.#{config_gitlab_fqdn}"
config_ubuntu_ip    = '10.10.9.98'
config_windows_fqdn = "windows.#{config_gitlab_fqdn}"
config_windows_ip   = '10.10.9.97'

Vagrant.configure('2') do |config|
  config.vm.provider :libvirt do |lv, config|
    lv.memory = 2048
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    # lv.nested = true
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs'
  end

  config.vm.provider :virtualbox do |vb|
    vb.linked_clone = true
    vb.memory = 2048
    vb.cpus = 2
    vb.customize ['modifyvm', :id, '--cableconnected1', 'on']
  end

  config.vm.define :windows do |config|
    config.vm.provider :libvirt do |lv, config|
      lv.memory = 4096
      config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
    end
    config.vm.provider :virtualbox do |vb|
      vb.memory = 4096
    end
    config.vm.box = 'windows-2016-amd64'
    config.vm.hostname = 'windows'
    config.vm.network :private_network, ip: config_windows_ip, libvirt__forward_mode: 'route', libvirt__dhcp_enabled: false
    config.vm.provision :shell, inline: "echo '#{config_gitlab_ip} #{config_gitlab_fqdn}' | Out-File -Encoding ASCII -Append c:/Windows/System32/drivers/etc/hosts"
    config.vm.provision :shell, inline: "$env:chocolateyVersion='0.10.11'; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex", name: "Install Chocolatey"
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-dotnet.ps1'
    config.vm.provision :reload
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-base.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-vs-build-tools.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-dotnetcore-sdk.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: ['provision-gitlab-runner.ps1', config_gitlab_fqdn, config_windows_fqdn]
  end

  config.trigger.before :up do |trigger|
    trigger.run = {
      inline: '''bash -euc \'
mkdir -p tmp
artifacts=(
  ../gitlab-vagrant/tmp/gitlab.example.com-crt.der
  ../gitlab-vagrant/tmp/gitlab-runners-registration-token.txt
)
for artifact in "${artifacts[@]}"; do
  if [ -f $artifact ]; then
    cp $artifact tmp
  fi
done
\'
'''
    }
  end
end
