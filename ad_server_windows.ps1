<powershell>
    Start-Transcript -Path "C:/ad_server_windows.txt" -Append
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
    # Verificar si el servidor ya es un controlador de dominio
    $dcCheck = Get-ADDomainController -Filter * -ErrorAction SilentlyContinue
    if ($dcCheck) {
        Write-Output "Este servidor ya es un controlador de dominio."
    } else {
        Write-Output "Este servidor NO es un controlador de dominio. Procediendo con la promocion..."
        # Instalar los roles necesarios para la promoción del controlador de dominio
        Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
        # Importar el módulo de despliegue de AD DS
        Import-Module ADDSDeployment
        # Promover el servidor a un controlador de dominio
        Install-ADDSForest `
            -DomainName "chrisyjaime.com.mx" `
            -DomainNetbiosName "GDL-DC-01" `
            -SafeModeAdministratorPassword (ConvertTo-SecureString "ElAdministrador1853" -AsPlainText -Force) `
            -InstallDNS `
            -Force
        Write-Output "La promocion a controlador de dominio se ha iniciado. El servidor se reiniciara."
    }
    Stop-Transcript
</powershell>
<persist>true</persist>