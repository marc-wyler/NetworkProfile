# ------------------------ Create EventLog ------------------------ #
if ([System.Diagnostics.EventLog]::Exists('AM_NetworkLog') -eq $true) {  
    Write-Host "EventLog IP exists"
} else { 
    New-EventLog -LogName "AM_NetworkLog" -Source "NetworkProfile" 
}

# ------------------------ Path NetID Installation ------------------------ #
$IPAddressInstall = 'C:\Windows\OEM\Network\NetID.txt' 
$TestIPAddressPath = Test-Path $IPAddressInstall  

### check if file exists, if not write into the EventLog
if ($TestIPAddressPath -eq $true) { 
    Write-Host "NetID Path exists" 
} else {
    Write-Host "NetID Path does not exist" 
    Write-EventLog -LogName "AM_NetworkLog" -EventId 1 -Source "NetworkProfile"  -EntryType Information -Message "NetID Path does not exist." -ErrorAction SilentlyContinue
    exit
}

### more than 2 dots in string -> error
$count = Get-Content $IPAddressInstall -ErrorAction SilentlyContinue
# delete all characters except the dot "."  // delete generated space
$count2 = $count -replace '[^.]','' -replace '\s',''

### if there are more (gt) than 2 dots write into the logfile
if ($count2.length -gt 2) { 
    Write-Host "IP not Ok <more>" 
    Write-EventLog -LogName "AM_NetworkLog" -EventId 2 -Source "NetworkProfile"  -EntryType Information -Message "The IP Address is not correct (to long)."
    exit
}

### if there are less (lt) than 2 dots write into the logfile
if ($count2.length -lt 2) { 
    Write-Host "IP not Ok <less>" 
    Write-EventLog -LogName "AM_NetworkLog" -EventId 3 -Source "NetworkProfile" -EntryType Information -Message "The IP Address is not correct (to short)."
    exit
} 

