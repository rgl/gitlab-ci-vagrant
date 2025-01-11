# to be able to configure the hyper-v vm.
ENV['VAGRANT_EXPERIMENTAL'] = 'typed_triggers'

# NB execute apt-cache madison gitlab-runner to known the available versions.
#    also see https://gitlab.com/gitlab-org/gitlab-runner/-/tags
# renovate: datasource=gitlab-tags depName=gitlab-org/gitlab-runner
GITLAB_RUNNER_VERSION = '17.5.1'

# see https://github.com/lxc/incus/releases
# NB incus tag has a three component version number of MAJOR.MINOR.PATCH but the
#    package is versioned differently, as MAJOR.MINOR-DATE, so, we use a two
#    component version here.
#    see https://github.com/lxc/incus/issues/240#issuecomment-1853333228
# renovate: datasource=github-releases depName=lxc/incus extractVersion=v(?<version>\d+\.\d+)(\.\d+)?
INCUS_VERSION = "6.8"

# see https://linuxcontainers.org/incus/docs/main/reference/storage_drivers/#storage-drivers
# see https://linuxcontainers.org/incus/docs/main/reference/storage_btrfs/
# see https://linuxcontainers.org/incus/docs/main/reference/storage_zfs/
INCUS_STORAGE_DRIVER = "btrfs" # or zfs.

# link to the gitlab-vagrant environment:
CONFIG_GITLAB_FQDN  = 'gitlab.example.com'
CONFIG_GITLAB_IP    = '10.10.9.99'
# runner nodes:
CONFIG_UBUNTU_FQDN  = "ubuntu.#{CONFIG_GITLAB_FQDN}"
CONFIG_UBUNTU_IP    = '10.10.9.98'
CONFIG_INCUS_FQDN   = "incus.#{CONFIG_GITLAB_FQDN}"
CONFIG_INCUS_IP     = '10.10.9.97'
CONFIG_LXD_FQDN     = "lxd.#{CONFIG_GITLAB_FQDN}"
CONFIG_LXD_IP       = '10.10.9.96'
CONFIG_WINDOWS_FQDN = "windows.#{CONFIG_GITLAB_FQDN}"
CONFIG_WINDOWS_IP   = '10.10.9.95'

CONFIG_OS_DISK_SIZE_GB = 32

