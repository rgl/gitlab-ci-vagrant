#!/bin/bash
set -euxo pipefail

os_name="$(lsb_release -si)"
os_version="$(lsb_release -sr)"
config_gitlab_fqdn=$(hostname --domain)
config_gitlab_ip=$(python3 -c "import socket; print(socket.gethostbyname(\"$config_gitlab_fqdn\"))")
config_gitlab_runner_authentication_token="$(
    jq -r \
        .token \
        /vagrant/tmp/gitlab-runner-authentication-token-${os_name,,}-${os_version}-lxd.json)"

# configure the lxd runner.
# see https://docs.gitlab.com/runner/executors/custom.html
# see https://docs.gitlab.com/runner/executors/custom_examples/lxd.html
install -d /opt/gitlab-runner-lxd
install -m 444 /vagrant/ubuntu/gitlab-runner-lxd/base.sh /opt/gitlab-runner-lxd
install -m 755 /vagrant/ubuntu/gitlab-runner-lxd/config.sh /opt/gitlab-runner-lxd
install -m 755 /vagrant/ubuntu/gitlab-runner-lxd/prepare.sh /opt/gitlab-runner-lxd
install -m 755 /vagrant/ubuntu/gitlab-runner-lxd/run.sh /opt/gitlab-runner-lxd
install -m 755 /vagrant/ubuntu/gitlab-runner-lxd/cleanup.sh /opt/gitlab-runner-lxd
gitlab-runner \
    register \
    --non-interactive \
    --url "https://$config_gitlab_fqdn" \
    --token "$config_gitlab_runner_authentication_token" \
    --builds-dir /builds \
    --cache-dir /cache \
    --executor custom \
    --custom-config-exec /opt/gitlab-runner-lxd/config.sh \
    --custom-config-exec-timeout 120 \
    --custom-prepare-exec /opt/gitlab-runner-lxd/prepare.sh \
    --custom-prepare-exec-timeout 120 \
    --custom-run-exec /opt/gitlab-runner-lxd/run.sh \
    --custom-cleanup-exec /opt/gitlab-runner-lxd/cleanup.sh \
    --custom-cleanup-exec-timeout 120
