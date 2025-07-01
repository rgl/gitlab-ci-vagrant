#!/bin/bash
set -euxo pipefail

config_gitlab_ip_address="$1"

# configure systemd do use the gitlab dns server.
install -d /etc/systemd/resolved.conf.d
cat >/etc/systemd/resolved.conf.d/local.conf <<EOF
[Resolve]
DNS=$config_gitlab_ip_address
Domains=~.
EOF
systemctl restart systemd-resolved
resolvectl status
