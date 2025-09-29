# DeviceInfo.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Query
)

# Find by exact InstanceId (case-insensitive) OR partial FriendlyName (case-insensitive)
$devices = Get-PnpDevice -PresentOnly | Where-Object {
    ($_.InstanceId -ieq $Query) -or
    ($_.FriendlyName -and $_.FriendlyName -imatch [regex]::Escape($Query))
}

if (-not $devices) {
    Write-Output "No devices matched. Refine the name or paste the exact InstanceId."
    exit
}

if ($devices.Count -gt 1) {
    Write-Output "Multiple devices matched. Be more precise:"
    $devices | Select-Object FriendlyName, InstanceId | Sort-Object FriendlyName | Format-Table -AutoSize
    exit
}

$id = $devices.InstanceId
$wmiId = $id.Replace('\', '\\').Replace("'", "''")  # escape for WMI -Filter

$report = [pscustomobject]@{
    Timestamp  = (Get-Date).ToString('s')
    Query      = $Query
    InstanceId = $id
    Device     = Get-PnpDevice -InstanceId $id | Select-Object *
    Properties = Get-PnpDeviceProperty -InstanceId $id -ErrorAction SilentlyContinue |
    Sort-Object KeyName |
    ForEach-Object {
        [pscustomobject]@{
            KeyName = $_.KeyName
            Type    = $_.Type.ToString()
            Data    = $_.Data
        }
    }
    Driver     = Get-CimInstance Win32_PnPSignedDriver -Filter "DeviceID='$wmiId'" -ErrorAction SilentlyContinue | Select-Object *
    Wmi        = Get-CimInstance Win32_PnPEntity        -Filter "PNPDeviceID='$wmiId'" -ErrorAction SilentlyContinue | Select-Object *
}

$report | ConvertTo-Json -Depth 64
