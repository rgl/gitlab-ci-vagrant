param(
    $dnsServerAddress
)

# NB this is somewhat brittle: InterfaceIndex sometimes does not enumerate
#    the same way, so we use MacAddress instead, as it seems to work more
#    reliably; but this is not ideal either.
# TODO somehow use the MAC address to set the IP addresses.
$adapters = @(Get-NetAdapter -Physical | Sort-Object MacAddress)

# nutter the vagrant management interface.
$adapters[0] | Set-DnsClientServerAddress -ServerAddresses '127.0.0.1'

# real dns requests go to the gitlab dns server.
# NB this is needed as a workaround for being able to access
#    our custom domain from a windows container.
# see provision-gitlab-runner.ps1
$adapters[1] | Set-DnsClientServerAddress -ServerAddresses $dnsServerAddress
