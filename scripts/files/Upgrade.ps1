# =============================================================================
# System Upgrade Script
# =============================================================================

# =============================================================================
# Configuration
# =============================================================================

# Define the minimum required free space in GB
$MinimumFreeSpaceGB = 10

# =============================================================================
# Functions
# =============================================================================

function Test-Admin {
    <#
    .SYNOPSIS
    Check if the script is running with administrative privileges.

    .DESCRIPTION
    This function checks whether the current user has administrative rights.
    If not, it exits the script with an error message.

    .EXAMPLE
    Test-Admin
    #>
    $currentUser = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    if (-not $currentUser.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "This script must be run as an administrator. Exiting..." -ForegroundColor Red
        exit 1
    }
}

function Test-DiskSpace {
    <#
    .SYNOPSIS
    Ensure there is sufficient free disk space on the C: drive.

    .DESCRIPTION
    Checks the free space on the C: drive and exits if it is below the minimum required.

    .EXAMPLE
    Test-DiskSpace
    #>
    $drive = Get-PSDrive -Name C
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
    Write-Host "Free disk space on C:: $freeSpaceGB GB"

    if ($freeSpaceGB -lt $MinimumFreeSpaceGB) {
        Write-Host "Insufficient disk space. At least $MinimumFreeSpaceGB GB required. Exiting..." -ForegroundColor Red
        exit 1
    }
}

function Start-RequiredServices {
    <#
    .SYNOPSIS
    Ensure that essential services are running.

    .DESCRIPTION
    Checks and starts essential Windows services required for updates.

    .EXAMPLE
    Start-RequiredServices
    #>
    $services = @("wuauserv", "bits", "cryptsvc", "msiserver")
    foreach ($service in $services) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            Write-Host "Starting service: $service"
            Start-Service -Name $service
        }
    }
}

function Update-SystemTime {
    <#
    .SYNOPSIS
    Synchronize system time.

    .DESCRIPTION
    Starts the Windows Time service and forces a time synchronization.

    .EXAMPLE
    Update-SystemTime
    #>
    Write-Host "Starting time synchronization..."
    net start w32time | Out-Null
    W32tm /resync /force | Out-Null
    Write-Host "Time synchronization completed."
}

function Optimize-SSD {
    <#
    .SYNOPSIS
    Perform TRIM operation on SSD.

    .DESCRIPTION
    Uses Optimize-Volume cmdlet to perform a TRIM operation on the C: drive.

    .EXAMPLE
    Optimize-SSD
    #>
    Write-Host "Starting SSD TRIM operation..."
    Optimize-Volume -DriveLetter C -ReTrim -Verbose
    Write-Host "SSD TRIM completed."
}

function Invoke-Diagnostics {
    <#
    .SYNOPSIS
    Schedule Windows Memory Diagnostic and Disk Check.

    .DESCRIPTION
    Schedules a memory diagnostic and a disk check to run on the next reboot.

    .EXAMPLE
    Invoke-Diagnostics
    #>
    Write-Host "Scheduling Windows Memory Diagnostic..."
    mdsched.exe /schedule | Out-Null
    Write-Host "Windows Memory Diagnostic scheduled."

    Write-Host "Scheduling disk check for C: drive..."
    cmd.exe /c "echo y | chkdsk /x /f c:" | Out-Null
    Write-Host "Disk check for C: drive scheduled."
}

function Update-ChocolateyPackages {
    <#
    .SYNOPSIS
    Upgrade Chocolatey itself and all installed packages.

    .DESCRIPTION
    Uses Chocolatey to upgrade itself and all installed packages, and keeps track of upgraded packages.

    .EXAMPLE
    Update-ChocolateyPackages
    #>
    Write-Host "Starting Chocolatey package updates..."

    # Upgrade Chocolatey itself
    choco upgrade chocolatey -y
    Write-Host "Chocolatey itself updated."

    # Get list of outdated packages before upgrade
    Write-Host "Getting list of outdated packages before upgrade..."
    $OutdatedPackagesBeforeOutput = choco outdated

    if ($OutdatedPackagesBeforeOutput -match 'No packages found') {
        Write-Host "No outdated Chocolatey packages found before upgrade."
        $OutdatedPackagesBefore = @()
    }
    else {
        $OutdatedPackagesBefore = $OutdatedPackagesBeforeOutput |
        Select-Object -Skip 1 |
        ForEach-Object { $_ -replace '\s+', ' ' } |
        ForEach-Object { $_.Split(' ')[0] }
    }

    # Upgrade all packages
    choco upgrade all -y

    # Get list of outdated packages after upgrade
    Write-Host "Getting list of outdated packages after upgrade..."
    $OutdatedPackagesAfterOutput = choco outdated

    if ($OutdatedPackagesAfterOutput -match 'No packages found') {
        $OutdatedPackagesAfter = @()
    }
    else {
        $OutdatedPackagesAfter = $OutdatedPackagesAfterOutput |
        Select-Object -Skip 1 |
        ForEach-Object { $_ -replace '\s+', ' ' } |
        ForEach-Object { $_.Split(' ')[0] }
    }

    # Determine which packages were upgraded
    $Global:UpgradedChocoPackages = $OutdatedPackagesBefore | Where-Object { $_ -notin $OutdatedPackagesAfter }

    if ($Global:UpgradedChocoPackages.Count -gt 0) {
        Write-Host "The following packages were upgraded via Chocolatey:"
        $Global:UpgradedChocoPackages | ForEach-Object { Write-Host "- $_" }
    }
    else {
        Write-Host "No Chocolatey packages were upgraded."
    }
}

