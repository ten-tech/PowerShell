<#
.SYNOPSIS
    Module de collecte des metriques systeme (CPU, RAM, Disque).
.DESCRIPTION
    Collecte les informations sur l'utilisation des ressources systeme
    et genere des alertes si les seuils configures sont depasses.
.NOTES
    Auteur: Tene
    Date: 2026-01-31
#>

function Get-CpuUsage {
    <#
    .SYNOPSIS
        Recupere le pourcentage d'utilisation CPU.
    .DESCRIPTION
        Utilise Get-CimInstance pour obtenir la charge processeur moyenne.
    .OUTPUTS
        Double representant le pourcentage d'utilisation CPU.
    #>
    [CmdletBinding()]
    param()

    try {
        $cpuLoad = Get-CimInstance -ClassName Win32_Processor |
            Measure-Object -Property LoadPercentage -Average |
            Select-Object -ExpandProperty Average

        return [math]::Round($cpuLoad, 2)
    }
    catch {
        Write-Error "Erreur lors de la recuperation de l'utilisation CPU: $_"
        return -1
    }
}

function Get-MemoryUsage {
    <#
    .SYNOPSIS
        Recupere les informations d'utilisation de la memoire.
    .DESCRIPTION
        Utilise Get-CimInstance Win32_OperatingSystem pour obtenir
        la memoire totale et disponible.
    .OUTPUTS
        PSCustomObject avec TotalMB, AvailableMB, UsedMB, UsedPercent.
    #>
    [CmdletBinding()]
    param()

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem

        $totalMemoryMB = [math]::Round($os.TotalVisibleMemorySize / 1024, 2)
        $freeMemoryMB = [math]::Round($os.FreePhysicalMemory / 1024, 2)
        $usedMemoryMB = $totalMemoryMB - $freeMemoryMB
        $usedPercent = [math]::Round(($usedMemoryMB / $totalMemoryMB) * 100, 2)

        return [PSCustomObject]@{
            TotalMB     = $totalMemoryMB
            AvailableMB = $freeMemoryMB
            UsedMB      = $usedMemoryMB
            UsedPercent = $usedPercent
        }
    }
    catch {
        Write-Error "Erreur lors de la recuperation de l'utilisation memoire: $_"
        return $null
    }
}

function Get-DiskUsage {
    <#
    .SYNOPSIS
        Recupere les informations d'utilisation des disques.
    .DESCRIPTION
        Utilise Get-PSDrive pour obtenir l'espace utilise et disponible
        sur chaque partition.
    .OUTPUTS
        Tableau de PSCustomObject avec DriveLetter, TotalGB, FreeGB, UsedGB, FreePercent.
    #>
    [CmdletBinding()]
    param()

    try {
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }

        $results = @()
        foreach ($drive in $drives) {
            $totalGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
            $freeGB = [math]::Round($drive.Free / 1GB, 2)
            $usedGB = [math]::Round($drive.Used / 1GB, 2)
            $freePercent = if ($totalGB -gt 0) {
                [math]::Round(($freeGB / $totalGB) * 100, 2)
            }
            else { 0 }

            $results += [PSCustomObject]@{
                DriveLetter = $drive.Name
                TotalGB     = $totalGB
                FreeGB      = $freeGB
                UsedGB      = $usedGB
                FreePercent = $freePercent
            }
        }

        return $results
    }
    catch {
        Write-Error "Erreur lors de la recuperation de l'utilisation disque: $_"
        return @()
    }
}

function Get-SystemResources {
    <#
    .SYNOPSIS
        Collecte toutes les metriques systeme et genere des alertes.
    .DESCRIPTION
        Fonction principale qui collecte CPU, RAM et Disque,
        compare aux seuils et genere des alertes appropriees.
    .PARAMETER Thresholds
        Objet contenant les seuils d'alerte (cpu_percent, memory_available_mb, disk_free_percent).
    .PARAMETER BasePath
        Chemin de base du projet pour le logging.
    .EXAMPLE
        $thresholds = @{ cpu_percent = 80; memory_available_mb = 1024; disk_free_percent = 20 }
        Get-SystemResources -Thresholds $thresholds -BasePath "C:\SystemHealthMonitor"
    .OUTPUTS
        Tableau d'objets PSCustomObject contenant les alertes generees.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Thresholds,

        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    $alerts = @()

    # Verification CPU
    Write-Verbose "Verification de l'utilisation CPU..."
    $cpuUsage = Get-CpuUsage
    if ($cpuUsage -ge 0) {
        $cpuStatus = if ($cpuUsage -gt $Thresholds.cpu_percent) { "CRITICAL" } else { "OK" }
        $cpuMessage = "Utilisation CPU: $cpuUsage% (Seuil: $($Thresholds.cpu_percent)%)"

        $alert = New-AlertObject `
            -Type "CPU" `
            -Component "Processor" `
            -CurrentValue "$cpuUsage%" `
            -Threshold "$($Thresholds.cpu_percent)%" `
            -Status $cpuStatus `
            -Message $cpuMessage

        $alerts += $alert

        $logLevel = if ($cpuStatus -eq "CRITICAL") { "CRITICAL" } else { "INFO" }
        Write-AlertLog -Message $cpuMessage -Level $logLevel -BasePath $BasePath
    }

    # Verification Memoire
    Write-Verbose "Verification de l'utilisation memoire..."
    $memory = Get-MemoryUsage
    if ($null -ne $memory) {
        $memStatus = if ($memory.AvailableMB -lt $Thresholds.memory_available_mb) { "CRITICAL" } else { "OK" }
        $memMessage = "Memoire disponible: $($memory.AvailableMB) MB (Seuil minimum: $($Thresholds.memory_available_mb) MB) - Utilisation: $($memory.UsedPercent)%"

        $alert = New-AlertObject `
            -Type "Memory" `
            -Component "RAM" `
            -CurrentValue "$($memory.AvailableMB) MB" `
            -Threshold "$($Thresholds.memory_available_mb) MB" `
            -Status $memStatus `
            -Message $memMessage

        $alerts += $alert

        $logLevel = if ($memStatus -eq "CRITICAL") { "CRITICAL" } else { "INFO" }
        Write-AlertLog -Message $memMessage -Level $logLevel -BasePath $BasePath
    }

    # Verification Disques
    Write-Verbose "Verification de l'utilisation des disques..."
    $disks = Get-DiskUsage
    foreach ($disk in $disks) {
        $diskStatus = if ($disk.FreePercent -lt $Thresholds.disk_free_percent) { "CRITICAL" } else { "OK" }
        $diskMessage = "Disque $($disk.DriveLetter): - Espace libre: $($disk.FreeGB) GB ($($disk.FreePercent)%) (Seuil minimum: $($Thresholds.disk_free_percent)%)"

        $alert = New-AlertObject `
            -Type "Disk" `
            -Component "Drive_$($disk.DriveLetter)" `
            -CurrentValue "$($disk.FreePercent)%" `
            -Threshold "$($Thresholds.disk_free_percent)%" `
            -Status $diskStatus `
            -Message $diskMessage

        $alerts += $alert

        $logLevel = if ($diskStatus -eq "CRITICAL") { "CRITICAL" } else { "INFO" }
        Write-AlertLog -Message $diskMessage -Level $logLevel -BasePath $BasePath
    }

    return $alerts
}
