#!/bin/bash
set -euxo pipefail

# download.
# see https://docs.docker.com/compose/install/#install-compose-on-linux-systems
docker_compose_version='1.28.2'
docker_compose_url="https://github.com/docker/compose/releases/download/$docker_compose_version/docker-compose-$(uname -s)-$(uname -m)"
wget -qO /tmp/docker-compose "$docker_compose_url"

# install.
install -o root -g root -m 555 /tmp/docker-compose /usr/local/bin
rm /tmp/docker-compose
docker-compose --version
