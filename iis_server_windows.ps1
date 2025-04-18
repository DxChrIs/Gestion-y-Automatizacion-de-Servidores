<powershell>
    Start-Transcript -Path "C:/iis_server_windows.txt" -Append
    #Enable Powershell remoting
    Enable-PSRemoting -Force
    #Set WinRM service startup type to automatic
    Set-Service WinRM -StartupType 'Automatic'
    #Configure WinRM to allow unencrypted traffic and basic authentication
    Set-Item -Path WSMan:\localhost\Service\Auth\Certificate -Value $true
    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item -Path WSMan:\localhost\Service\Auth\CredSSP -Value $true
    #Create a Firewall rule to allow WinRM HTTP inbound traffic
    New-NetFirewallRule -DisplayName "Allow WinRM HTTP" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow
    New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow
    New-NetFirewallRule -DisplayName "Allow ICMPv6-In" -Protocol ICMPv6 -IcmpType 128 -Direction Inbound -Action Allow
    #Set LocalAccountTokenFilterPolicy
    New-ItemProperty -Name LocalAccountTokenFilterPolicy -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -PropertyType DWord -Value 1 -Force
    #Set Execution Policy to Unrestricted
    Set-ExecutionPolicy Unrestricted -Force
    #Configure TrustedHosts
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    #Restart WinRM service to apply changes
    Restart-Service WinRM
    Stop-Transcript
</powershell>
<persist>true</persist>