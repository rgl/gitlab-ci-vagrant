param(
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$addresses
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Host "ERROR: $_"
    Write-Host (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

# bail when not running over hyperv.
$systemVendor = (Get-WmiObject Win32_ComputerSystemProduct Vendor).Vendor
if ($systemVendor -ne 'Microsoft Corporation') {
    Exit 0
}

# expand the C drive when there is disk available.
$partition = Get-Partition -DriveLetter C
$partitionSupportedSize = Get-PartitionSupportedSize -DriveLetter C
# calculate the maximum size (1MB aligned).
# NB when running in the hyperv hypervisor, the size must be must multiple of
#    1MB, otherwise, it fails with:
#       The size of the extent is less than the minimum of 1MB.
$sizeMax = $partitionSupportedSize.SizeMax - ($partitionSupportedSize.SizeMax % (1*1024*1024))
if ($partition.Size -lt $sizeMax) {
    Write-Output "Expanding the C: partition from $($partition.Size) to $sizeMax bytes..."
    Resize-Partition -DriveLetter C -Size $sizeMax
}

# NB the first network adapter is the vagrant management interface
#    which we do not modify.
# NB this is somewhat brittle: InterfaceIndex sometimes does not enumerate
#    the same way, so we use MacAddress instead, as it seems to work more
#    reliably; but this is not ideal either.
# TODO somehow use the MAC address to set the IP addresses.
$adapters = @(Get-NetAdapter -Physical | Sort-Object MacAddress | Select-Object -Skip 1)

for ($n = 0; $n -lt $adapters.Length; ++$n) {
    $adapter = $adapters[$n]
    Write-Output "Setting the $($adapter.Name) ($($adapter.MacAddress)) adapter IP address to $($addresses[$n])..."
    $adapter | New-NetIPAddress `
        -IPAddress $addresses[$n] `
        -PrefixLength 24 `
        | Out-Null
    $adapter | Set-NetConnectionProfile `
        -NetworkCategory Private `
        | Out-Null
}
