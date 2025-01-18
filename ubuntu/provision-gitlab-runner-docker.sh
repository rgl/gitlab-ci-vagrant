#!/bin/bash
set -euxo pipefail

os_name="$(lsb_release -si)"
os_version="$(lsb_release -sr)"
config_gitlab_fqdn=$(hostname --domain)
config_gitlab_ip=$(python3 -c "import socket; print(socket.gethostbyname(\"$config_gitlab_fqdn\"))")

# let the gitlab-runner user manage docker.
usermod -aG docker gitlab-runner

# configure the docker runner.
# see https://docs.gitlab.com/runner/executors/docker.html
# see https://docs.gitlab.com/runner/configuration/feature-flags.html
# see https://docs.gitlab.com/ee/ci/jobs/job_logs.html#job-log-timestamps
config_gitlab_runner_authentication_token="$(
    jq -r \
        .token \
        /vagrant/tmp/gitlab-runner-authentication-token-${os_name,,}-${os_version}-docker.json)"
gitlab-runner \
    register \
    --non-interactive \
    --url "https://$config_gitlab_fqdn" \
    --token "$config_gitlab_runner_authentication_token" \
    --env 'FF_TIMESTAMPS=true' \
    --executor 'docker' \
    --docker-image "${os_name,,}:${os_version}" \
    --docker-extra-hosts "$config_gitlab_fqdn:$config_gitlab_ip"
