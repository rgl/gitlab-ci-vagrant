#!/bin/bash
set -eux

config_fqdn=$(hostname --fqdn)
config_gitlab_fqdn=$(hostname --domain)
config_gitlab_runner_registration_token="$(cat /vagrant/tmp/gitlab-runners-registration-token.txt)"

export DEBIAN_FRONTEND=noninteractive


#
# trust the gitlab certificate.

cp /vagrant/tmp/$config_gitlab_fqdn-crt.pem /usr/local/share/ca-certificates/$config_gitlab_fqdn.crt
update-ca-certificates


#
# install the runner.
# see https://docs.gitlab.com/runner/install/linux-repository.html

apt-get install -y --no-install-recommends curl
wget -qO- https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash
# TODO even though this installs a gitlab-runner user the daemon is running as root... why?
apt-get install -y gitlab-runner

# configure the docker runner.
# see https://docs.gitlab.com/runner/executors/docker.html
gitlab-runner \
    register \
    --non-interactive \
    --url "https://$config_gitlab_fqdn" \
    --registration-token "$config_gitlab_runner_registration_token" \
    --locked 'false' \
    --env 'GIT_SSL_NO_VERIFY=true' \
    --tag-list 'docker,ubuntu,ubuntu-18.04' \
    --description 'Docker / Ubuntu 18.04' \
    --executor 'docker' \
    --docker-image 'ubuntu:18.04'
