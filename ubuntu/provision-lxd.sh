#!/bin/bash
set -euxo pipefail

# NB lxd is already installed in the base ubuntu image, we just need to
#    configure it.

# install the zfs tools.
# NB this is not required by lxd, but are useful for us to troubleshoot zfs.
apt-get install -y zfsutils-linux

# this will be used for the lxd storage.
storage_device='/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_lxd'

# init lxd.
lxd init --preseed <<EOF
storage_pools:
  - name: default
    driver: zfs
    config:
      source: $storage_device
      zfs.pool_name: lxd
networks:
  - name: lxdbr0
    type: bridge
    config:
      ipv4.nat: true
      ipv4.address: 10.2.0.1/24
      ipv6.address: none
profiles:
  - name: default
    devices:
      root:
        type: disk
        path: /
        pool: default
      eth0:
        type: nic
        nictype: bridged
        parent: lxdbr0
EOF

# show the iptables state.
iptables-save

# show the zfs state.
zpool list
zpool status
zfs list
