# download install the docker-compose binaries.
# see https://github.com/docker/compose/releases
$archiveVersion = '2.14.1'
$archiveUrl = "https://github.com/docker/compose/releases/download/v$archiveVersion/docker-compose-windows-x86_64.exe"
$archiveName = Split-Path -Leaf $archiveUrl
$archiveHash = '82394eecdb3cb9e6973edf8c8cc767123f7d2847572b98dcd42bda0e16e4b7e8'
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
