################################################################################
# Helpers: WSL path conversion and script execution
################################################################################

# Directory (inside your WSL filesystem) that holds PowerShell scripts you want to run from Windows.
# $script: scope keeps this variable private to this profile script (and visible to functions defined here).
$script:WSLScriptDir = "/home/anon/repos/personal/ivystopia.github.io/scripts/files"

function Convert-WSLPathToWindows {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WSLPath
    )

    # Convert a WSL/Linux path to a Windows path using wslpath.
    # - wsl.exe launches a command in the default WSL distro.
    # - We trim output to avoid newline/whitespace surprises.
    return (wsl.exe -e sh -c "wslpath -w '$WSLPath'" | ForEach-Object { $_.Trim() })
}

function Invoke-WSLScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WSLPath,

        # Arguments are passed as a single string appended to a PowerShell -Command call.
        # This is simple but means you should pre-escape any quotes/backticks inside $Arguments.
        [string]$Arguments = ""
    )

    $windowsPath = Convert-WSLPathToWindows -WSLPath $WSLPath
    if (-not $windowsPath) {
        Write-Error "Failed to convert WSL path to Windows path."
        return
    }

    if (-not (Test-Path -LiteralPath $windowsPath)) {
        Write-Error "Script not found: $windowsPath"
        return
    }

    # Remove the "downloaded from the internet" mark so PowerShell won't prompt/deny execution.
    Unblock-File -Path $windowsPath

    # Run the script in Windows PowerShell (powershell.exe) in a fresh process:
    # -NoProfile: avoids re-loading this profile in the child process
    # -ExecutionPolicy Bypass: allows running the script without policy friction
    #
    # We explicitly dot-source this profile in the child process so any aliases/functions it needs exist.
    # NOTE: This means the child process will execute this entire profile too.
    $cmd = ". '$PROFILE'; & '$windowsPath' $Arguments"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $cmd
}

################################################################################
# WSL script launchers (thin wrappers around Invoke-WSLScript)
################################################################################

function Invoke-UpgradeScript {
    Write-Output "Running the upgrade script..."
    Invoke-WSLScript -WSLPath "$script:WSLScriptDir/Upgrade.ps1"
}

Set-Alias -Name upgrade -Value Invoke-UpgradeScript

function Add-ChocoShortcuts {
    Write-Output "Running Add-ChocolateyStartMenuShortcuts.ps1..."
    Invoke-WSLScript -WSLPath "$script:WSLScriptDir/Add-ChocolateyStartMenuShortcuts.ps1"
}

Set-Alias -Name choco-shortcuts -Value Add-ChocoShortcuts

function Invoke-DeviceInfo {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Query
    )

    # $Arguments is injected into a -Command string, so we escape characters that would break parsing.
    # - Backtick is PowerShell's escape character.
    # - Double quotes delimit strings in our -Arguments payload.
    $q = $Query -replace '`', '``' -replace '"', '`"'
    Invoke-WSLScript -WSLPath "$script:WSLScriptDir/DeviceInfo.ps1" -Arguments "-Query `"$q`""
}

Set-Alias -Name deviceinfo -Value Invoke-DeviceInfo

################################################################################
# Bitwarden helpers
################################################################################

function Unlock-Bitwarden {
    # Sync first to ensure the local vault is up to date.
    bw sync
    Write-Output ""

    # bw unlock --raw returns the session key as plain text.
    # Storing it in $env:BW_SESSION enables authenticated "bw" commands for this shell session.
    $sessionKey = bw unlock --raw
    if ($sessionKey) {
        $env:BW_SESSION = $sessionKey
        Write-Output "Vault is now unlocked for this shell session."
        Write-Output "To lock the vault and clear the session, run: bw-lock"
    }
    else {
        Write-Output "Failed to unlock Bitwarden vault."
    }
}

Set-Alias -Name bw-unlock -Value Unlock-Bitwarden

function Lock-Bitwarden {
    # Lock the vault and remove the session key from the environment.
    bw lock
    Remove-Item Env:BW_SESSION
}

Set-Alias -Name bw-lock -Value Lock-Bitwarden

################################################################################
# Chocolatey profile (tab completion for choco)
################################################################################

# Chocolatey ships a helper module that registers argument completers for `choco`.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
    Import-Module $ChocolateyProfile
}

################################################################################
# Chocolatey helpers: resolve portable package executables (version-proof)
################################################################################

# Cache resolved exe paths so repeated calls don't re-scan the filesystem.
$script:ChocoExeCache = @{}

function Resolve-ChocoPortableExe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter(Mandatory = $true)]
        [string]$ExeName
    )

    # ChocolateyInstall is usually like: C:\ProgramData\chocolatey
    if (-not $env:ChocolateyInstall) { return $null }

    $key = "$PackageName|$ExeName"

    # Cache hit: only return if the file still exists (portable packages can be upgraded/removed).
    if ($script:ChocoExeCache.ContainsKey($key)) {
        $cached = $script:ChocoExeCache[$key]
        if ($cached -and (Test-Path -LiteralPath $cached)) { return $cached }
        $null = $script:ChocoExeCache.Remove($key)
    }

    # For portable packages, Chocolatey commonly unpacks binaries under:
    #   $env:ChocolateyInstall\lib\<package>\tools\...
    $toolsDir = Join-Path $env:ChocolateyInstall "lib\$PackageName\tools"
    if (-not (Test-Path -LiteralPath $toolsDir)) { return $null }

    # Find candidate executables anywhere under tools/.
    $candidates = Get-ChildItem -LiteralPath $toolsDir -Recurse -File -Filter $ExeName -ErrorAction SilentlyContinue
    if (-not $candidates) { return $null }

    # Heuristic choice:
    #  1) Prefer x64/amd64 builds when identifiable in the path
    #  2) Prefer paths containing a higher-looking version number
    #  3) Fall back to newest LastWriteTimeUtc
    $best = $candidates |
    Sort-Object `
    @{ Expression = { $_.FullName -match '(\\|/)(x64|amd64)(\\|/)' -or $_.FullName -match 'windows-amd64' }; Descending = $true }, `
    @{ Expression = { if ($_.FullName -match 'v?(\d+\.\d+\.\d+(?:\.\d+)*)') { [version]$Matches[1] } else { [version]'0.0.0' } }; Descending = $true }, `
    @{ Expression = { $_.LastWriteTimeUtc }; Descending = $true } |
    Select-Object -First 1

    if ($best) {
        $script:ChocoExeCache[$key] = $best.FullName
        return $best.FullName
    }

    return $null
}

