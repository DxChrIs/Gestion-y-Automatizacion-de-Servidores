#Enable Powershell remoting
Enable-PSRemoting -Force

#Set WinRM service startup type to automatic
Set-Service WinRM -StartupType 'Automatic'

#Configure WinRM to allow unencrypted traffic and basic authentication
Set-Item -Path WSMan:\localhost\Service\Auth\Certificate -Value $true
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
Set-Item -Path WSMan:\localhost\Service\Auth\CredSSP -Value $true

#Create a Firewall rule to allow WinRM HTTP inbound traffic
New-NetFirewallRule -DisplayName "Allow WinRM HTTP" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow
New-NetFirewallRule -DisplayName "Allow ICMPv6-In" -Protocol ICMPv6 -IcmpType 128 -Direction Inbound -Action Allow

#Configure TrustedHosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

#Restart WinRM service to apply changes
Restart-Service WinRM