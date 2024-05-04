# see https://dotnet.microsoft.com/en-us/download/dotnet/8.0
# see https://github.com/dotnet/core/blob/main/release-notes/8.0/8.0.4/8.0.4.md

# opt-out from dotnet telemetry.
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine')
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

# install the dotnet sdk.
$archiveUrl = 'https://download.visualstudio.microsoft.com/download/pr/1e9f5038-d1c3-4219-94e9-62d6f810e589/c28bb8c8a1a3d01c72f3db1646a983c5/dotnet-sdk-8.0.204-win-x64.exe'
$archiveHash = '9c3bf9c027131a3ad9f66667c609b19e8846af795fa5a88558b49c6d6011d571aa1faea76f7b6a2dc5f5eb30d9ab5db7a4a9bea2348642b23c9968a4b73f3c11'
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
