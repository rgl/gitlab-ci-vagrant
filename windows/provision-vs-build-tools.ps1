# add support for building applications that target the .net 4.8 framework.
choco install -y netfx-4.8-devpack

# install the Visual Studio Build Tools 2026 18.3.1.
# see https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-history#release-dates-and-build-numbers
# see https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes
# see https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=visualstudio
# see https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=visualstudio
# see https://learn.microsoft.com/en-us/visualstudio/install/workload-and-component-ids?view=visualstudio
# see https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=visualstudio
# NB update the windbg version in provision-procdump-as-postmortem-debugger.ps1 to match the installed Windows11SDK.26100.
$archiveUrl = 'https://download.visualstudio.microsoft.com/download/pr/5b5cda09-f12b-4e87-9fcf-38e38e09cede/ad6a8ee47ba7d5f8d952a63b80fa14e96b7d5bd08f984cf7887d68dca4ef93a5/vs_BuildTools.exe'
$archiveHash = 'ad6a8ee47ba7d5f8d952a63b80fa14e96b7d5bd08f984cf7887d68dca4ef93a5'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading the Visual Studio Build Tools Setup Bootstrapper...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing the Visual Studio Build Tools...'
$vsBuildToolsHome = 'C:\VS2026BuildTools'
for ($try = 1; ; ++$try) {
    &$archivePath `
        --installPath $vsBuildToolsHome `
        --add Microsoft.VisualStudio.Workload.MSBuildTools `
        --add Microsoft.VisualStudio.Workload.VCTools `
        --add Microsoft.VisualStudio.Component.VC.CLI.Support `
        --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        --add Microsoft.VisualStudio.Component.Windows11SDK.26100 `
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
