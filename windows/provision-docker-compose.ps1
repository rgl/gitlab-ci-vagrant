# download install the docker-compose binaries.
# see https://github.com/docker/compose/releases
$archiveVersion = '2.5.1'
$archiveUrl = "https://github.com/docker/compose/releases/download/v$archiveVersion/docker-compose-windows-x86_64.exe"
$archiveName = Split-Path -Leaf $archiveUrl
$archiveHash = '1013d982e67f4b08f4493234b3b6cead3d9428ed24a82f8703e014becabd83a5'
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
