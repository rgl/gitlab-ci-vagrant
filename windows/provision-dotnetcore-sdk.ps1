# see https://dotnet.microsoft.com/download/dotnet-core/3.1
# see https://github.com/dotnet/core/blob/main/release-notes/3.1/3.1.18/3.1.18.md

# opt-out from dotnet telemetry.
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine')
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

# install the dotnet sdk.
$archiveUrl = 'https://download.visualstudio.microsoft.com/download/pr/046165a4-10d4-4156-8e65-1d7b2cbd304e/a4c7b01f6bf7199669a45ab6a03803ac/dotnet-sdk-3.1.412-win-x64.exe'
$archiveHash = '542ce4bd7b2249ece59f411d9f4075648ff7b66d3895043a499976306039080d2ba626ec2e9d90ec8e4f0f0ab9ec61a4227417ed148f4c96ed8bc953078f148c'
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
    throw "Failed to install dotnetcore-sdk with Exit Code $LASTEXITCODE"
}
Remove-Item $archivePath

# reload PATH.
$env:PATH = "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$([Environment]::GetEnvironmentVariable('PATH', 'User'))"

# show information about dotnet.
dotnet --info

# add the nuget.org source.
# see https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-add-source
dotnet nuget add source --name nuget.org https://api.nuget.org/v3/index.json
dotnet nuget list source

# install the sourcelink dotnet global tool.
dotnet tool install --global sourcelink
