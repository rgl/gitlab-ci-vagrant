# add support for building applications that target the .net 4.8 framework.
choco install -y netfx-4.8-devpack

# install the Visual Studio Build Tools 2022 17.12.6.
# see https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history#fixed-version-bootstrappers
# see https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes
# see https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022
# see https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=vs-2022
# see https://learn.microsoft.com/en-us/visualstudio/install/workload-and-component-ids?view=vs-2022
# see https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022
# NB update the windbg version in provision-procdump-as-postmortem-debugger.ps1 to match the installed Windows10SDK.19041.
$archiveUrl = 'https://download.visualstudio.microsoft.com/download/pr/7c611a5a-a51d-429f-83d5-4ff522b14367/21cfe74b3a50f484e9404dc5b5df77ab2c1aabc95c07fe913b20239a10b815f6/vs_BuildTools.exe'
$archiveHash = '21cfe74b3a50f484e9404dc5b5df77ab2c1aabc95c07fe913b20239a10b815f6'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading the Visual Studio Build Tools Setup Bootstrapper...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing the Visual Studio Build Tools...'
$vsBuildToolsHome = 'C:\VS2022BuildTools'
for ($try = 1; ; ++$try) {
    &$archivePath `
        --installPath $vsBuildToolsHome `
        --add Microsoft.VisualStudio.Workload.MSBuildTools `
        --add Microsoft.VisualStudio.Workload.VCTools `
        --add Microsoft.VisualStudio.Component.VC.CLI.Support `
        --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        --add Microsoft.VisualStudio.Component.Windows10SDK.19041 `
        --norestart `
        --quiet `
        --wait `
        | Out-String -Stream
    if ($LASTEXITCODE) {
        if ($try -le 5) {
            Write-Host "Failed to install the Visual Studio Build Tools with Exit Code $LASTEXITCODE. Trying again (hopefully the error was transient)..."
            Start-Sleep -Seconds 10
            continue
        }
        throw "Failed to install the Visual Studio Build Tools with Exit Code $LASTEXITCODE"
    }
    break
}

# add MSBuild to the machine PATH.
[Environment]::SetEnvironmentVariable(
    'PATH',
    "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$vsBuildToolsHome\MSBuild\Current\Bin",
    'Machine')

# prevent msbuild from running in background, as that will interfere with
# cleaning the job workspace due to open files/directories.
[Environment]::SetEnvironmentVariable(
    'MSBUILDDISABLENODEREUSE',
    '1',
    'Machine')
