####### IMPORTANT #######
# THIS IS ONLY A BACKUP
# IT IS NOT SYMLINKED

function global:pause ($message) {
    # Check if running Powershell ISE
    if ($psISE) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("$message")
    }
    else {
        Write-Host "$message" -ForegroundColor Yellow
        $x = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Convert-WSLPathToWindows {
    param (
        [string]$wslPath
    )
    return (wsl.exe wslpath -w $wslPath).Trim()
}

function Invoke-UpgradeScript {
    $wslPath = "/home/anon/repos/personal/ivystopia.github.io/scripts/files/UpgradeAndReboot.ps1"
    $windowsPath = Convert-WSLPathToWindows -wslPath $wslPath
    Unblock-File -Path $windowsPath
    echo "R" | powershell.exe -File $windowsPath
}
Set-Alias -Name upgrade -Value Invoke-UpgradeScript

function Invoke-ForwardPortsScript {
    $wslPath = "/home/anon/repos/personal/ivystopia.github.io/scripts/files/ForwardPorts.ps1"
    $windowsPath = Convert-WSLPathToWindows -wslPath $wslPath
    Unblock-File -Path $windowsPath
    echo "R" | powershell.exe -File $windowsPath
}
Set-Alias -Name forwardports -Value Invoke-ForwardPortsScript