function Clear-TemporaryFiles {
    <#
    .SYNOPSIS
    Remove temporary files to free up disk space.

    .DESCRIPTION
    Clears the contents of the TEMP directory to free up disk space.

    .EXAMPLE
    Clear-TemporaryFiles
    #>
    Write-Host "Cleaning up temporary files..."
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Temporary files cleaned up."
}

function Install-WindowsUpdates {
    <#
    .SYNOPSIS
    Install Windows and Driver updates.

    .DESCRIPTION
    Uses PSWindowsUpdate module to install all Windows and driver updates.

    .EXAMPLE
    Install-WindowsUpdates
    #>
    try {
        # Define the registry path
        $windowsUpdateRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

        # Check if the registry path exists
        if (Test-Path $windowsUpdateRegPath) {
            # Prevent automatic reboot
            Set-ItemProperty -Path $windowsUpdateRegPath -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1
            Write-Host "Set 'NoAutoRebootWithLoggedOnUsers' policy to 1."
        }
        else {
            Write-Host "Registry path $windowsUpdateRegPath not found. Skipping NoAutoReboot policy update." -ForegroundColor Yellow
        }

        # Install Windows Updates and capture installed updates
        $Global:WindowsUpdatesInstalled = Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -IgnoreReboot -Verbose
        Write-Host "Windows Updates installed successfully."

        # Install Driver Updates and capture installed driver updates
        $Global:DriverUpdatesInstalled = Install-WindowsUpdate -Category Drivers -AcceptAll -Install -IgnoreReboot -Verbose
        Write-Host "Driver updates installed successfully."
    }
    catch {
        Write-Error "An error occurred during Windows Updates: $_"
    }
    finally {
        # Revert the 'NoAutoRebootWithLoggedOnUsers' policy if the path exists
        if (Test-Path $windowsUpdateRegPath) {
            Set-ItemProperty -Path $windowsUpdateRegPath -Name 'NoAutoRebootWithLoggedOnUsers' -Value 0
            Write-Host "Reverted 'NoAutoRebootWithLoggedOnUsers' policy to 0."
        }
    }
}

# =============================================================================
# Start of Script
# =============================================================================

# Ensure verbose output
$VerbosePreference = 'Continue'

# Stop execution if any error occurs
$ErrorActionPreference = 'Stop'

# Check for administrative privileges
Test-Admin

# Check available disk space
Test-DiskSpace

# Ensure essential services are running
Start-RequiredServices

# Synchronize system time
Update-SystemTime

# Update Chocolatey packages
Update-ChocolateyPackages

# Clean up temporary files
Clear-TemporaryFiles

# Optimize SSD
Optimize-SSD

# Schedule diagnostics
Invoke-Diagnostics

# Install Windows and Driver updates
Install-WindowsUpdates

# =============================================================================
# Report of Upgraded Packages
# =============================================================================

Write-Host "`n==========================================="
Write-Host "Upgrade Report"
Write-Host "==========================================="

# Windows Updates
if ($Global:WindowsUpdatesInstalled -and $Global:WindowsUpdatesInstalled.Count -gt 0) {
    Write-Host "`nThe following Windows updates were installed:"
    foreach ($update in $Global:WindowsUpdatesInstalled) {
        Write-Host "- $($update.Title)"
    }
}
else {
    Write-Host "`nNo Windows updates were installed."
}

# Driver Updates
if ($Global:DriverUpdatesInstalled -and $Global:DriverUpdatesInstalled.Count -gt 0) {
    Write-Host "`nThe following driver updates were installed:"
    foreach ($update in $Global:DriverUpdatesInstalled) {
        Write-Host "- $($update.Title)"
    }
}
else {
    Write-Host "`nNo driver updates were installed."
}

# Chocolatey Packages
if ($Global:UpgradedChocoPackages -and $Global:UpgradedChocoPackages.Count -gt 0) {
    Write-Host "`nThe following Chocolatey packages were upgraded:"
    foreach ($package in $Global:UpgradedChocoPackages) {
        Write-Host "- $package"
    }
}
else {
    Write-Host "`nNo Chocolatey packages were upgraded."
}

# Spicetify Notification
if ($Global:UpgradedChocoPackages -and ($Global:UpgradedChocoPackages -contains 'spicetify-cli')) {
    Write-Host "`nNote: 'spicetify' was upgraded via Chocolatey. You need to re-apply your spicetify customizations manually." -ForegroundColor Yellow
}

# =============================================================================
# End of Script
# =============================================================================
