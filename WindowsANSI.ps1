# Set the encoding to ANSI
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(1251)
Write-Output "Setting encoding to ANSI..."

# Define paths and URLs
$easyRSADownloadURL = "https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.1/EasyRSA-3.2.1-win64.zip"
$tempZipPath = "$env:TEMP\EasyRSA.zip"
$openVPNPath = "C:\Program Files\OpenVPN"
$easyRSAPath = "$openVPNPath\easy-rsa"

# Ensure OpenVPN directory exists
if (-Not (Test-Path $openVPNPath)) {
    Write-Error "OpenVPN path not found: $openVPNPath"
    exit
}

# Download EasyRSA
Write-Output "Downloading EasyRSA..."
try {
    Invoke-WebRequest -Uri $easyRSADownloadURL -OutFile $tempZipPath -ErrorAction Stop
} catch {
    Write-Error "Failed to download EasyRSA. Check the URL: $easyRSADownloadURL"
    exit
}

# Extract EasyRSA
Write-Output "Extracting EasyRSA..."
try {
    if (Test-Path $tempZipPath) {
        tar -xf $tempZipPath -C $openVPNPath
        $extractedFolder = Get-ChildItem -Path $openVPNPath -Directory | Where-Object { $_.Name -like "EasyRSA-*" } | Select-Object -First 1
        if ($null -eq $extractedFolder) {
            throw "Extraction failed: Folder not found."
        }

        # Удаляем папку easy-rsa, если она уже существует
        if (Test-Path $easyRSAPath) {
            Remove-Item -Path $easyRSAPath -Recurse -Force
        }

        Rename-Item -Path $extractedFolder.FullName -NewName "easy-rsa"
        Remove-Item $tempZipPath -Force
    } else {
        throw "Temporary archive not found: $tempZipPath"
    }
} catch {
    Write-Error "Failed to extract EasyRSA. Error: $($_.Exception.Message)"
    exit
}

# Initialize EasyRSA
Set-Location $easyRSAPath
Write-Output "Initializing EasyRSA..."
try {
    Start-Process -FilePath ".\EasyRSA-Start.bat" -Wait
    .\easyrsa init-pki
    .\easyrsa build-ca nopass
    .\easyrsa build-server-full server nopass
    .\easyrsa gen-dh
} catch {
    Write-Error "Failed to initialize EasyRSA. Error: $($_.Exception.Message)"
    exit
}

# Copy generated files
Write-Output "Copying generated files..."
$configPath = "$openVPNPath\config"
if (-Not (Test-Path $configPath)) {
    New-Item -ItemType Directory -Path $configPath | Out-Null
}

try {
    Copy-Item "$easyRSAPath\pki\ca.crt" "$configPath"
    Copy-Item "$easyRSAPath\pki\issued\server.crt" "$configPath"
    Copy-Item "$easyRSAPath\pki\private\server.key" "$configPath"
    Copy-Item "$easyRSAPath\pki\dh.pem" "$configPath"
} catch {
    Write-Error "Failed to copy generated files. Error: $($_.Exception.Message)"
    exit
}

Write-Output "EasyRSA setup completed successfully."

# Add task to Task Scheduler
Write-Output "Configuring Task Scheduler..."
try {
    # Удаляем задачу, если она уже существует
    if (Get-ScheduledTask -TaskName "OpenVPN Server" -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName "OpenVPN Server" -Confirm:$false
    }
    
    $taskAction = New-ScheduledTaskAction -Execute "$openVPNPath\bin\openvpn.exe" -Argument "--config $configPath\server.ovpn"
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    
    Register-ScheduledTask -TaskName "OpenVPN Server" -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Force
} catch {
    Write-Error "Failed to configure Task Scheduler. Error: $($_.Exception.Message)"
    exit
}

Write-Output "Script completed successfully."
