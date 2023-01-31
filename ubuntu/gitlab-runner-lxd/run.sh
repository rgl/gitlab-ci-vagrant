#!/bin/bash
source /opt/gitlab-runner-lxd/base.sh

lxc exec "$CONTAINER_ID" -- bash <"$1"
