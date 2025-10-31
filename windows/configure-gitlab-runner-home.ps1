# NB this script run as the gitlab-runner user and does not have access to C:\vagrant.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

# configure the docker client through a configuration file.
# see https://docs.docker.com/reference/cli/docker/#docker-cli-configuration-file-configjson-properties
# see https://docs.docker.com/engine/security/protect-access
$homePath = (Resolve-Path ~).Path
mkdir "$homePath\.docker" | Out-Null
Copy-Item gitlab-ca-crt.pem "$homePath\.docker\ca.pem"
Copy-Item windows-crt.pem "$homePath\.docker\cert.pem"
Copy-Item windows-key.pem "$homePath\.docker\key.pem"
$config = @{
    'tlscacert' = "$homePath\.docker\ca.pem"
    'tlscert' = "$homePath\.docker\cert.pem"
    'tlskey' = "$homePath\.docker\key.pem"
}
Set-Content -Encoding ascii "$homePath\.docker\config.json" ($config | ConvertTo-Json -Depth 100)

# install the sourcelink dotnet global tool.
# NB this is installed at %USERPROFILE%\.dotnet\tools.
# see https://github.com/dotnet/sourcelink
# see https://github.com/ctaggart/SourceLink
# see https://www.nuget.org/packages/SourceLink
# renovate: datasource=nuget depName=SourceLink
$sourceLinkVersion = '3.1.1'
dotnet tool install --global SourceLink --version $sourceLinkVersion

# install the xUnit to JUnit report converter.
# see https://github.com/gabrielweyer/xunit-to-junit
# see https://www.nuget.org/packages/dotnet-xunit-to-junit
# renovate: datasource=nuget depName=dotnet-xunit-to-junit
$dotnetXunitToJunitVersion = '7.0.0'
dotnet tool install --global dotnet-xunit-to-junit --version $dotnetXunitToJunitVersion

# install the report generator.
# see https://github.com/danielpalme/ReportGenerator
# see https://www.nuget.org/packages/dotnet-reportgenerator-globaltool
# renovate: datasource=nuget depName=dotnet-reportgenerator-globaltool
$dotnetReportgeneratorGlobaltoolVersion = '5.4.18'
dotnet tool install --global dotnet-reportgenerator-globaltool --version $dotnetReportgeneratorGlobaltoolVersion
