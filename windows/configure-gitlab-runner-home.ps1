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

# install the sourcelink dotnet global tool.
# NB this is installed at %USERPROFILE%\.dotnet\tools.
# see https://github.com/dotnet/sourcelink
# see https://github.com/ctaggart/SourceLink
# see https://www.nuget.org/packages/SourceLink
dotnet tool install --global SourceLink --version 3.1.1

# install the xUnit to JUnit report converter.
# see https://github.com/gabrielweyer/xunit-to-junit
# see https://www.nuget.org/packages/dotnet-xunit-to-junit
dotnet tool install --global dotnet-xunit-to-junit --version 4.0.0

# install the report generator.
# see https://github.com/danielpalme/ReportGenerator
# see https://www.nuget.org/packages/dotnet-reportgenerator-globaltool
dotnet tool install --global dotnet-reportgenerator-globaltool --version 5.1.9
