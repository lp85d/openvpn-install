Set-ExecutionPolicy Bypass -Scope Process -Force

if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

choco install openvpn -y

$openVPNPath = "C:\Program Files\OpenVPN"
$easyRSAPath = "$openVPNPath\easy-rsa"
$configPath = "$openVPNPath\config"

Set-Location $easyRSAPath
Start-Process -FilePath "$easyRSAPath\EasyRSA-Start.bat" -Wait
Start-Process -FilePath "$easyRSAPath\easyrsa.exe" -ArgumentList "init-pki" -Wait
Start-Process -FilePath "$easyRSAPath\easyrsa.exe" -ArgumentList "build-ca nopass" -Wait
Start-Process -FilePath "$easyRSAPath\easyrsa.exe" -ArgumentList "build-server-full server nopass" -Wait
Start-Process -FilePath "$easyRSAPath\easyrsa.exe" -ArgumentList "gen-dh" -Wait
& "$openVPNPath\bin\openvpn.exe" --genkey --secret "$configPath\ta.key"

Copy-Item "$easyRSAPath\pki\ca.crt" "$configPath"
Copy-Item "$easyRSAPath\pki\issued\server.crt" "$configPath"
Copy-Item "$easyRSAPath\pki\private\server.key" "$configPath"
Copy-Item "$easyRSAPath\pki\dh.pem" "$configPath"

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

$action = New-ScheduledTaskAction -Execute "$openVPNPath\bin\openvpn.exe" -Argument "--config `"$configPath\server.ovpn`""
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "OpenVPN Server" -Description "Auto-start OpenVPN server"
