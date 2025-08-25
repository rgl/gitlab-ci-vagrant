#!/bin/bash
set -euxo pipefail

# opt-out of telemetry.
# see https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_telemetry?view=powershell-7.4
echo 'export POWERSHELL_TELEMETRY_OPTOUT=1' >/etc/profile.d/opt-out-powershell-telemetry.sh
source /etc/profile.d/opt-out-powershell-telemetry.sh

# install.
# see https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu?view=powershell-7.4
# see https://github.com/PowerShell/PowerShell/releases
# renovate: datasource=deb:microsoft depName=powershell extractVersion=^(?<version>7\.4\..+)-1\.deb$
powershell_version='7.4.11'
wget -qO packages-microsoft-prod.deb "https://packages.microsoft.com/config/ubuntu/$(lsb_release -s -r)/packages-microsoft-prod.deb"
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get install -y apt-transport-https
apt-get update
package_version="$(apt-cache madison powershell | awk "/$powershell_version-/{print \$3}")"
apt-get install -y "powershell=$package_version"