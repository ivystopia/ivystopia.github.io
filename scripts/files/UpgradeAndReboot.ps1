# Workaround for passing "R" via $PROFILE alias
$null = Read-Host " "

# Ensure we see all output
$VerbosePreference = 'Continue'

# Stop execution if any error occurs
$ErrorActionPreference = 'Stop'

# Check if script is running with elevated privileges
$currentUser = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $currentUser.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "This script must be run as an administrator. Exiting..."
    exit
}

# Install Windows Updates
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -IgnoreReboot -Verbose
Install-WindowsUpdate -Category Drivers -AcceptAll -Install -IgnoreReboot -Verbose

# TRIM SSD
Optimize-Volume -DriveLetter C -ReTrim -Verbose

# Schedule Windows Memory Diagnostic
mdsched.exe /schedule

# Schedule a disk check for the C drive
cmd.exe /c "echo y | chkdsk /x /f c:"

# Upgrade Chocolatey packages
choco upgrade chocolatey -y
choco upgrade all -y
