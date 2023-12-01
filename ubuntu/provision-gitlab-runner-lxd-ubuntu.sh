#!/bin/bash
set -euxo pipefail

gitlab_runner_version="${1:-16.6.1}"; shift || true
docker_version="${1:-24.0.7}"; shift || true
os_name="$(lsb_release -si)"
os_version="$(lsb_release -sr)"
os_codename="$(lsb_release -sc)"
os_arch="$(uname -m)"
image_name="gitlab-runner-lxd-${os_name,,}"
# see https://uk.lxd.images.canonical.com/
# see lxc image list images:${os_name,,}/ type=container architecture=${os_arch,,}
base_image_name="images:${os_name,,}/${os_codename}"

# delete the existing container.
if lxc info "$image_name" >/dev/null 2>&1; then
    lxc delete -f "$image_name"
fi

# build the container.
lxc init $base_image_name $image_name </dev/null
lxc config set $image_name boot.autostart=false
# configure the container to run nested docker managed containers.
# see https://ubuntu.com/tutorials/how-to-run-docker-inside-lxd-containers
# see https://www.youtube.com/watch?v=_fCSSEyiGro
lxc config set $image_name \
    security.nesting=true \
    security.syscalls.intercept.mknod=true \
    security.syscalls.intercept.setxattr=true
# TODO set the container resources (e.g. cpu, memory)?
lxc start $image_name
lxc exec $image_name \
    --env "gitlab_runner_version=$gitlab_runner_version" \
    --env "docker_version=$docker_version" \
    -- bash <<'LXCEXEC'
set -euxo pipefail

# wait for the system to be running.
function wait-for-system-running {
    for i in {0..20}; do
        if [ "$(systemctl is-system-running 2>/dev/null)" == 'running' ]; then
            return 0
        fi
        sleep 0.5
    done
    echo 'ERROR: Timeout waiting for the system to be running'
    return 1
}
wait-for-system-running

# install dependencies.
apt-get update
apt-get install -y --no-install-recommends wget curl

# install git-lfs.
# TODO pin the version.
wget -qO- https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
apt-get install -y git-lfs

# install the gitlab-runner binary.
# see https://docs.gitlab.com/runner/install/linux-repository.html
wget -qO- https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash
apt-get install -y "gitlab-runner=$gitlab_runner_version"
systemctl disable --now gitlab-runner

# make sure there are no shell configuration files (at least .bash_logout).
# NB these were copied from the /etc/skel directory when the gitlab-runner
#    user was created but are not really needed.
# NB without this the job can fail with an odd error alike:
#       bash: line 87: cd: /home/gitlab-runner/builds/vhCrXYRX/0/root/hello-pi: No such file or directory
#       ERROR: Job failed: exit status 1
#    see https://gitlab.com/gitlab-org/gitlab-runner/issues/4449
rm -f /home/gitlab-runner/{.bash_logout,.bashrc,.profile}

# install docker.
# see https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-using-the-repository
# see https://github.com/moby/moby/releases
apt-get install -y apt-transport-https software-properties-common
wget -qO- https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-cache madison docker-ce
docker_version="$(apt-cache madison docker-ce | awk "/$docker_version/{print \$3}")"
apt-get install -y "docker-ce=$docker_version" "docker-ce-cli=$docker_version" containerd.io

# dump information.
uname -a
lscpu
ps axww
systemctl list-units
dpkg-query -W -f='${binary:Package}\\n' | sort
cat /var/lib/dbus/machine-id
#cat /var/lib/systemd/random-seed

# reset the machine-id.
# NB systemd will re-generate it on the next boot.
# NB machine-id is indirectly used in DHCP as Option 61 (Client Identifier), which
#    the DHCP server uses to (re-)assign the same or new client IP address.
# see https://www.freedesktop.org/software/systemd/man/machine-id.html
# see https://www.freedesktop.org/software/systemd/man/systemd-machine-id-setup.html
echo '' >/etc/machine-id
rm -f /var/lib/dbus/machine-id

# clean.
apt-get -y autoremove --purge
apt-get -y clean
rm -rf /tmp/*
rm -rf /var/lib/apt/lists/*
LXCEXEC
lxc stop $image_name

# show the container configuration.
lxc config show $image_name

# show the container zfs dataset properies.
# NB the origin property points to the parent zfs dataset.
zfs get all lxd/containers/$image_name
