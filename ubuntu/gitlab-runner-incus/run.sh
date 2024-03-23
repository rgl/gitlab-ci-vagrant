#!/bin/bash
source /opt/gitlab-runner-incus/base.sh

incus exec "$CONTAINER_ID" -- bash <"$1"
