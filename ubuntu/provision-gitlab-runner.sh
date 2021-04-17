#!/bin/bash
set -euxo pipefail

gitlab_runner_version="${1:-13.10.0}"; shift || true
config_gitlab_fqdn=$(hostname --domain)
config_gitlab_ip=$(python3 -c "import socket; print(socket.gethostbyname(\"$config_gitlab_fqdn\"))")
config_gitlab_runner_registration_token="$(cat /vagrant/tmp/gitlab-runners-registration-token.txt)"

export DEBIAN_FRONTEND=noninteractive


#
# trust the gitlab certificate.

cp "/vagrant/tmp/$config_gitlab_fqdn-crt.pem" "/usr/local/share/ca-certificates/$config_gitlab_fqdn.crt"
update-ca-certificates


#
# install the runner.
# see https://docs.gitlab.com/runner/install/linux-repository.html

apt-get install -y --no-install-recommends curl
wget -qO- https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash
# NB the gitlab-runner daemon runs as root and launches jobs as the gitlab-runner user.
# NB the gitlab-runner daemon manages this node registered runners.
apt-get install -y "gitlab-runner=$gitlab_runner_version"

# configure the docker runner.
# see https://docs.gitlab.com/runner/executors/docker.html
gitlab-runner \
    register \
    --non-interactive \
    --url "https://$config_gitlab_fqdn" \
    --registration-token "$config_gitlab_runner_registration_token" \
    --locked=false \
    --tag-list 'docker,ubuntu,ubuntu-20.04' \
    --description 'Docker / Ubuntu 20.04' \
    --executor 'docker' \
    --docker-image 'ubuntu:20.04' \
    --docker-extra-hosts "$config_gitlab_fqdn:$config_gitlab_ip"

# make sure there are no shell configuration files (at least .bash_logout).
# NB these were copied from the /etc/skel directory when the gitlab-runner
#    user was created but are not really needed.
# NB without this the job can fail with an odd error alike:
#       bash: line 87: cd: /home/gitlab-runner/builds/vhCrXYRX/0/root/hello-pi: No such file or directory
#       ERROR: Job failed: exit status 1
#    see https://gitlab.com/gitlab-org/gitlab-runner/issues/4449
rm -f /home/gitlab-runner/{.bash_logout,.bashrc,.profile}
