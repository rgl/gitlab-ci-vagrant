# see https://community.chocolatey.org/packages/chocolatey
# renovate: datasource=nuget:chocolatey depName=chocolatey
$chocolateyVersion = '2.4.3'
$env:chocolateyVersion = $chocolateyVersion

Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
