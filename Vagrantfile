# to be able to configure the hyper-v vm.
ENV['VAGRANT_EXPERIMENTAL'] = 'typed_triggers'

# NB execute apt-cache madison gitlab-runner to known the available versions.
#    also see https://gitlab.com/gitlab-org/gitlab-runner/-/tags
gitlab_runner_version = '15.0.0'

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
    lv.memory = 2*1024
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    lv.nested = false
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
  end

  config.vm.provider :virtualbox do |vb|
    vb.linked_clone = true
    vb.memory = 2*1024
    vb.cpus = 2
    vb.customize ['modifyvm', :id, '--cableconnected1', 'on']
  end

  config.vm.provider :hyperv do |hv, config|
    hv.linked_clone = true
    hv.memory = 2*1024
    hv.cpus = 2
    hv.enable_virtualization_extensions = false # nested virtualization.
    hv.vlan_id = ENV['HYPERV_VLAN_ID']
    # see https://github.com/hashicorp/vagrant/issues/7915
    # see https://github.com/hashicorp/vagrant/blob/10faa599e7c10541f8b7acf2f8a23727d4d44b6e/plugins/providers/hyperv/action/configure.rb#L21-L35
    config.vm.network :private_network, bridge: ENV['HYPERV_SWITCH_NAME'] if ENV['HYPERV_SWITCH_NAME']
    config.vm.synced_folder '.', '/vagrant',
      type: 'smb',
      smb_username: ENV['VAGRANT_SMB_USERNAME'] || ENV['USER'],
      smb_password: ENV['VAGRANT_SMB_PASSWORD']
    # further configure the VM (e.g. manage the network adapters).
    config.trigger.before :'VagrantPlugins::HyperV::Action::StartInstance', type: :action do |trigger|
      trigger.ruby do |env, machine|
        # see https://github.com/hashicorp/vagrant/blob/v2.2.10/lib/vagrant/machine.rb#L13
        # see https://github.com/hashicorp/vagrant/blob/v2.2.10/plugins/kernel_v2/config/vm.rb#L716
        bridges = machine.config.vm.networks.select{|type, options| type == :private_network && options.key?(:hyperv__bridge)}.map do |type, options|
          mac_address_spoofing = false
          mac_address_spoofing = options[:hyperv__mac_address_spoofing] if options.key?(:hyperv__mac_address_spoofing)
          [options[:hyperv__bridge], mac_address_spoofing]
        end
        system(
          'PowerShell',
          '-NoLogo',
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'configure-hyperv-vm.ps1',
          machine.id,
          bridges.to_json
        )
      end
    end
  end

  config.vm.define :ubuntu do |config|
    config.vm.box = 'ubuntu-20.04-amd64'
    config.vm.hostname = config_ubuntu_fqdn
    config.vm.network :private_network, ip: config_ubuntu_ip, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false, hyperv__bridge: 'gitlab'
    config.vm.provision :shell, path: 'configure-hyperv-guest.sh', args: [config_ubuntu_ip]
    config.vm.provision :shell, inline: "echo '#{config_gitlab_ip} #{config_gitlab_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, path: 'ubuntu/provision-base.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-docker.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-docker-compose.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-powershell.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-dotnet-sdk.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-gitlab-runner.sh', args: [gitlab_runner_version]
  end

  config.vm.define :windows do |config|
    config.vm.provider :libvirt do |lv, config|
      lv.memory = 4*1024
      config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
    end
    config.vm.provider :virtualbox do |vb|
      vb.memory = 4*1024
    end
    config.vm.provider :hyperv do |hv|
      hv.memory = 4*1024
    end
    config.vm.box = 'windows-2022-amd64'
    config.vm.hostname = 'windows'
    config.vm.network :private_network, ip: config_windows_ip, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false, hyperv__bridge: 'gitlab'
    config.vm.provision :shell, path: 'configure-hyperv-guest.ps1', args: [config_windows_ip]
    config.vm.provision :shell, path: 'windows/ps.ps1', args: ['provision-dns-client.ps1', config_gitlab_ip]
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-chocolatey.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-containers-feature.ps1', reboot: true
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-docker-ce.ps1'
    # config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-docker-ee.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-docker-compose.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-base.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-vs-build-tools.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-dotnet-sdk.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: ['provision-gitlab-runner.ps1', config_gitlab_fqdn, config_windows_fqdn, gitlab_runner_version], reboot: true
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'summary.ps1'
  end

  config.trigger.before :up do |trigger|
    trigger.run = {
      inline: '''bash -euc \'
mkdir -p tmp
artifacts=(
  ../gitlab-vagrant/tmp/gitlab.example.com-crt.pem
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
