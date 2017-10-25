<#
.SYNOPSIS
PowerCLI script used to check for duplicate MAC addresses across a vCenter instance.

.DESCRIPTION
This script gathers MAC addresses for all vmkernel and virtual machine vNIC interfaces and reports any duplicates.
Physical NIC MAC addresses are not compared.  vmk0 automatically shares vnic0's MAC address at creation.

.PARAMETER VIServer
Specifies a FQDN vCenter name that you'd like to scan.

.EXAMPLE
Get-DuplicateMacAddresses [-VIServer <vCenterFQDN>]

.NOTES
Mark Wolfe
2017-10-05

#>

Param(
  [Parameter(Mandatory=$true, Position=0, HelpMessage="Which vCenter server?")]
  [string]$VIServer
)

Write-Host "Connecting to $VIServer..."
Connect-VIServer -Server $VIServer -ErrorAction Stop | Out-Null
Write-Host "Scanning $VIServer for duplicate MAC addresses.."

$VMHosts = Get-VMHost | Sort-Object Name
$VMs = Get-VM | Sort-Object Name
$MacTable = @()
$i = 0

foreach ($VMHost in $VMHosts){
    Write-Progress -Activity "Gathering VM Host information" -Status "Host $i of $($VMHosts.count) complete." -PercentComplete (($i / $VMHosts.Count) * 100)
    $i++
    $VirtualNICs = $VMHost | Get-VMHostNetworkAdapter -VMKernel
    foreach ($vmk in $VirtualNICs){
        $MacEntry = [PSCustomObject] @{
            Hostname = $VMHost.Name
            Interfacetype = "vmkernel"
            Interfacename = $vmk.name
            IP = $vmk.IP
            NetworkName = $vmk.PortGroupName
            MAC = $vmk.Mac
        }
        $MacTable += $MacEntry
        }
    }


$i = 0

foreach ($VM in $VMs){
    Write-Progress -Activity "Gathering VM information" -Status "VM $i of $($VMs.count) complete." -PercentComplete (($i / $VMs.Count) * 100)
    $i++
    $NICs = $VM | Get-NetworkAdapter
     foreach ($NIC in $NICs){
            $MacEntry = [PSCustomObject] @{
                Hostname = $VM.name
                Interfacetype = "VM vNIC"
                Interfacename = $NIC.Name
                NetworkName = $NIC.NetworkName
                MAC = $NIC.MacAddress
            }
        $MacTable += $MacEntry
        }
    }

$vmkCount = $MacTable | Where-Object {$_.Interfacetype -eq "vmkernel"}
$vmCount = $MacTable | Where-Object {$_.Interfacetype -eq "VM vNIC"}
Write-Host "Number of VM Hosts:" $VMHosts.count
Write-Host "Number of VMs:" $VMs.count
Write-Host "Number of vmk interfaces:" $vmkCount.count
Write-Host "Number of VM interfaces:" $vmCount.count
Write-Host "Total number of MAC addresses:" $MacTable.count

$DupeMacs = $MacTable | Group-Object MAC | Where-Object {$_.count -gt 1}

if ($DupeMacs -ne $null){
    Write-Host -ForegroundColor Red "`n`nDuplicate MAC addresses found:"
    $DupeMacs.Group | Select-Object Hostname, Interfacetype, Interfacename, NetworkName, MAC | Format-Table
    }
if ($DupeMacs -eq $null){
    Write-Host -Foregroundcolor Green "`n`nNo duplicate MAC addresses found."
    }

Write-Host "`n`nDuplicate MAC address check complete!`n`n"
Write-Host "Disconnecting from vCenter Server $VIServer"
Disconnect-VIServer -Server $VIServer -Confirm:$False