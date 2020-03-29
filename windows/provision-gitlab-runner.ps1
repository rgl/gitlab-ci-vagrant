param(
    [Parameter(Mandatory=$true)]
    [string]$config_gitlab_fqdn = 'gitlab.example.com',

    [Parameter(Mandatory=$true)]
    [string]$config_fqdn = 'windows.gitlab.example.com',

    [Parameter(Mandatory=$true)]
    [string]$gitlabRunnerVersion = '12.9.0'
)

# install carbon.
choco install -y carbon
Import-Module Carbon

# install git and related applications.
choco install -y git --params '/GitOnlyOnPath /NoAutoCrlf /SChannel'
choco install -y gitextensions
choco install -y meld

# update $env:PATH with the recently installed Chocolatey packages.
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"
Update-SessionEnvironment

# configure git.
# see http://stackoverflow.com/a/12492094/477532
git config --global user.name 'Rui Lopes'
git config --global user.email 'rgl@ruilopes.com'
git config --global http.sslbackend schannel
git config --global push.default simple
git config --global core.autocrlf false
git config --global diff.guitool meld
git config --global difftool.meld.path 'C:/Program Files (x86)/Meld/Meld.exe'
git config --global difftool.meld.cmd '\"C:/Program Files (x86)/Meld/Meld.exe\" \"$LOCAL\" \"$REMOTE\"'
git config --global merge.tool meld
git config --global mergetool.meld.path 'C:/Program Files (x86)/Meld/Meld.exe'
git config --global mergetool.meld.cmd '\"C:/Program Files (x86)/Meld/Meld.exe\" \"$LOCAL\" \"$BASE\" \"$REMOTE\" --auto-merge --output \"$MERGED\"'
#git config --list --show-origin

# install testing tools.
choco install -y xunit
choco install -y reportgenerator.portable
# NB we need to install a recent (non-released) version due
#    to https://github.com/OpenCover/opencover/issues/736
Push-Location opencover-rgl.portable
choco pack
choco install -y opencover-rgl.portable -Source $PWD
Pop-Location

# install troubeshooting tools.
choco install -y procexp
choco install -y procmon

# add start menu entries.
Install-ChocolateyShortcut `
    -ShortcutFilePath 'C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\Process Explorer.lnk' `
    -TargetPath 'C:\ProgramData\chocolatey\lib\procexp\tools\procexp64.exe'
Install-ChocolateyShortcut `
    -ShortcutFilePath 'C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\Process Monitor.lnk' `
    -TargetPath 'C:\ProgramData\chocolatey\lib\procmon\tools\procmon.exe'

# import the GitLab site https certificate into the local machine trust store.
Import-Certificate `
    -FilePath C:/vagrant/tmp/$config_gitlab_fqdn-crt.der `
    -CertStoreLocation Cert:/LocalMachine/Root

# restart the SSH service so it can re-read the environment (e.g. the system environment
# variables like PATH) after we have installed all this slave node dependencies.
Restart-Service sshd

