#!/bin/bash
set -euxo pipefail

gitlab_runner_version="${1:-17.2.1}"; shift || true
os_name="$(lsb_release -si)"
os_version="$(lsb_release -sr)"
config_gitlab_fqdn=$(hostname --domain)
config_gitlab_ip=$(python3 -c "import socket; print(socket.gethostbyname(\"$config_gitlab_fqdn\"))")

export DEBIAN_FRONTEND=noninteractive


#
# trust the gitlab certificate.

install "/vagrant/tmp/$config_gitlab_fqdn-crt.pem" "/usr/local/share/ca-certificates/$config_gitlab_fqdn.crt"
update-ca-certificates


#
# install the runner.
# see https://docs.gitlab.com/runner/install/linux-repository.html
# see https://gitlab.com/gitlab-org/gitlab-runner/tags

apt-get install -y --no-install-recommends curl
wget -qO- https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash
gitlab_runner_package_version="$(apt-cache madison gitlab-runner | perl -ne "/gitlab-runner \\|\\s+(\\Q$gitlab_runner_version\\E[^ .|]*)\\s+\\|/ && print \$1" | head -1)"
# NB the gitlab-runner daemon runs as root and launches jobs as the gitlab-runner user.
# NB the gitlab-runner daemon manages this node registered runners.
apt-get install -y "gitlab-runner=$gitlab_runner_package_version"

# make sure there are no shell configuration files (at least .bash_logout).
# NB these were copied from the /etc/skel directory when the gitlab-runner
#    user was created but are not really needed.
# NB without this the job can fail with an odd error alike:
#       bash: line 87: cd: /home/gitlab-runner/builds/vhCrXYRX/0/root/hello-pi: No such file or directory
#       ERROR: Job failed: exit status 1
#    see https://gitlab.com/gitlab-org/gitlab-runner/issues/4449
rm -f /home/gitlab-runner/{.bash_logout,.bashrc,.profile}
