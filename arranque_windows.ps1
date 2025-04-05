# arranque_windows.ps1

# Este script se ejecuta automáticamente al inicio de la instancia de Windows Server 2019.

# Actualizar Windows
Write-Host "Actualizando Windows..."
Install-WindowsUpdate -AcceptAll -AutoReboot

# Habilitar Remote Desktop Protocol (RDP)
Write-Host "Habilitando RDP..."
$RdpKey = "HKLM:\System\CurrentControlSet\Control\Terminal Server"
Set-ItemProperty -Path $RdpKey -Name fDenyTSConnections -Value 0

# Configurar Firewall para permitir RDP
Write-Host "Configurando el firewall para permitir RDP..."
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Reiniciar servicio de red para aplicar cambios
Write-Host "Reiniciando los servicios necesarios..."
Restart-Service -Name "TermService"

# Crear un archivo de prueba en la carpeta de inicio
Write-Host "Creando archivo de prueba para verificar la ejecución del script..."
New-Item -Path "C:\Users\Administrator\Desktop" -Name "RDP_Configuration_Success.txt" -ItemType File

Write-Host "Configuración completada."