function Install-GitLabRunner($name, $extraRunnerArguments) {
    Write-Title "Installing GitLab Runner $name..."

    # create the gitlab-runner user account and home directory.
    [Reflection.Assembly]::LoadWithPartialName('System.Web') | Out-Null
    $gitLabRunnerAccountName = "gitlab-runner-$name" # NB this has a limit of 20 characters.
    $gitLabRunnerAccountPassword = [Web.Security.Membership]::GeneratePassword(32, 8)
    $gitLabRunnerAccountPasswordSecureString = ConvertTo-SecureString $gitLabRunnerAccountPassword -AsPlainText -Force
    $gitLabRunnerAccountCredential = New-Object `
        Management.Automation.PSCredential `
        -ArgumentList `
            $gitLabRunnerAccountName,
            $gitLabRunnerAccountPasswordSecureString
    New-LocalUser `
        -Name $gitLabRunnerAccountName `
        -FullName "GitLab Runner $name" `
        -Password $gitLabRunnerAccountPasswordSecureString `
        -PasswordNeverExpires
    # login to force the system to create the home directory.
    # NB the home directory will have the correct permissions, only the
    #    SYSTEM, Administrators and the gitlab-runner account are granted full
    #    permissions to it.
    Start-Process -WindowStyle Hidden -Credential $gitLabRunnerAccountCredential -WorkingDirectory 'C:\' -FilePath cmd -ArgumentList '/c'

    # configure the gitlab-runner home.
    choco install -y pstools
    Copy-Item C:\vagrant\windows\configure-gitlab-runner-home.ps1 C:\tmp
    psexec `
        -accepteula `
        -nobanner `
        -u $gitLabRunnerAccountName `
        -p $gitLabRunnerAccountPassword `
        -h `
        PowerShell -File C:\tmp\configure-gitlab-runner-home.ps1
    Remove-Item C:\tmp\configure-gitlab-runner-home.ps1

    # create the installation directory hierarchy.
    $gitLabRunnerDirectory = mkdir "C:\GitLab-Runner-$name"
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    @(
        'SYSTEM'
        'Administrators'
    ) | ForEach-Object {
        $acl.AddAccessRule((
            New-Object `
                Security.AccessControl.FileSystemAccessRule(
                    $_,
                    'FullControl',
                    'ContainerInherit,ObjectInherit',
                    'None',
                    'Allow')))
    }
    $acl.AddAccessRule((
        New-Object `
            Security.AccessControl.FileSystemAccessRule(
                $gitLabRunnerAccountName,
                'ReadAndExecute',
                'ContainerInherit,ObjectInherit',
                'None',
                'Allow')))
    $gitLabRunnerDirectory.SetAccessControl($acl)
    $gitLabRunnerConfigDirectory = mkdir "$gitLabRunnerDirectory\config"
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($false, $true)
    $acl.AddAccessRule((
        New-Object `
            Security.AccessControl.FileSystemAccessRule(
                $gitLabRunnerAccountName,
                'FullControl',
                'ContainerInherit,ObjectInherit',
                'None',
                'Allow')))
    $gitLabRunnerConfigDirectory.SetAccessControl($acl)
    $gitLabRunnerWorkspaceDirectory = mkdir "$gitLabRunnerDirectory\workspace"
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($false, $true)
    $acl.AddAccessRule((
        New-Object `
            Security.AccessControl.FileSystemAccessRule(
                $gitLabRunnerAccountName,
                'FullControl',
                'ContainerInherit,ObjectInherit',
                'None',
                'Allow')))
    $gitLabRunnerWorkspaceDirectory.SetAccessControl($acl)

    # download the binary and install it.
    # see https://gitlab.com/gitlab-org/gitlab-runner/tags
    # see https://docs.gitlab.com/runner/install/bleeding-edge.html#download-any-other-tagged-release
    $gitLabRunnerConfigPath = "$gitLabRunnerConfigDirectory\config.toml"
    $gitLabRunnerPath = "$gitLabRunnerDirectory\bin\gitlab-runner.exe"
    mkdir "$gitLabRunnerDirectory\bin" | Out-Null
    (New-Object Net.WebClient).DownloadFile(
        "https://gitlab-runner-downloads.s3.amazonaws.com/v$gitlabRunnerVersion/binaries/gitlab-runner-windows-amd64.exe",
        $gitLabRunnerPath)

    # register the gitlab runner with gitlab.
    # see https://docs.gitlab.com/runner/register/index.html#one-line-registration-command
    $gitLabRunnerRegistrationToken = Get-Content C:\vagrant\tmp\gitlab-runners-registration-token.txt
    # NB temporarily prevent powershell from raising an exception when something
    #    is written to stderr by $gitLabRunnerPath, as that is expected.
    $ErrorActionPreference = 'Continue'
    try {
        &$gitLabRunnerPath `
            register `
            --non-interactive `
            --config $gitLabRunnerConfigPath `
            --url "https://$config_gitlab_fqdn" `
            --registration-token $gitLabRunnerRegistrationToken `
            --locked=false `
            @extraRunnerArguments
        if ($LASTEXITCODE) {
            throw "failed to register gitlab-runner $name with exit code $LASTEXITCODE"
        }
    } finally {
        $ErrorActionPreference = 'Stop'
    }

    # configure the gitlab runner.
    # see https://docs.gitlab.com/runner/configuration/advanced-configuration.html
    (Get-Content $gitLabRunnerConfigPath) `
        -replace '^(concurrent\s*=).*','$1 3' `
        | Set-Content -Encoding ascii $gitLabRunnerConfigPath

    # install the gitlab-runner service.
    &$gitLabRunnerPath `
        install `
        --service $gitLabRunnerAccountName `
        --user ".\$gitLabRunnerAccountName" `
        --password $gitLabRunnerAccountPassword `
        --config $gitLabRunnerConfigPath `
        --working-directory $gitLabRunnerWorkspaceDirectory
    if ($LASTEXITCODE) {
        throw "failed to install the gitlab-runner service with exit code $LASTEXITCODE"
    }

    # grant the logon as service permission to the gitlab-runner account.
    Grant-Privilege $gitLabRunnerAccountName 'SeServiceLogonRight'

    # start the service.
    Start-Service $gitLabRunnerAccountName
}

# see https://docs.gitlab.com/runner/executors/shell.html
Install-GitLabRunner 'ps' @(
    '--executor'
        'shell'
    '--shell'
        'powershell'
    '--tag-list'
        'powershell,vs2019,windows,windows1809'
    '--description'
        'PowerShell / Visual Studio 2019 / Windows 1809'
)

# see https://docs.gitlab.com/runner/executors/docker.html
Install-GitLabRunner 'docker' @(
    '--tag-list'
        'docker,windows,windows1809'
    '--description'
        'Docker / Windows 1809'
    '--executor'
        'docker-windows'
    '--docker-image'
        'mcr.microsoft.com/windows/servercore:1809'
)
Add-LocalGroupMember -Group docker-users -Member gitlab-runner-docker

# create artifacts that need to be shared with the other nodes.
mkdir -Force C:\vagrant\tmp | Out-Null
[IO.File]::WriteAllText(
    "C:\vagrant\tmp\$config_fqdn.ssh_known_hosts",
    (dir 'C:\ProgramData\ssh\ssh_host_*_key.pub' | %{ "$config_fqdn $(Get-Content $_)`n" }) -join ''
)

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-GitLab.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\GitLab.url",
    @"
[InternetShortcut]
URL=https://{0}
"@)
'@ -f $config_gitlab_fqdn)

# show installation summary.
function Write-Title($title) {
    Write-Host "`n#`n# $title`n"
}
Write-Title 'Installed DotNet version'
Write-Host (Get-DotNetVersion)
Write-Title 'Installed MSBuild version'
MSBuild -version
Write-Title 'Installed chocolatey packages'
choco list -l
