# see https://dotnet.microsoft.com/en-us/download/dotnet/8.0
# see https://github.com/dotnet/core/blob/main/release-notes/8.0/8.0.6/8.0.6.md

# opt-out from dotnet telemetry.
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine')
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

# install the dotnet sdk.
$archiveUrl = 'https://download.visualstudio.microsoft.com/download/pr/2e3d0e1d-ad81-4ca7-b186-49f2313547e7/ee8546e4148b87c6e14878b5055406e9/dotnet-sdk-8.0.301-win-x64.exe'
$archiveHash = '4f6fbed3d79e8f8e782198c92d5a3454e817efd03c656b9cb2e1a11d67627070bd14eb78d7618efed29f5c958649d4e93ea6b6469c2e06f07110882fb63f39c3'
$archiveName = Split-Path -Leaf $archiveUrl
$archivePath = "$env:TEMP\$archiveName"
Write-Host "Downloading $archiveName..."
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA512).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host "Installing $archiveName..."
&$archivePath /install /quiet /norestart | Out-String -Stream
if ($LASTEXITCODE) {
    throw "Failed to install dotnet-sdk with Exit Code $LASTEXITCODE"
}
Remove-Item $archivePath

# reload PATH.
$env:PATH = "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$([Environment]::GetEnvironmentVariable('PATH', 'User'))"

# show information about dotnet.
dotnet --info
