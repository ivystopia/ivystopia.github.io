# ForwardPorts.ps1
# This script dynamically forwards Docker container ports using the IP associated with the "Ethernet" interface.

# ========================
# Function Definitions
# ========================

# Function to dynamically retrieve the IP address of the "Ethernet" interface
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

# Function to retrieve Docker container IP addresses and ports
function Get-DockerServices {
    $DockerServices = @{}
    docker ps --format '{{.Names}}' | ForEach-Object {
        $containerName = $_

        $ip = $(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $containerName)
        if (-not $ip) {
            Write-Error "No IP address found for container '$containerName'"
            return
        }
        $ports = docker inspect --format '{{json .NetworkSettings.Ports}}' $containerName | ConvertFrom-Json
        $portMappings = @()
        foreach ($port in $ports.PSObject.Properties) {
            $protocol = $port.Name.Split('/')[1].ToUpper()
            $containerPort = $port.Name.Split('/')[0]
            foreach ($binding in $port.Value) {
                $portMappings += @{ HostPort = $binding.HostPort; ContainerPort = $containerPort; Protocol = $protocol }
            }
        }
        $DockerServices[$containerName] = $portMappings
        Write-Host "Docker Service '$containerName' IP: $ip, Ports: $($portMappings | Out-String)"
    }
    return $DockerServices
}

# Function to add port proxy rules for TCP and UDP
function Add-PortProxy {
    param (
        [string]$HostIP,
        [string]$TargetIP,
        [array]$Ports
    )
    foreach ($port in $Ports) {
        try {
            $protocol = $port.Protocol.ToLower()
            $listenPort = $port.HostPort
            $connectPort = $port.ContainerPort
            if ($listenPort -and $connectPort) {
                Write-Host "Attempting to add port proxy for: $($listenPort) -> $($connectPort) on $($protocol)"
                netsh interface portproxy add v4tov4 listenport=$($listenPort) listenaddress=$($HostIP) connectport=$($connectPort) connectaddress=$($TargetIP) protocol=$($protocol)
                Write-Host "Added port proxy rule: $($HostIP):$($listenPort) -> $($TargetIP):$($connectPort) ($($protocol))"
                if ($protocol -eq 'udp') {
                    Write-Host "UDP port $($listenPort) has been successfully forwarded."
                }
            }
            else {
                Write-Error "Invalid port mapping for $($HostIP):$($listenPort) -> $($TargetIP):$($connectPort) ($($protocol))"
            }
        }
        catch {
            Write-Error "Failed to add port proxy rule for port $($listenPort) ($($protocol)): $_"
            throw
        }
    }
}

# Function to add firewall rules, now with a check for existing rules
function Add-FirewallRule {
    param (
        [array]$Ports,
        [string]$Direction = 'Inbound'
    )
    foreach ($port in $Ports) {
        try {
            $protocol = $port.Protocol.ToUpper()
            $hostPort = $port.HostPort
            
            # Check if a rule already exists
            $existingRule = Get-NetFirewallRule -Direction $Direction | Where-Object {
                $_.LocalPort -eq $hostPort -and $_.Protocol -eq $protocol
            }
            
            if ($existingRule) {
                Write-Host "Firewall rule already exists for port $($hostPort) ($($protocol)). Skipping..."
            }
            else {
                Write-Host "Adding firewall rule for port $($hostPort) ($($protocol))"
                New-NetFirewallRule -DisplayName "Port $($hostPort) $($protocol) Allow Rule" -Direction $Direction -Action Allow -Protocol $protocol -LocalPort $($hostPort)
                Write-Host "Added firewall rule for port $($hostPort) ($($protocol))"
            }
        }
        catch {
            Write-Error "Failed to add firewall rule for port $($hostPort) ($($protocol)): $_"
            throw
        }
    }
}


# ========================
# Main Script Execution
# ========================

try {
    $HostIP = Get-HostIP -InterfaceAlias 'Ethernet'  # Dynamically retrieve the host IP address

    $DockerServices = Get-DockerServices  # Dynamically retrieve Docker services and print full inspect output

    $PortMappingSummary = @()

    # Forward ports for Docker services
    foreach ($service in $DockerServices.Keys) {
        $ports = $DockerServices[$service]
        $dockerIP = $(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $service)
        if (-not $dockerIP) {
            Write-Error "Failed to get IP address for Docker container '$service'. Skipping..."
            continue
        }
        Add-PortProxy -HostIP $HostIP -TargetIP $dockerIP -Ports $ports
        Add-FirewallRule -Ports $ports -Direction 'Inbound'

        foreach ($port in $ports) {
            $PortMappingSummary += [PSCustomObject]@{
                HostIP        = $HostIP
                HostPort      = $port.HostPort
                TargetIP      = $dockerIP
                ContainerPort = $port.ContainerPort
                Protocol      = $port.Protocol.ToUpper()
            }
        }
    }

    # Display all port proxy rules with protocol distinction
    Write-Host "Custom Port Proxy Summary:"
    $PortMappingSummary | Format-Table -Property HostIP, HostPort, TargetIP, ContainerPort, Protocol
}
catch {
    Write-Error "An error occurred during script execution: $_"
    throw
}
