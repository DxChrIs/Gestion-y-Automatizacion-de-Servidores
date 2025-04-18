# Función para elevar el script automáticamente si no tiene privilegios de administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Habilitar PowerShell Remoting
Enable-PSRemoting -Force

# Configurar WinRM para iniciar automáticamente
Set-Service WinRM -StartupType Automatic
Start-Service WinRM

# Configurar autenticación WinRM (Basic, Certificate, AllowUnencrypted, CredSSP)
$authPaths = @(
    @{Path="WSMan:\localhost\Service\Auth\Certificate"; Value=$true},
    @{Path="WSMan:\localhost\Service\Auth\Basic"; Value=$true},
    @{Path="WSMan:\localhost\Service\AllowUnencrypted"; Value=$true},
    @{Path="WSMan:\localhost\Service\Auth\CredSSP"; Value=$true}
)

foreach ($item in $authPaths) {
    try {
        Set-Item -Path $item.Path -Value $item.Value -Force
    } catch {
        # Ignorar errores en la configuración de autenticación
    }
}

# Agregar reglas de firewall para WinRM e ICMP
$firewallRules = @(
    @{Name="Allow WinRM HTTP"; Port=5985; Protocol="TCP"},
    @{Name="Allow ICMPv4-In"; Protocol="ICMPv4"; IcmpType=8},
    @{Name="Allow ICMPv6-In"; Protocol="ICMPv6"; IcmpType=128}
)

foreach ($rule in $firewallRules) {
    try {
        if ($rule.Port) {
            New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -LocalPort $rule.Port -Protocol $rule.Protocol -Action Allow -ErrorAction Stop
        } else {
            New-NetFirewallRule -DisplayName $rule.Name -Protocol $rule.Protocol -IcmpType $rule.IcmpType -Direction Inbound -Action Allow -ErrorAction Stop
        }
    } catch {
        # Ignorar errores en la creación de reglas de firewall
    }
}

# Configurar LocalAccountTokenFilterPolicy
try {
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
                    -Name "LocalAccountTokenFilterPolicy" -PropertyType DWord -Value 1 -Force
} catch {
    # Ignorar errores en la configuración de LocalAccountTokenFilterPolicy
}

# Establecer política de ejecución de PowerShell
try {
    Set-ExecutionPolicy Unrestricted -Force
} catch {
    # Ignorar errores en la configuración de política de ejecución
}

# Configurar TrustedHosts
try {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
} catch {
    # Ignorar errores en la configuración de TrustedHosts
}

# Reiniciar servicio WinRM
Restart-Service WinRM