function Invoke-Rclone {
    # Wrap rclone so you can keep using `rclone` even if the portable folder name changes.
    $exe = Resolve-ChocoPortableExe -PackageName 'rclone.portable' -ExeName 'rclone.exe'
    if (-not $exe) {
        Write-Error "rclone.exe not found under Chocolatey lib\rclone.portable\tools. Reinstall with: choco install rclone.portable -y"
        return
    }

    # Forward all arguments exactly as received.
    & $exe @args
}

Set-Alias -Name rclone -Value Invoke-Rclone

################################################################################
# Zsh-style completion and history using PSReadLine
################################################################################

# PSReadLine is PowerShell's interactive line editor:
# - It handles keybindings (Ctrl+L, Up/Down, Tab, etc.)
# - It provides history search and inline predictions (grey text suggestions)
Import-Module PSReadLine

# Inline prediction ("grey autosuggestion") sourced from history.
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView

# Make history searching case-insensitive for a closer Zsh feel.
Set-PSReadLineOption -HistorySearchCaseSensitive:$false

# Ctrl+D: Exit the shell (like Bash/Zsh). ViExit is the standard "leave the editor" function.
Set-PSReadLineKeyHandler -Key Ctrl+d -Function ViExit

# Ctrl+L: Clear the screen (like Bash/Zsh).
Set-PSReadLineKeyHandler -Key Ctrl+l -Function ClearScreen

# Backward kill word:
# - Ctrl+H often arrives when terminals send ^H for Backspace in some configurations
# - Alt+Backspace is the common Windows chord for deleting a word backward
Set-PSReadLineKeyHandler -Chord Ctrl+h -Function BackwardKillWord
Set-PSReadLineKeyHandler -Chord Alt+Backspace -Function BackwardKillWord

# Up/Down: Zsh-style "history-beginning-search" using the prefix from start-of-line to cursor.
# - If the prefix is empty, fall back to normal history navigation.
# - If you moved the cursor left, text to the right of the cursor is ignored (matches your spec).
Set-PSReadLineKeyHandler -Chord UpArrow -ScriptBlock {
    param($key, $arg)

    $line = ''
    $cursor = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $prefix = if ($cursor -gt 0) { $line.Substring(0, $cursor) } else { '' }

    if ([string]::IsNullOrEmpty($prefix)) {
        [Microsoft.PowerShell.PSConsoleReadLine]::PreviousHistory($key, $arg)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchBackward($key, $arg)
    }
}

Set-PSReadLineKeyHandler -Chord DownArrow -ScriptBlock {
    param($key, $arg)

    $line = ''
    $cursor = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $prefix = if ($cursor -gt 0) { $line.Substring(0, $cursor) } else { '' }

    if ([string]::IsNullOrEmpty($prefix)) {
        [Microsoft.PowerShell.PSConsoleReadLine]::NextHistory($key, $arg)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::HistorySearchForward($key, $arg)
    }
}

# Tab behavior:
# 1) If there is a visible inline suggestion, accept it (like Zsh autosuggest accept).
# 2) Otherwise perform normal completion.
#
# Implementation detail:
# PSReadLine doesn't expose a "suggestion present?" boolean in a simple public API,
# so we snapshot buffer state, attempt AcceptSuggestion, then compare buffer state.
Set-PSReadLineKeyHandler -Chord Tab -ScriptBlock {
    param($key, $arg)

    $lineBefore = ''
    $cursorBefore = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$lineBefore, [ref]$cursorBefore)

    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptSuggestion($key, $arg)

    $lineAfter = ''
    $cursorAfter = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$lineAfter, [ref]$cursorAfter)

    if (($lineAfter -eq $lineBefore) -and ($cursorAfter -eq $cursorBefore)) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Complete($key, $arg)
    }
}

# Alternate completion chord that always runs completion even if a suggestion exists:
# - MenuComplete cycles through possible completions interactively.
Set-PSReadLineKeyHandler -Chord Shift+Tab -Function MenuComplete

# Optional: some terminals map Ctrl+Spacebar reliably; if yours does, this is a second completion chord.
Set-PSReadLineKeyHandler -Chord Ctrl+Spacebar -Function MenuComplete

################################################################################
# Clipboard helper: xclip equivalent (file path or pipeline input)
################################################################################

function xclip {
    param(
        [string]$LiteralPath
    )

    # Usage:
    #   xclip -LiteralPath .\file.txt
    # or:
    #   Get-Content .\file.txt | xclip
    if ($PSBoundParameters.ContainsKey('LiteralPath')) {
        Get-Content -LiteralPath $LiteralPath -Raw | Set-Clipboard
    }
    else {
        ($input | Out-String).TrimEnd("`r", "`n") | Set-Clipboard
    }
}
