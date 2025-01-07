$openVPNPath = "C:\Program Files\OpenVPN"
$easyRSAPath = "$openVPNPath\easy-rsa"
$configPath = "$openVPNPath\config"

if (-Not (Test-Path $easyRSAPath)) {
    $easyRSADownloadURL = "https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.5/EasyRSA-3.1.5.zip"
    $tempZipPath = "$env:TEMP\EasyRSA.zip"
    Invoke-WebRequest -Uri $easyRSADownloadURL -OutFile $tempZipPath
    Expand-Archive -Path $tempZipPath -DestinationPath $openVPNPath -Force
    Rename-Item -Path "$openVPNPath\EasyRSA-3.1.5" -NewName "easy-rsa"
    Remove-Item $tempZipPath
}

Set-Location $easyRSAPath

if (-Not (Test-Path "$easyRSAPath\pki")) {
    .\EasyRSA-Start.bat
    .\easyrsa.exe init-pki
}

if (-Not (Test-Path "$easyRSAPath\pki\ca.crt")) {
    .\easyrsa.exe build-ca nopass
}

if (-Not (Test-Path "$easyRSAPath\pki\issued\server.crt")) {
    .\easyrsa.exe build-server-full server nopass
}

if (-Not (Test-Path "$easyRSAPath\pki\dh.pem")) {
    .\easyrsa.exe gen-dh
}

if (-Not (Test-Path $configPath)) {
    New-Item -Path $configPath -ItemType Directory
}

Copy-Item "$easyRSAPath\pki\ca.crt" "$configPath"
Copy-Item "$easyRSAPath\pki\issued\server.crt" "$configPath"
Copy-Item "$easyRSAPath\pki\private\server.key" "$configPath"
Copy-Item "$easyRSAPath\pki\dh.pem" "$configPath"

if (Get-ScheduledTask -TaskName "OpenVPN Server" -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName "OpenVPN Server" -Confirm:$false
}

$action = New-ScheduledTaskAction -Execute "$openVPNPath\bin\openvpn.exe" -Argument "server.ovpn"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "OpenVPN Server" -Description "Start OpenVPN Server on system startup"
