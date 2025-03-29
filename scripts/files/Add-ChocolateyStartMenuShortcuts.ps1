param(
    [switch]$Force
)

# Define the folder where shortcuts will be created.
$startMenuFolder = "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Chocolatey Shortcuts"
if (-not (Test-Path $startMenuFolder)) {
    New-Item -ItemType Directory -Path $startMenuFolder | Out-Null
    Write-Verbose "Created Start Menu folder: $startMenuFolder"
}

# ***********************
# Step 1: Clean up invalid shortcuts.
# ***********************
Get-ChildItem -Path $startMenuFolder -Filter *.lnk -File | ForEach-Object {
    $shortcutPath = $_.FullName
    try {
        $wshell = New-Object -ComObject WScript.Shell
        $shortcut = $wshell.CreateShortcut($shortcutPath)
        if (-not (Test-Path $shortcut.TargetPath)) {
            Write-Host "Removing invalid shortcut: $shortcutPath (target not found)"
            Remove-Item $shortcutPath -Force
        }
    }
    catch {
        Write-Host "Error reading shortcut: $shortcutPath"
    }
}

# Define Chocolatey's bin folder where shims are installed.
$chocoBin = "C:\ProgramData\chocolatey\bin"

# ***********************
# Step 2: Process each installed package.
# ***********************
Get-ChildItem -Path "C:\ProgramData\chocolatey\lib" -Directory | ForEach-Object {
    $pkgId = $_.Name
    $exePath = $null

    # Prefer a shim from Chocolatey's bin folder.
    $shimExe = Join-Path $chocoBin ("$pkgId.exe")
    if (Test-Path $shimExe) {
        $exePath = $shimExe
    }
    else {
        # If no shim exists, search for an executable in the package's tools folder recursively.
        $toolsDir = Join-Path $_.FullName "tools"
        if (Test-Path $toolsDir) {
            $exeCandidate = Get-ChildItem -Path $toolsDir -Recurse -Filter *.exe -File | Select-Object -First 1
            if ($exeCandidate) {
                $exePath = $exeCandidate.FullName
            }
        }
    }

    if ($exePath) {
        $shortcutPath = Join-Path $startMenuFolder ("$pkgId.lnk")
        # Create shortcut if it doesn't exist or if forced.
        if ($Force -or -not (Test-Path $shortcutPath)) {
            try {
                $wshell = New-Object -ComObject WScript.Shell
                $shortcut = $wshell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $exePath
                # Set working directory to the folder of the exe.
                $shortcut.WorkingDirectory = Split-Path $exePath
                $shortcut.IconLocation = $exePath
                $shortcut.Save()
                Write-Host "Created shortcut for $pkgId using target: $exePath"
            }
            catch {
                Write-Error "Failed to create shortcut for $pkgId. Error: $_"
            }
        }
    }
    else {
        Write-Verbose "No executable found for package $pkgId."
    }
}

Write-Host "DONE $($MyInvocation.MyCommand.Name)"