#!/bin/bash
set -euxo pipefail

os_name="$(lsb_release -si)"
os_version="$(lsb_release -sr)"
config_gitlab_fqdn=$(hostname --domain)

# configure the shell runner.
# see https://docs.gitlab.com/runner/executors/shell.html
# see https://docs.gitlab.com/runner/configuration/feature-flags.html
# see https://docs.gitlab.com/ee/ci/jobs/job_logs.html#job-log-timestamps
config_gitlab_runner_authentication_token="$(
    jq -r \
        .token \
        /vagrant/tmp/gitlab-runner-authentication-token-${os_name,,}-${os_version}-shell.json)"
gitlab-runner \
    register \
    --non-interactive \
    --url "https://$config_gitlab_fqdn" \
    --token "$config_gitlab_runner_authentication_token" \
    --executor 'shell'
