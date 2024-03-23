#!/bin/bash
source /opt/gitlab-runner-incus/base.sh

if incus info "$CONTAINER_ID" >/dev/null 2>&1; then
    echo "Deleting $CONTAINER_ID..."
    incus delete -f "$CONTAINER_ID"
fi

os_name="$(lsb_release -si)"
image_name="gitlab-runner-incus-${os_name,,}"

echo "Launching $CONTAINER_ID..."
incus copy "$image_name" "$CONTAINER_ID"
incus start "$CONTAINER_ID"
incus exec "$CONTAINER_ID" -- bash <<'LXCEXEC'
set -euo pipefail
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
LXCEXEC
