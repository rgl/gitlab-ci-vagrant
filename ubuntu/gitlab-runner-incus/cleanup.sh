#!/bin/bash
source /opt/gitlab-runner-incus/base.sh

echo "Deleting $CONTAINER_ID..."
incus delete -f "$CONTAINER_ID"
