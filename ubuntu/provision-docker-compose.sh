#!/bin/bash
set -euxo pipefail

# install.
# see https://docs.docker.com/compose/install/#install-compose-on-linux-systems
# see https://github.com/docker/compose/releases
# NB the apt respository was already configured in provision-docker.sh.
docker_compose_version='2.3.3'
docker_compose_package_version="$(apt-cache madison docker-compose-plugin | awk "/$docker_compose_version~/{print \$3}")"
apt-get install -y "docker-compose-plugin=$docker_compose_package_version"
docker compose version
