param(
    [Parameter(Mandatory=$true)]
    [string]$config_gitlab_fqdn = 'gitlab.example.com',

    [Parameter(Mandatory=$true)]
    [string]$config_fqdn = 'windows.gitlab.example.com',

    [Parameter(Mandatory=$true)]
    [string]$gitlabRunnerVersion = '15.11.0'
)

$config_gitlab_ip = "$((Resolve-DNSName $config_gitlab_fqdn).IPAddress)"

# import carbon.
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
git config --global core.longpaths true
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
choco install -y opencover.portable

# install troubeshooting tools.
# NB we ignore the checksums because all the upstream binaries versions use the
#    same URL which will eventually break the package installation when they
#    are updated.
choco install -y --ignore-checksums procexp
choco install -y --ignore-checksums procmon

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

function Install-GitLabRunner($runners) {
    $accountName = 'gitlab-runner' # NB this has a limit of 20 characters.
    $fullName = 'GitLab Runner'

    Write-Title "Installing $fullName..."

    # create the gitlab-runner user account and home directory.
    [Reflection.Assembly]::LoadWithPartialName('System.Web') | Out-Null
    $gitLabRunnerAccountName = $accountName
    $gitLabRunnerAccountPassword = [Web.Security.Membership]::GeneratePassword(32, 8)
    $gitLabRunnerAccountPasswordSecureString = ConvertTo-SecureString $gitLabRunnerAccountPassword -AsPlainText -Force
    $gitLabRunnerAccountCredential = New-Object `
        Management.Automation.PSCredential `
        -ArgumentList `
            $gitLabRunnerAccountName,
            $gitLabRunnerAccountPasswordSecureString
    New-LocalUser `
        -Name $gitLabRunnerAccountName `
        -FullName $fullName `
        -Password $gitLabRunnerAccountPasswordSecureString `
        -PasswordNeverExpires
    # login to force the system to create the home directory.
    # NB the home directory will have the correct permissions, only the
    #    SYSTEM, Administrators and the gitlab-runner account are granted full
    #    permissions to it.
    Start-Process `
        -Wait `
        -WindowStyle Hidden `
        -Credential $gitLabRunnerAccountCredential `
        -WorkingDirectory 'C:\' `
        -FilePath cmd `
        -ArgumentList '/c'

    # configure the gitlab-runner home.
    # NB we have to manually create the service to run as gitlab-runner because psexec 2.32 is fubar.
    choco install -y nssm
    $configureGitLabRunnerServiceName = 'configure-gitlab-runner-home'
    $configureGitLabRunnerServiceHome = "C:\tmp\$configureGitLabRunnerServiceName"
    $configureGitLabRunnerServiceLogPath = "$configureGitLabRunnerServiceHome\service.log"
    mkdir $configureGitLabRunnerServiceHome | Out-Null
    $acl = Get-Acl $configureGitLabRunnerServiceHome
    $acl.AddAccessRule((
        New-Object `
            Security.AccessControl.FileSystemAccessRule(
                $gitLabRunnerAccountName,
                'FullControl',
                'ContainerInherit,ObjectInherit',
                'None',
                'Allow')))
    Set-Acl $configureGitLabRunnerServiceHome $acl
    Copy-Item C:\vagrant\windows\configure-gitlab-runner-home.ps1 $configureGitLabRunnerServiceHome
    nssm install $configureGitLabRunnerServiceName PowerShell.exe
    nssm set $configureGitLabRunnerServiceName AppParameters `
        '-NoLogo' `
        '-NoProfile' `
        '-ExecutionPolicy Bypass' `
        '-File configure-gitlab-runner-home.ps1'
    nssm set $configureGitLabRunnerServiceName ObjectName ".\$gitLabRunnerAccountName" $gitLabRunnerAccountPassword
    nssm set $configureGitLabRunnerServiceName AppStdout $configureGitLabRunnerServiceLogPath
    nssm set $configureGitLabRunnerServiceName AppStderr $configureGitLabRunnerServiceLogPath
    nssm set $configureGitLabRunnerServiceName AppDirectory $configureGitLabRunnerServiceHome
    nssm set $configureGitLabRunnerServiceName AppExit Default Exit
    Start-Service $configureGitLabRunnerServiceName
    $line = 0
    do {
        Start-Sleep -Seconds 5
        if (Test-Path $configureGitLabRunnerServiceLogPath) {
            Get-Content $configureGitLabRunnerServiceLogPath | Select-Object -Skip $line | ForEach-Object {
                ++$line
                Write-Output $_
            }
        }
    } while ((Get-Service $configureGitLabRunnerServiceName).Status -ne 'Stopped')
    nssm remove $configureGitLabRunnerServiceName confirm
    Remove-Item -Recurse $configureGitLabRunnerServiceHome

    # create the installation directory hierarchy.
    $gitLabRunnerDirectory = mkdir "C:\$accountName"
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
        $runners | ForEach-Object {
            &$gitLabRunnerPath `
                register `
                --non-interactive `
                --config $gitLabRunnerConfigPath `
                --url "https://$config_gitlab_fqdn" `
                --registration-token $gitLabRunnerRegistrationToken `
                --locked=false `
                @_
            if ($LASTEXITCODE) {
                throw "failed to register $gitLabRunnerAccountName with exit code $LASTEXITCODE"
            }
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
        throw "failed to install the $gitLabRunnerAccountName service with exit code $LASTEXITCODE"
    }

    # grant the logon as service permission to the gitlab-runner account.
    Grant-Privilege $gitLabRunnerAccountName 'SeServiceLogonRight'

    # grant docker access to the gitlab-runner account.
    Add-LocalGroupMember -Group docker-users -Member $gitLabRunnerAccountName

    # start the service.
    Start-Service $gitLabRunnerAccountName
}

# get windows containers metadata.
$windowsContainers = Get-WindowsContainers

# get build tools metadata.
$buildTools = &"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" `
    -products Microsoft.VisualStudio.Product.BuildTools `
    -format json `
    | ConvertFrom-Json `
    | ForEach-Object {
        $_.catalog.productLineVersion
    }
$runnerBuildToolsTag = ($buildTools | ForEach-Object { "vs$_" }) -join ','
$runnerBuildToolsDescription = "Visual Studio $($buildTools -join '/')"

# install the gitlab-runner service and runners/executors.
Install-GitLabRunner @(
    # see https://docs.gitlab.com/runner/executors/shell.html
    ,@(
        '--executor'
            'shell'
        '--shell'
            'powershell'
        '--tag-list'
            "powershell,shell,$runnerBuildToolsTag,windows,$($windowsContainers.tag)"
        '--description'
            "PowerShell / $runnerBuildToolsDescription / Windows $($windowsContainers.tag)"
    )
    # see https://docs.gitlab.com/runner/executors/shell.html
    ,@(
        '--executor'
            'shell'
        '--shell'
            'pwsh'
        '--tag-list'
            "pwsh,shell,$runnerBuildToolsTag,windows,$($windowsContainers.tag)"
        '--description'
            "pwsh / $runnerBuildToolsDescription / Windows $($windowsContainers.tag)"
    )
    # see https://docs.gitlab.com/runner/executors/docker.html
    # NB although we use --docker-extra-hosts it will not really work on windows
    #    as it does on linux. you will have to work around it; e.g. like we do in
    #    this vagrant environment by having a recursive dns server in the gitlab
    #    vm and configure this vm to use that dns server.
    #    see https://github.com/moby/moby/issues/41165
    ,@(
        '--tag-list'
            "docker,windows,$($windowsContainers.tag)"
        '--description'
            "Docker / Windows $($windowsContainers.tag)"
        '--executor'
            'docker-windows'
        '--shell'
            'powershell'
        '--docker-image'
            $windowsContainers.servercore
        '--docker-extra-hosts'
            "$config_gitlab_fqdn`:$config_gitlab_ip"
    )
)

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
