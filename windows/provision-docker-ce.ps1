param(
    [Parameter(Mandatory=$true)]
    [string]$config_fqdn = 'windows.gitlab.example.com'
)

# see https://learn.microsoft.com/en-us/virtualization/windowscontainers/manage-docker/configure-docker-daemon
# see https://docs.docker.com/engine/installation/linux/docker-ce/binaries/#install-server-and-client-binaries-on-windows
# see https://github.com/moby/moby/releases/tag/v29.1.3
# see https://github.com/rgl/docker-ce-windows-binaries-vagrant/releases/tag/v29.1.3

# download install the docker binaries.
# renovate: datasource=github-releases depName=rgl/docker-ce-windows-binaries-vagrant
$archiveVersion = '29.1.3'
$archiveName = "docker-$archiveVersion.zip"
$archiveUrl = "https://github.com/rgl/docker-ce-windows-binaries-vagrant/releases/download/v$archiveVersion/$archiveName"
$archivePath = "$env:TEMP\$archiveName"
Write-Host "Installing docker $archiveVersion..."
(New-Object System.Net.WebClient).DownloadFile($archiveUrl, $archivePath)
Expand-Archive $archivePath -DestinationPath $env:ProgramFiles
Remove-Item $archivePath

# add docker to the Machine PATH.
[Environment]::SetEnvironmentVariable(
    'PATH',
    "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$env:ProgramFiles\docker",
    'Machine')
# add docker to the current process PATH.
$env:PATH += ";$env:ProgramFiles\docker"

# install the docker service.
dockerd --register-service

# add group that will be allowed to use the docker engine named pipe.
New-LocalGroup `
    -Name docker-users `
    -Description 'Docker engine users' `
    | Out-Null

# configure docker through a configuration file.
# see https://docs.docker.com/engine/reference/commandline/dockerd/#windows-configuration-file
# see https://docs.docker.com/engine/security/protect-access/#use-tls-https-to-protect-the-docker-daemon-socket
$config = @{
    'experimental' = $false
    'debug' = $false
    'labels' = @('os=windows')
    'exec-opts' = @('isolation=process')
    # allow users in the following groups to use the docker engine named pipe.
    # see https://github.com/moby/moby/commit/0906195fbbd6f379c163b80f23e4c5a60bcfc5f0
    # see https://github.com/moby/moby/blob/8e610b2b55bfd1bfa9436ab110d311f5e8a74dcb/daemon/listeners/listeners_windows.go#L25
    'group' = 'docker-users'
    'hosts' = @(
        ,'npipe:////./pipe/docker_engine'
        ,'tcp://0.0.0.0:2376'
    )
    "tlsverify" = $true
    "tlscacert" = "$env:ProgramData\docker\config\gitlab-ca-crt.pem"
    "tlscert" = "$env:ProgramData\docker\config\$config_fqdn-crt.pem"
    "tlskey" = "$env:ProgramData\docker\config\$config_fqdn-key.pem"
}
mkdir -Force "$env:ProgramData\docker\config" | Out-Null
Copy-Item c:\vagrant\tmp\gitlab-ca-crt.pem "$env:ProgramData\docker\config"
Copy-Item "c:\vagrant\tmp\$config_fqdn-crt.pem" "$env:ProgramData\docker\config"
Copy-Item "c:\vagrant\tmp\$config_fqdn-key.pem" "$env:ProgramData\docker\config"
Set-Content -Encoding ascii "$env:ProgramData\docker\config\daemon.json" ($config | ConvertTo-Json -Depth 100)

Write-Host 'Starting docker...'
Start-Service docker

Write-Host 'Creating the firewall rule to allow inbound TCP/IP access to the Docker Engine port 2376...'
New-NetFirewallRule `
    -Name 'Docker-Engine-In-TCP' `
    -DisplayName 'Docker Engine (TCP-In)' `
    -Direction Inbound `
    -Enabled True `
    -Protocol TCP `
    -LocalPort 2376 `
    | Out-Null

Write-Title "windows version"
$windowsCurrentVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$windowsVersion = "$($windowsCurrentVersion.CurrentMajorVersionNumber).$($windowsCurrentVersion.CurrentMinorVersionNumber).$($windowsCurrentVersion.CurrentBuildNumber).$($windowsCurrentVersion.UBR)"
Write-Output $windowsVersion

Write-Title 'windows BuildLabEx version'
# BuildLabEx is something like:
#      17763.1.amd64fre.rs5_release.180914-1434
#      ^^^^^^^ ^^^^^^^^ ^^^^^^^^^^^ ^^^^^^ ^^^^
#      build   platform branch      date   time (redmond tz)
# see https://channel9.msdn.com/Blogs/One-Dev-Minute/Decoding-Windows-Build-Numbers
(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name BuildLabEx).BuildLabEx

Write-Title 'docker version'
docker version

Write-Title 'docker info'
docker info

Write-Title 'docker info (tls endpoint)'
docker `
    --tlsverify `
    --tlscacert c:\vagrant\tmp\gitlab-ca-crt.pem `
    --tlscert c:\vagrant\tmp\windows-crt.pem `
    --tlskey c:\vagrant\tmp\windows-key.pem `
    --host "tcp://${config_fqdn}:2376" `
    info

Write-Title 'docker named pipe \\.\pipe\docker_engine ACL'
# NB you can get the current list of named pipes with:
#       [System.IO.Directory]::GetFiles('\\.\pipe\') | Sort-Object
# NB you can manually change the named pipe ACL with:
#       Add-LocalGroupMember -Group docker-users -Member jenkins
#       $ac = [System.IO.Directory]::GetAccessControl('\\.\pipe\docker_engine')
#       $ac.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule 'docker-users','Read,Write,Synchronize','Allow'))
#       [System.IO.Directory]::SetAccessControl('\\.\pipe\docker_engine', $ac)
[System.IO.Directory]::GetAccessControl("\\.\pipe\docker_engine") | Format-Table -Wrap
