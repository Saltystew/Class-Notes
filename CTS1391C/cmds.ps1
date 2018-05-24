
## Create internal virtual switch named Public
New-VMSwitch -Name Public -SwitchType Internal

## Add an ip address to the previously created virtual switch interface
New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 16 -InterfaceAlias 'vEthernet (Public)'

## Add dns addresses to the previously created virtual switch interface
Set-DnsClientServerAddress -ServerAddresses 10.13.2.5,10.13.2.7 -InterfaceAlias 'vEthernet (Public)'

## Enable NAT for 172.16/16 network
New-NetNat -InternalIPInterfaceAddressPrefix 172.16.0.0/16 -Name Public

# Create three drives for vms
New-VHD -Path 'C:\users\Public\Documents\Hyper-V\Virtual hard disks\dns1.vhdx' -ParentPath D:\VHDs\Parent\20181_S2016Eval.vhdx
New-VHD -Path 'C:\users\Public\Documents\Hyper-V\Virtual hard disks\dns2.vhdx' -ParentPath D:\VHDs\Parent\20181_S2016Eval.vhdx
New-VHD -Path 'C:\users\Public\Documents\Hyper-V\Virtual hard disks\www.vhdx' -ParentPath D:\VHDs\Parent\20181_S2016Eval.vhdx

# Install features for VMs
Install-WindowsFeature -Name DNS -IncludeManagementTools -Vhd 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dns1.vhdx'
Install-WindowsFeature -Name DNS -IncludeManagementTools -Vhd 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dns2.vhdx'
Install-WindowsFeature -Name Web-Server -IncludeManagementTools -Vhd 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\www.vhdx'

# Create VMs
New-VM -Name DNS1 -Generation 2 -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dns1.vhdx'
New-VM -Name DNS2 -Generation 2 -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dns2.vhdx'
New-VM -Name WWW -Generation 2 -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\www.vhdx'

# Set all VMs to dynamic memory
Set-VMMemory -DynamicMemoryEnabled:$true *

# Sleep for 60 seconds
Start-Sleep -Seconds 60

# Start all VMs
Start-VM *

# Auth variables
$localUser = 'administrator'
$pwd = ConvertTo-SecureString 'Pa11word' -AsPlainText -Force
$localAuth = New-Object System.Management.Automation.PSCredential($localUser,$pwd)

# Connect to VM DNS1 and set IP, DNS, and Computer name, and then restart
Invoke-Command -VMName DNS1 -Credential $localAuth -ScriptBlock {
    New-NetIPAddress -IPAddress 172.16.0.2 -PrefixLength 16 -InterfaceAlias 'Ethernet' -DefaultGateway 172.16.0.1
    Set-DnsClientServerAddress -ServerAddresses 127.0.0.1 -InterfaceAlias *
    Rename-Computer -NewName "cs03-dns1" -Restart
}

# Connect to VM DNS2 and set IP, DNS, and Computer name, and then restart
Invoke-Command -VMName DNS2 -Credential $localAuth -ScriptBlock {
    New-NetIPAddress -IPAddress 172.16.0.3 -PrefixLength 16 -InterfaceAlias 'Ethernet' -DefaultGateway 172.16.0.1
    Set-DnsClientServerAddress -ServerAddresses 172.16.0.2 -InterfaceAlias *
    Rename-Computer -NewName "cs03-dns2" -Restart
}

# Connect to VM WWW and set IP, DNS, and Computer name, and then restart
Invoke-Command -VMName WWW -Credential $localAuth -ScriptBlock {
    New-NetIPAddress -IPAddress 172.16.0.4 -PrefixLength 16 -InterfaceAlias Ethernet -DefaultGateway 172.16.0.1
    Set-DnsClientServerAddress -ServerAddresses 172.16.0.2,172.16.0.3 -InterfaceAlias *
    Rename-Computer -NewName "cs03-www" -Restart
}

# Optional: Enable ping
Import-Module NetSecurity
Set-NetFirewallRule -DisplayName “File and Printer Sharing (Echo Request – ICMPv4-In)” -enabled True
Set-NetFirewallRule -DisplayName “File and Printer Sharing (Echo Request – ICMPv4-Out)” -enabled True
Set-NetFirewallRule -DisplayName “File and Printer Sharing (Echo Request – ICMPv6-In)” -enabled True
Set-NetFirewallRule -DisplayName “File and Printer Sharing (Echo Request – ICMPv6-Out)” -enabled True

# Make DHCP & Client VMs
New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dhcp.vhdx' -ParentPath D:\VHDs\Parent\20181_S2016Eval.vhdx
New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\client.vhdx' -ParentPath D:\VHDs\Parent\20181_Win10Eval.vhdx

# Install DHCP
Install-WindowsFeature -Name DHCP -IncludeManagementTools -Vhd 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dhcp.vhdx'

# Create new VMs
New-VM -name DHCP -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\dhcp.vhdx' -Generation 2 -Force
New-VM -name Client -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\client.vhdx' -Generation 2 -Force

# Set memory to dynamic
Set-VMMemory -VMName DHCP -DynamicMemoryEnabled:$true
Set-VMMemory -VMName Client -DynamicMemoryEnabled:$true

# Start VMs
Start-VM -VMName DHCP
Start-VM -VMName Client

# If using a Linux client then run the following
New-VHD -Path 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\client-linux.vhdx' -ParentPath D:\VHDs\Parent\20181_CentOS7.vhdx
New-VM -Name Client-Linux -SwitchName Public -VHDPath 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\client-linux.vhdx' -Generation 2 -Force
Set-VMMemory -VMName Client-Linux -DynamicMemoryEnabled:$true
Set-VMFirmware -EnableSecureBoot off -VMName Client-Linux
Start-VM -VMName Client-Linux
