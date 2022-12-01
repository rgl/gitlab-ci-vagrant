# download install the docker-compose binaries.
# see https://github.com/docker/compose/releases
$archiveVersion = '2.13.0'
$archiveUrl = "https://github.com/docker/compose/releases/download/v$archiveVersion/docker-compose-windows-x86_64.exe"
$archiveName = Split-Path -Leaf $archiveUrl
$archiveHash = '09f099b74dcb566a5d77c46d3e8e6061640bbec3c6f329c7863040a933d2d358'
$archivePath = "$env:TEMP\$archiveName"
Write-Host "Installing docker-compose $archiveVersion..."
(New-Object System.Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveActualHash -ne $archiveHash) {
    throw "the $archiveUrl file hash $archiveActualHash does not match the expected $archiveHash"
}
$dockerCliPluginsPath = "$env:ProgramData\docker\cli-plugins"
mkdir -Force $dockerCliPluginsPath | Out-Null
Move-Item -Force $archivePath "$dockerCliPluginsPath\docker-compose.exe"
docker compose version
