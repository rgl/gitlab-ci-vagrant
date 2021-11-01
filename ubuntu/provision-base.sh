#!/bin/bash
set -euxo pipefail

config_fqdn=$(hostname --fqdn)
config_jenkins_master_fqdn=$(hostname --domain)

echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive


#
# make sure the package index cache is up-to-date before installing anything.

apt-get update


#
# install vim.

apt-get install -y --no-install-recommends vim

cat >/etc/vim/vimrc.local <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF


#
# configure the shell.

cat >/etc/profile.d/login.sh <<'EOF'
[[ "$-" != *i* ]] && return
export EDITOR=vim
export PAGER=less
alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat >/etc/inputrc <<'EOF'
set input-meta on
set output-meta on
set show-all-if-ambiguous on
set completion-ignore-case on
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
EOF


#
# install git.

apt-get install -y git-core


#
# create artifacts that need to be shared with the other nodes.

mkdir -p /vagrant/tmp
pushd /vagrant/tmp
find \
    /etc/ssh \
    -name 'ssh_host_*_key.pub' \
    -exec sh -c "(echo -n '$config_fqdn '; cat {})" \; \
    >$config_fqdn.ssh_known_hosts
popd
