#!/bin/bash
source /opt/gitlab-runner-lxd/base.sh

echo "Deleting $CONTAINER_ID..."
lxc delete -f "$CONTAINER_ID"
