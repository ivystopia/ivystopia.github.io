# ===========================================
#       Pre-reboot Windows Update Script
# ===========================================

# Function Definitions for Consistent Output
function Write-Info {
    param ([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Success {
    param ([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-WarningMsg {
    param ([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param ([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

# Consistent Separator for Clear Section Divisions
function Write-Separator {
    Write-Host "=============================================" -ForegroundColor DarkGray
}

# ===========================================
#       Check for Administrative Privileges
# ===========================================
$currentUser = [Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-ErrorMsg "This script must be run as an administrator. Exiting..."
    exit 1
}

# ===========================================
#           Pending Reboot Check
# ===========================================
$rebootKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
if (Test-Path $rebootKey) {
    Write-WarningMsg "A pending reboot is detected. Press Enter to continue or Ctrl-C to abort."
    [void][System.Console]::ReadLine()
}

# ===========================================
#                   Preferences
# ===========================================
$VerbosePreference = 'SilentlyContinue'  # Suppress global verbose messages
$ErrorActionPreference = 'Stop'

# ===========================================
#           Start Script Execution
# ===========================================
Write-Separator
Write-Info "Starting upgrade script."
Write-Separator

# ===========================================
#       Ensure Essential Services Are Running
# ===========================================
Write-Info "Ensuring essential services are running..."
$services = @("wuauserv", "bits", "cryptsvc", "msiserver", "w32time")
foreach ($service in $services) {
    try {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -eq 'Stopped') {
                Write-Info "Starting service: $service"
                Start-Service -Name $service
                Write-Success "Service '$service' started."
            }
            else {
                Write-Info "Service '$service' is already running or in progress."
            }
        }
        else {
            Write-WarningMsg "Service '$service' not found."
        }
    }
    catch {
        Write-WarningMsg "Failed to start service '$service'."
    }
}
Write-Separator

# ===========================================
#             Synchronize System Time
# ===========================================
Write-Info "Synchronizing system time..."
try {
    w32tm /resync /force | Out-Null
    Write-Success "Time synchronization completed."
}
catch {
    Write-WarningMsg "Failed to synchronize system time."
}
Write-Separator

# ===========================================
#        Install Windows Updates
# ===========================================
Write-Info "Installing Windows Updates..."
try {
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        if (-not (Get-InstalledModule -Name PSWindowsUpdate -ErrorAction SilentlyContinue)) {
            Write-Info "Installing PSWindowsUpdate module..."
            Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -AllowClobber -ErrorAction Stop
            Write-Success "PSWindowsUpdate module installed successfully."
        }
        else {
            Write-Info "PSWindowsUpdate module is already installed but not loaded."
        }
    }

    # Import the module
    Import-Module -Name PSWindowsUpdate -ErrorAction Stop

    # Install updates
    $WindowsUpdatesInstalled = PSWindowsUpdate\Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -Verbose:$false -ErrorAction Stop

    if ($WindowsUpdatesInstalled.Count -gt 0) {
        Write-Success "Windows Updates installed successfully."
    }
    else {
        Write-WarningMsg "No Windows updates were installed."
    }
}
catch {
    Write-WarningMsg "Failed to install Windows Updates."
    Write-WarningMsg "Error Details: $($_.Exception.Message)"
    Write-WarningMsg "Error StackTrace: $($_.Exception.StackTrace)"
    Write-WarningMsg "Inner Exception: $($_.Exception.InnerException)"
}
Write-Separator

# ===========================================
#          Upgrade Chocolatey Packages
# ===========================================
Write-Info "Upgrading Chocolatey packages..."
try {
    # Upgrade the Chocolatey package manager first
    Write-Info "Upgrading Chocolatey..."
    choco upgrade chocolatey -y --use-system-powershell
    Write-Success "Chocolatey updated successfully."

    # Upgrade all other packages
    Write-Info "Upgrading all packages..."
    choco upgrade all -y --use-system-powershell
    choco cache clean
    Write-Success "Finished upgrading packages."
}
catch {
    Write-WarningMsg "Failed to perform some Chocolatey operations."
    Write-WarningMsg "Error Details: $($_.Exception.Message)"
}
Write-Separator

# ===========================================
#                 End of Script
# ===========================================
Write-Success "Script execution finished."
Write-Separator