### when there are only 2 dots 
if ($count2.length -eq 2) { 
    Write-Host "IP Ok" 
    # ------------------------ Check if DHCP is enabled  ------------------------ #
    $DHCP = 'C:\Windows\Temp\DHCP.txt' # temporary file
    $IPEnabled = Get-WmiObject -Class Win32_NetworkAdapter | Select-Object NetConnectionID | Where-Object {$_.Name -like "LAN1"} | Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=True -ComputerName $env:COMPUTERNAME
    Out-File -FilePath $DHCP -InputObject $IPEnabled
    $StatusDHCP = Get-Content $DHCP 
    $containsWord = $StatusDHCP | ForEach-Object{$_ -match "True"}
    
    if ($containsWord -contains $true) {
        Write-Host "Host is set to DHCP"  
        Write-EventLog -LogName "AM_NetworkLog" -EventId 4 -Source "NetworkProfile" -EntryType Information -Message "DHCP is enabled."
        $IPAddressHost = 'C:\Windows\Temp\IPAddress.txt' # temporary file
        $IPAddressHost2 = 'C:\Windows\Temp\IPAddress2.txt' # temporary file
                
        Get-NetIPAddress -InterfaceAlias LAN1 | Select-Object IPAddress | Where-Object { $_.IPAddress -like "*.*.*.*"} | Out-File $IPAddressHost #-like "*.*.*.*" da auch MAC angezeigt wird
        Get-Content $IPAddressHost | Select-Object -Index 3 | Out-File $IPAddressHost2
        $shortIP = Get-Content $IPAddressHost2
        $shortIP = $shortIP.Substring(0, $shortIP.LastIndexOf(".")) #löscht alle Charakter bis und mit zum letzten . (von hinten nach vorne)
        Out-File -FilePath $IPAddressHost2 -InputObject $shortIP
        $CompareHost = Get-Content $IPAddressHost2
        $CompareInstall = Get-Content $IPAddressInstall
        } 
        
        if (Compare-Object $CompareHost $CompareInstall) {
        Write-Host "IP is different"   # output for testing             
        Write-EventLog -LogName "AM_NetworkLog" -EventId 6 -Source "NetworkProfile" -EntryType Information -Message "IP address is different from the installed IP Address. Current IP range: $(Get-Content $IPAddressHost2)"  
        Remove-Item $DHCP -Force
        Remove-Item $IPAddressHost -Force
        Remove-Item $IPAddressHost2 -Force   
        exit
        } else {
        Write-Host "Same IP"  # output for testing 
        # ------------------------ check network profile settings ------------------------ #
        $AktProfile = 'C:\Windows\Temp\NetworkProfile.txt' # temporary file
        $ProfileSettings = Get-NetConnectionProfile -InterfaceAlias LAN1
        Out-File -FilePath $AktProfile -InputObject $ProfileSettings
        $StatusProfile = Get-Content $AktProfile | Select-String 'Public', 'Private', 'DomainAuthenticated'
        $StatusProfile2 = $StatusProfile -Replace "NetworkCategory" -replace " " -replace ":" -replace ""

            # ------------------------ network profile is set to "public" ------------------------ #
            if ($StatusProfile2 -eq 'Public') {
            Write-EventLog -LogName "AM_NetworkLog" -EventId 7 -Source "NetworkProfile" -EntryType Information -Message 'The network profile was set to public. Changed network profile to private.'
            Set-NetConnectionProfile -InterfaceAlias LAN1 -NetworkCategory Private
            Write-Host "Changed network profile to Private" # output for testing 
            Remove-Item -Path $AktProfile -Force
            Remove-Item -Path $DHCP -Force
            Remove-Item -Path $IPAddressHost -Force
            Remove-Item -Path $IPAddressHost2 -Force
            exit
            }

    
    if ($StatusProfile2 -eq 'Public') {
        Write-EventLog -LogName "AM_NetworkLog" -EventId 7 -Source "NetworkProfile" -EntryType Information -Message 'The network profile was set to public. Changed network profile to private.'
        Set-NetConnectionProfile -InterfaceAlias LAN1 -NetworkCategory Private
        Remove-Item -Path $AktProfile -Force
        Remove-Item -Path $DHCP -Force
        Write-Host "Changed network profile setting to Private" # output for testing
    } else {
        Remove-Item -Path $AktProfile -Force
        Remove-Item -Path $DHCP -Force
        Write-Host "Host is not set to Public" # output for testing 
    }
    exit   
    } else {
        # ------------------------ Host has a assigned IP Address ------------------------ #
        Write-Host "Host has an assigned IP Address" # output for testing 
        $IPAddressHost = 'C:\Windows\Temp\IPAddress.txt' # temporary file
        $IPAddressHost2 = 'C:\Windows\Temp\IPAddress2.txt' # temporary file
        $txtchecknet = 'C:\Windows\Temp\NetConnection.txt'
        $checknetconnid = get-wmiobject win32_networkadapter -filter "netconnectionid = 'LAN1'" | Select-Object  Name, InterfaceIndex, NetConnectionStatus
        Out-File -FilePath $txtchecknet -InputObject $checknetconnid
        $StatusNetConn = Get-Content $txtchecknet 
        $containsNet = $StatusNetConn | ForEach-Object{$_ -match "2"} #2 = connected

    if ($containsNet -contains $true) {
        Write-Host "Host is connected to the LAN1" 
        Get-NetIPAddress -InterfaceAlias LAN1 | Select-Object IPAddress | Where-Object { $_.IPAddress -like "*.*.*.*"} | Out-File $IPAddressHost #-like "*.*.*.*" da auch MAC angezeigt wird
        Get-Content $IPAddressHost | Select-Object -Index 3 | Out-File $IPAddressHost2
        $shortIP = Get-Content $IPAddressHost2
        $shortIP = $shortIP.Substring(0, $shortIP.LastIndexOf(".")) #löscht alle Charakter bis und mit zum letzten . (von hinten nach vorne)
        Out-File -FilePath $IPAddressHost2 -InputObject $shortIP
        $CompareHost = Get-Content $IPAddressHost2
        $CompareInstall = Get-Content $IPAddressInstall
    } else {
        Write-Host "Host is not connected to the LAN1" 
        Write-EventLog -LogName "AM_NetworkLog" -EventId 5 -Source "NetworkProfile" -EntryType Information -Message 'Computer is not connected to the Network Interface LAN1.'
        Remove-Item $DHCP -Force 
        Remove-Item $txtchecknet -Force 
        exit
    }  
            
    # ------------------------ compare NetID Address and current IP Address of the computer ------------------------ # 
    if (Compare-Object $CompareHost $CompareInstall) {
        Write-Host "IP is different"   # output for testing             
        Write-EventLog -LogName "AM_NetworkLog" -EventId 6 -Source "NetworkProfile" -EntryType Information -Message "IP address is different from the installed IP Address. Current IP range: $(Get-Content $IPAddressHost2)"  
        Remove-Item $DHCP -Force
        Remove-Item $IPAddressHost -Force
        Remove-Item $IPAddressHost2 -Force  
        Remove-Item $txtchecknet -Force 
        exit
    } else {
        Write-Host "Same IP"  # output for testing 
        # ------------------------ check network profile settings ------------------------ #
        $AktProfile = 'C:\Windows\Temp\NetworkProfile.txt' # temporary file
        $ProfileSettings = Get-NetConnectionProfile -InterfaceAlias LAN1
        Out-File -FilePath $AktProfile -InputObject $ProfileSettings
        $StatusProfile = Get-Content $AktProfile | Select-String 'Public', 'Private', 'DomainAuthenticated'
        $StatusProfile2 = $StatusProfile -Replace "NetworkCategory" -replace " " -replace ":" -replace ""

            # ------------------------ network profile is set to "public" ------------------------ #
            if ($StatusProfile2 -eq 'Public') {
            Write-EventLog -LogName "AM_NetworkLog" -EventId 7 -Source "NetworkProfile" -EntryType Information -Message 'The network profile was set to public. Changed network profile to private.'
            Set-NetConnectionProfile -InterfaceAlias LAN1 -NetworkCategory Private
            Write-Host "Changed network profile to Private" # output for testing 
            Remove-Item -Path $AktProfile -Force
            Remove-Item -Path $DHCP -Force
            Remove-Item -Path $IPAddressHost -Force
            Remove-Item -Path $IPAddressHost2 -Force
            Remove-Item -Path $txtchecknet -Force 
            exit                                                       
            } else {
            # ------------------------ network profile is not public ------------------------ #
            Write-Host "Everything is Ok" # output for testing      
            Remove-Item -Path $AktProfile -Force
            Remove-Item -Path $DHCP -Force
            Remove-Item -Path $IPAddressHost -Force
            Remove-Item -Path $IPAddressHost2 -Force
            Remove-Item -Path $txtchecknet -Force 
            exit
            } 
        } 
    }            
} 
