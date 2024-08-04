# ForwardPorts.ps1
# This script sets up port forwarding from bridged Docker containers and WSL to your local network and adds necessary Windows Firewall rules.

# ========================
# Configuration Section
# ========================

# Define your network interface alias (default is 'Ethernet')
$InterfaceAlias = 'Ethernet'

# Define the ports and container names for Docker services
$DockerServices = @{
    'Monero-Node' = @(18080, 18081)
    'Pi-hole'     = @((@{ Port = 53; Protocol = 'TCP' }, @{ Port = 53; Protocol = 'UDP' }, @{ Port = 31415; Protocol = 'TCP' }))
}

# Define the ports for WSL services (e.g., nginx on port 443)
$WSLPorts = @(80, 443)

# ========================
# Function Definitions
# ========================

# Function to get the host IP address
function Get-HostIP {
    param (
        [string]$InterfaceAlias = 'Ethernet'
    )
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $InterfaceAlias).IPAddress
        Write-Host "Host IP address for interface '$InterfaceAlias': $ip"
        return $ip
    }
    catch {
        Write-Error "Failed to get host IP address: $_"
        throw
    }
}

# Function to get the Docker container IP address
function Get-DockerIP {
    param (
        [string]$ContainerName
    )
    try {
        $ip = $(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $ContainerName)
        if (-not $ip) {
            throw "No IP address found for container '$ContainerName'"
        }
        Write-Host "Docker container '$ContainerName' IP address: $ip"
        return $ip
    }
    catch {
        Write-Error "Failed to get Docker container IP address for '$ContainerName': $_"
        throw
    }
}

# Function to get the WSL IP address
function Get-WSLIP {
    try {
        $ips = wsl hostname -I
        $ip = $ips.Split(" ")[0] # Take the first IP address
        Write-Host "WSL IP address: $ip"
        return $ip
    }
    catch {
        Write-Error "Failed to get WSL IP address: $_"
        throw
    }
}

# Function to add port proxy rules
function Add-PortProxy {
    param (
        [string]$HostIP,
        [string]$TargetIP,
        [array]$Ports
    )
    foreach ($port in $Ports) {
        try {
            if ($port -is [int]) {
                # Default to TCP if protocol is not specified
                netsh interface portproxy add v4tov4 listenport=$port listenaddress=$HostIP connectport=$port connectaddress=$TargetIP protocol=tcp
                Write-Host "Added port proxy rule: ${HostIP}:${port} -> ${TargetIP}:${port} (TCP)"
            }
            else {
                $protocol = $port.Protocol.ToLower()
                netsh interface portproxy add v4tov4 listenport=$($port.Port) listenaddress=$HostIP connectport=$($port.Port) connectaddress=$TargetIP protocol=$protocol
                Write-Host "Added port proxy rule: ${HostIP}:${($port.Port)} -> ${TargetIP}:${($port.Port)} (${protocol.ToUpper()})"
            }
        }
        catch {
            Write-Error "Failed to add port proxy rule for port ${($port.Port)} (${protocol.ToUpper()}): $_"
            throw
        }
    }
}

# Function to add firewall rules
function Add-FirewallRule {
    param (
        [array]$Ports,
        [string]$Direction = 'Inbound'
    )
    foreach ($port in $Ports) {
        try {
            if ($port -is [int]) {
                # Default to TCP if protocol is not specified
                New-NetFirewallRule -DisplayName "Port ${port} TCP Allow Rule" -Direction $Direction -Action Allow -Protocol TCP -LocalPort $port
                Write-Host "Added firewall rule for port ${port} (TCP)"
            }
            else {
                $protocol = $port.Protocol.ToUpper()
                New-NetFirewallRule -DisplayName "Port ${($port.Port)} ${protocol} Allow Rule" -Direction $Direction -Action Allow -Protocol $protocol -LocalPort $($port.Port)
                Write-Host "Added firewall rule for port ${($port.Port)} (${protocol})"
            }
        }
        catch {
            Write-Error "Failed to add firewall rule for port ${($port.Port)} (${protocol}): $_"
            throw
        }
    }
}

# ========================
# Main Script Execution
# ========================

try {
    # Get the host IP address (It's better if this is static)
    $hostIP = '192.168.1.99'

    # Forward ports for Docker services
    foreach ($service in $DockerServices.Keys) {
        $dockerIP = Get-DockerIP -ContainerName $service
        if (-not $dockerIP) {
            Write-Error "Failed to get IP address for Docker container '$service'. Skipping..."
            continue
        }
        $ports = $DockerServices[$service]
        Add-PortProxy -HostIP $hostIP -TargetIP $dockerIP -Ports $ports
        Add-FirewallRule -Ports $ports -Direction 'Inbound'
    }

    # Forward ports for WSL services
    $wslIP = Get-WSLIP
    if ($wslIP) {
        Add-PortProxy -HostIP $hostIP -TargetIP $wslIP -Ports $WSLPorts
        Add-FirewallRule -Ports $WSLPorts -Direction 'Inbound'
    }
    else {
        Write-Error "Failed to retrieve WSL IP address. Skipping WSL port forwarding."
    }

    # Display all port proxy rules
    netsh interface portproxy show all | Write-Host

}
catch {
    Write-Error "An error occurred during script execution: $_"
    throw
}
