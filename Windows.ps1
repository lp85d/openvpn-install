# Убедитесь, что запуск скриптов разрешен
Set-ExecutionPolicy Bypass -Scope Process -Force

# Установите Chocolatey, если он еще не установлен
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Установка Chocolatey..."
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Установка OpenVPN через Chocolatey
Write-Host "Установка OpenVPN..."
choco install openvpn -y

# Путь к OpenVPN
$openVPNPath = "C:\Program Files\OpenVPN"
$easyRSAPath = "$openVPNPath\easy-rsa"
$configPath = "$openVPNPath\config"

# Перейдем в каталог easy-rsa и инициализируем PKI
Write-Host "Настройка PKI..."
Set-Location $easyRSAPath
Start-Process -FilePath "$easyRSAPath\EasyRSA-Start.bat" -Wait
Start-Process -FilePath "$easyRSAPath\easyrsa.exe" -ArgumentList "init-pki" -Wait

# Генерация CA (сертификата центра сертификации)
Write-Host "Создание CA..."
Start-Process -FilePath "$easyRSAPath\easyrsa.exe" -ArgumentList "build-ca nopass" -Wait

# Генерация серверного ключа и сертификата
Write-Host "Создание серверного ключа и сертификата..."
Start-Process -FilePath "$easyRSAPath\easyrsa.exe" -ArgumentList "build-server-full server nopass" -Wait

# Генерация ключей Diffie-Hellman
Write-Host "Создание Diffie-Hellman ключей..."
Start-Process -FilePath "$easyRSAPath\easyrsa.exe" -ArgumentList "gen-dh" -Wait

# Генерация TLS-ключа
Write-Host "Создание TLS-ключа..."
& "$openVPNPath\bin\openvpn.exe" --genkey --secret "$configPath\ta.key"

# Копирование сертификатов и ключей в папку конфигурации
Write-Host "Копирование сертификатов..."
Copy-Item "$easyRSAPath\pki\ca.crt" "$configPath"
Copy-Item "$easyRSAPath\pki\issued\server.crt" "$configPath"
Copy-Item "$easyRSAPath\pki\private\server.key" "$configPath"
Copy-Item "$easyRSAPath\pki\dh.pem" "$configPath"

# Создание конфигурационного файла OpenVPN-сервера
Write-Host "Создание конфигурационного файла сервера..."
$serverConfig = @"
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
keepalive 10 120
cipher AES-256-CBC
persist-key
persist-tun
status openvpn-status.log
log openvpn.log
verb 3
"@
$serverConfig | Out-File -Encoding ASCII "$configPath\server.ovpn"

# Настройка автозагрузки OpenVPN-сервера
Write-Host "Добавление OpenVPN в автозагрузку..."
$action = New-ScheduledTaskAction -Execute "$openVPNPath\bin\openvpn.exe" -Argument "--config '$configPath\server.ovpn'"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "OpenVPN Server" -Description "Auto-start OpenVPN server"

Write-Host "Настройка завершена. Перезагрузите систему для применения изменений."