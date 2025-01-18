#!/bin/bash
set -euxo pipefail

os_name="$(lsb_release -si)"
os_version="$(lsb_release -sr)"
config_gitlab_fqdn=$(hostname --domain)
config_gitlab_ip=$(python3 -c "import socket; print(socket.gethostbyname(\"$config_gitlab_fqdn\"))")
config_gitlab_runner_authentication_token="$(
    jq -r \
        .token \
        /vagrant/tmp/gitlab-runner-authentication-token-${os_name,,}-${os_version}-incus.json)"

# configure the incus runner.
# see https://docs.gitlab.com/runner/executors/custom.html
# see https://docs.gitlab.com/runner/executors/custom_examples/incus.html
# see https://docs.gitlab.com/runner/configuration/feature-flags.html
# see https://docs.gitlab.com/ee/ci/jobs/job_logs.html#job-log-timestamps
install -d /opt/gitlab-runner-incus
install -m 444 /vagrant/ubuntu/gitlab-runner-incus/base.sh /opt/gitlab-runner-incus
install -m 755 /vagrant/ubuntu/gitlab-runner-incus/config.sh /opt/gitlab-runner-incus
install -m 755 /vagrant/ubuntu/gitlab-runner-incus/prepare.sh /opt/gitlab-runner-incus
install -m 755 /vagrant/ubuntu/gitlab-runner-incus/run.sh /opt/gitlab-runner-incus
install -m 755 /vagrant/ubuntu/gitlab-runner-incus/cleanup.sh /opt/gitlab-runner-incus
gitlab-runner \
    register \
    --non-interactive \
    --url "https://$config_gitlab_fqdn" \
    --token "$config_gitlab_runner_authentication_token" \
    --env 'FF_TIMESTAMPS=true' \
    --builds-dir /builds \
    --cache-dir /cache \
    --executor custom \
    --custom-config-exec /opt/gitlab-runner-incus/config.sh \
    --custom-config-exec-timeout 120 \
    --custom-prepare-exec /opt/gitlab-runner-incus/prepare.sh \
    --custom-prepare-exec-timeout 120 \
    --custom-run-exec /opt/gitlab-runner-incus/run.sh \
    --custom-cleanup-exec /opt/gitlab-runner-incus/cleanup.sh \
    --custom-cleanup-exec-timeout 120
