param(
    [switch]$Force  # Optional: if set, recreate existing shortcuts even if they exist
)

# === CONFIGURATION ===
# Define critical Chocolatey paths used throughout the script.
$chocoBin = "C:\ProgramData\chocolatey\bin"
$libRoot = "C:\ProgramData\chocolatey\lib"
$commonStartMenu = Join-Path -Path $env:ProgramData -ChildPath "Microsoft\Windows\Start Menu\Programs"
$userStartMenu = Join-Path -Path $env:AppData     -ChildPath "Microsoft\Windows\Start Menu\Programs"

# Include both system-wide and user-specific start menu roots
$startRoots = @($commonStartMenu, $userStartMenu)

# All generated shortcuts go in this managed folder
$shortcutFolder = Join-Path -Path $commonStartMenu -ChildPath "Chocolatey Shortcuts"

# Ensure the shortcut folder exists
if (-not (Test-Path $shortcutFolder)) {
    New-Item -ItemType Directory -Path $shortcutFolder | Out-Null
}

# === UTILITY FUNCTION ===
# Determines whether a path is one of Chocolatey's auto-generated shim .exe files.
function Test-IsShim {
    param([string]$Path)
    return ($Path -like "$chocoBin\*")
}

# === STEP 1: CLEAN UP BROKEN SHORTCUTS ===
# Remove any shortcut from our managed folder whose target no longer exists.
Get-ChildItem -Path $shortcutFolder -Filter '*.lnk' -File | ForEach-Object {
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($_.FullName)

    # If the file the shortcut points to is missing, delete the shortcut
    if (-not (Test-Path $sc.TargetPath)) {
        Remove-Item $_.FullName -Force
    }
}

# === STEP 2: REMOVE DUPLICATE SHORTCUTS TO NON-SHIMS ===
# Purpose: If there are multiple shortcuts to executables with the same name,
# we prefer the one that is a Chocolatey shim (in chocoBin), and we delete the rest.

# Build a table of all .lnk files from all Start Menu roots, grouped by target executable filename
$linkTable = @{}
foreach ($root in $startRoots) {
    Get-ChildItem -Path $root -Filter '*.lnk' -Recurse -File | ForEach-Object {
        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($_.FullName)
        if ($sc.TargetPath) {
            $name = Split-Path $sc.TargetPath -Leaf
            if (-not $linkTable.ContainsKey($name)) { $linkTable[$name] = @() }
            $linkTable[$name] += @{ Link = $_.FullName; Target = $sc.TargetPath }
        }
    }
}

# If a target name appears multiple times, keep only the shim shortcut (if any), and remove others
foreach ($name in $linkTable.Keys) {
    $entries = $linkTable[$name]
    if ($entries.Count -le 1) { continue }

    $shimExe = Join-Path -Path $chocoBin -ChildPath $name
    foreach ($entry in $entries) {
        if ($entry.Target -ne $shimExe) {
            Remove-Item $entry.Link -Force
        }
    }
}

# === STEP 3: CREATE SHORTCUTS FOR CHOCOLATEY PACKAGES ===
# For each installed Chocolatey package, create a shortcut to the main executable.
# Prioritize shims (preferred), otherwise fallback to first .exe found in tools folder.

Get-ChildItem -Path $libRoot -Directory | ForEach-Object {
    $pkgId = $_.Name
    $shimPath = Join-Path -Path $chocoBin -ChildPath "$pkgId.exe"

    # Prefer Chocolatey's generated shim executable
    if (Test-Path $shimPath) {
        $exe = $shimPath
    }
    else {
        # If no shim exists, try to find a real .exe in the 'tools' subfolder
        $toolsDir = Join-Path -Path $_.FullName -ChildPath "tools"
        if (Test-Path $toolsDir) {
            $exe = Get-ChildItem -Path $toolsDir -Recurse -Filter '*.exe' -File |
            Where-Object { -not (Test-IsShim $_.FullName) } |
            Select-Object -First 1 -ExpandProperty FullName
        }
    }

    # If nothing executable found, skip this package
    if (-not $exe) { return }

    $lnkPath = Join-Path -Path $shortcutFolder -ChildPath "$pkgId.lnk"

    # Skip creating the shortcut unless forced or doesn't exist
    if (-not $Force -and (Test-Path $lnkPath)) { return }

    # Create or overwrite the shortcut
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnkPath)
    $sc.TargetPath = $exe
    $sc.WorkingDirectory = Split-Path $exe
    $sc.IconLocation = $exe
    $sc.Save()
}