Vagrant.configure('2') do |config|
  config.vm.provider :libvirt do |lv, config|
    lv.memory = 2*1024
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    lv.nested = false
    lv.keymap = 'pt'
    lv.disk_bus = 'scsi'
    lv.disk_device = 'sda'
    lv.disk_driver :discard => 'unmap', :cache => 'unsafe'
    lv.machine_virtual_size = CONFIG_OS_DISK_SIZE_GB
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
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
          'pwsh',
          '-NoLogo',
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'configure-hyperv-vm.ps1',
          machine.id,
          bridges.to_json
        ) or raise "failed to configure hyper-v vm with exit code #{$?.exitstatus}"
      end
    end
  end

  config.vm.define :ubuntu do |config|
    config.vm.box = 'ubuntu-22.04-amd64'
    config.vm.hostname = CONFIG_UBUNTU_FQDN
    config.vm.network :private_network, ip: CONFIG_UBUNTU_IP, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false, hyperv__bridge: 'gitlab'
    config.vm.provision :shell, path: 'configure-hyperv-guest.sh', args: [CONFIG_UBUNTU_IP]
    config.vm.provision :shell, inline: "echo '#{CONFIG_GITLAB_IP} #{CONFIG_GITLAB_FQDN}' >>/etc/hosts"
    config.vm.provision :shell, path: 'ubuntu/provision-resize-disk.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-base.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-docker.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-docker-compose.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-powershell.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-dotnet-sdk.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-gitlab-runner.sh', args: [GITLAB_RUNNER_VERSION]
    config.vm.provision :shell, path: 'ubuntu/provision-gitlab-runner-shell.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-gitlab-runner-docker.sh'
  end

  config.vm.define :incus do |config|
    config.vm.provider :libvirt do |lv, config|
      lv.storage :file, :serial => 'incus', :size => '60G', :bus => 'scsi', :discard => 'unmap', :cache => 'unsafe'
    end
    config.vm.box = 'ubuntu-22.04-amd64'
    config.vm.hostname = CONFIG_INCUS_FQDN
    config.vm.network :private_network, ip: CONFIG_INCUS_IP, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false, hyperv__bridge: 'gitlab'
    config.vm.provision :shell, path: 'configure-hyperv-guest.sh', args: [CONFIG_INCUS_IP]
    config.vm.provision :shell, inline: "echo '#{CONFIG_GITLAB_IP} #{CONFIG_GITLAB_FQDN}' >>/etc/hosts"
    config.vm.provision :shell, path: 'ubuntu/provision-resize-disk.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-base.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-incus.sh', args: [INCUS_VERSION, INCUS_STORAGE_DRIVER]
    config.vm.provision :shell, path: 'ubuntu/provision-gitlab-runner.sh', args: [GITLAB_RUNNER_VERSION]
    config.vm.provision :shell, path: 'ubuntu/provision-gitlab-runner-incus-ubuntu.sh', args: [GITLAB_RUNNER_VERSION]
    config.vm.provision :shell, path: 'ubuntu/provision-gitlab-runner-incus.sh'
  end

  config.vm.define :lxd do |config|
    config.vm.provider :libvirt do |lv, config|
      lv.storage :file, :serial => 'lxd', :size => '60G', :bus => 'scsi', :discard => 'unmap', :cache => 'unsafe'
    end
    config.vm.box = 'ubuntu-22.04-amd64'
    config.vm.hostname = CONFIG_LXD_FQDN
    config.vm.network :private_network, ip: CONFIG_LXD_IP, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false, hyperv__bridge: 'gitlab'
    config.vm.provision :shell, path: 'configure-hyperv-guest.sh', args: [CONFIG_LXD_IP]
    config.vm.provision :shell, inline: "echo '#{CONFIG_GITLAB_IP} #{CONFIG_GITLAB_FQDN}' >>/etc/hosts"
    config.vm.provision :shell, path: 'ubuntu/provision-resize-disk.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-base.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-lxd.sh'
    config.vm.provision :shell, path: 'ubuntu/provision-gitlab-runner.sh', args: [GITLAB_RUNNER_VERSION]
    config.vm.provision :shell, path: 'ubuntu/provision-gitlab-runner-lxd-ubuntu.sh', args: [GITLAB_RUNNER_VERSION]
    config.vm.provision :shell, path: 'ubuntu/provision-gitlab-runner-lxd.sh'
  end

  config.vm.define :windows do |config|
    config.vm.provider :libvirt do |lv, config|
      lv.memory = 4*1024
      config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
    end
    config.vm.provider :hyperv do |hv|
      hv.memory = 4*1024
    end
    config.vm.box = 'windows-2022-amd64'
    config.vm.hostname = 'windows'
    config.vm.network :private_network, ip: CONFIG_WINDOWS_IP, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false, hyperv__bridge: 'gitlab'
    config.vm.provision :shell, path: 'configure-hyperv-guest.ps1', args: [CONFIG_WINDOWS_IP]
    config.vm.provision :shell, path: 'windows/ps.ps1', args: ['provision-dns-client.ps1', CONFIG_GITLAB_IP]
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-chocolatey.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-base.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-procdump-as-postmortem-debugger.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-containers-feature.ps1', reboot: true
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-docker-ce.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-docker-compose.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-vs-build-tools.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-dotnet-sdk.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: ['provision-gitlab-runner.ps1', CONFIG_GITLAB_FQDN, CONFIG_WINDOWS_FQDN, GITLAB_RUNNER_VERSION], reboot: true
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'summary.ps1'
  end

  config.trigger.before :up do |trigger|
    trigger.run = {
      inline: '''bash -euc \'
mkdir -p tmp
artifacts=(
  ../gitlab-vagrant/tmp/gitlab.example.com-crt.pem
  ../gitlab-vagrant/tmp/gitlab.example.com-crt.der
  ../gitlab-vagrant/tmp/gitlab-runner-authentication-token-*.json
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
