<#
.SYNOPSIS
    Script principal du moniteur de sante systeme.
.DESCRIPTION
    Lance la surveillance de l'etat de sante du systeme en verifiant
    les services Windows et les ressources systeme (CPU, RAM, Disque).
    Genere des alertes et des rapports en fonction des seuils configures.
.PARAMETER ConfigPath
    Chemin vers le fichier de configuration JSON.
    Par defaut: .\config\monitoring-config.json
.PARAMETER Continuous
    Active le mode surveillance continue avec l'intervalle defini dans la config.
.PARAMETER SingleRun
    Execute une seule verification (par defaut si -Continuous n'est pas specifie).
.EXAMPLE
    .\Start-HealthMonitoring.ps1
    Execute une verification unique avec la configuration par defaut.
.EXAMPLE
    .\Start-HealthMonitoring.ps1 -ConfigPath "C:\config\custom-config.json"
    Execute avec un fichier de configuration personnalise.
.EXAMPLE
    .\Start-HealthMonitoring.ps1 -Continuous
    Lance la surveillance en mode continu (Ctrl+C pour arreter).
.NOTES
    Auteur: Tene
    Date: 2026-01-31
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [switch]$Continuous
)

# Determination du chemin de base du projet
$scriptPath = $PSScriptRoot
$basePath = Split-Path -Path $scriptPath -Parent

# Chemin par defaut de la configuration
if (-not $ConfigPath) {
    $ConfigPath = Join-Path -Path (Join-Path -Path $basePath -ChildPath "config") -ChildPath "monitoring-config.json"
}

# Chargement des modules
. (Join-Path -Path $scriptPath -ChildPath "Send-Alert.ps1")
. (Join-Path -Path $scriptPath -ChildPath "Get-ServiceHealth.ps1")
. (Join-Path -Path $scriptPath -ChildPath "Get-SystemResources.ps1")
. (Join-Path -Path $scriptPath -ChildPath "New-HtmlDashboard.ps1")

function Import-MonitoringConfig {
    <#
    .SYNOPSIS
        Charge et valide le fichier de configuration JSON.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if (-not (Test-Path -Path $Path)) {
            throw "Fichier de configuration introuvable: $Path"
        }

        $config = Get-Content -Path $Path -Raw | ConvertFrom-Json

        # Validation des champs requis
        if (-not $config.services) {
            throw "Configuration invalide: 'services' est requis"
        }
        if (-not $config.thresholds) {
            throw "Configuration invalide: 'thresholds' est requis"
        }
        if (-not $config.thresholds.cpu_percent) {
            $config.thresholds | Add-Member -NotePropertyName "cpu_percent" -NotePropertyValue 80
        }
        if (-not $config.thresholds.memory_available_mb) {
            $config.thresholds | Add-Member -NotePropertyName "memory_available_mb" -NotePropertyValue 1024
        }
        if (-not $config.thresholds.disk_free_percent) {
            $config.thresholds | Add-Member -NotePropertyName "disk_free_percent" -NotePropertyValue 20
        }
        if (-not $config.check_interval_seconds) {
            $config | Add-Member -NotePropertyName "check_interval_seconds" -NotePropertyValue 300
        }

        return $config
    }
    catch {
        Write-Error "Erreur lors du chargement de la configuration: $_"
        throw
    }
}

function Start-HealthCheck {
    <#
    .SYNOPSIS
        Execute une verification complete de sante systeme.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config,

        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    $allAlerts = @()
    $criticalCount = 0

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  VERIFICATION DE SANTE SYSTEME" -ForegroundColor Cyan
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "  Machine: $env:COMPUTERNAME" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Verification des services
    Write-Host "[*] Verification des services Windows..." -ForegroundColor Yellow
    $serviceAlerts = Get-ServiceHealth -Services $Config.services -BasePath $BasePath
    $allAlerts += $serviceAlerts

    foreach ($alert in $serviceAlerts) {
        $color = switch ($alert.Status) {
            "OK" { "Green" }
            "WARNING" { "Yellow" }
            "CRITICAL" { "Red" }
        }
        Write-Host "    [$($alert.Status)] $($alert.Component): $($alert.CurrentValue)" -ForegroundColor $color
        if ($alert.Status -eq "CRITICAL") { $criticalCount++ }
    }

    # Verification des ressources systeme
    Write-Host "`n[*] Verification des ressources systeme..." -ForegroundColor Yellow

    $thresholdsHashtable = @{
        cpu_percent         = $Config.thresholds.cpu_percent
        memory_available_mb = $Config.thresholds.memory_available_mb
        disk_free_percent   = $Config.thresholds.disk_free_percent
    }

    $resourceAlerts = Get-SystemResources -Thresholds $thresholdsHashtable -BasePath $BasePath
    $allAlerts += $resourceAlerts

    foreach ($alert in $resourceAlerts) {
        $color = switch ($alert.Status) {
            "OK" { "Green" }
            "WARNING" { "Yellow" }
            "CRITICAL" { "Red" }
        }
        Write-Host "    [$($alert.Status)] $($alert.Type) - $($alert.Component): $($alert.CurrentValue)" -ForegroundColor $color
        if ($alert.Status -eq "CRITICAL") { $criticalCount++ }
    }

    # Export du rapport
    if ($allAlerts.Count -gt 0) {
        $reportPath = Export-AlertReport -Alerts $allAlerts -BasePath $BasePath
        Write-Host "`n[*] Rapport exporte: $reportPath" -ForegroundColor Cyan

        # Generation du dashboard HTML
        $dashboardPath = New-HtmlDashboard -Alerts $allAlerts -BasePath $BasePath
        Write-Host "[*] Dashboard HTML: $dashboardPath" -ForegroundColor Cyan
    }

    # Resume
    Write-Host "`n----------------------------------------" -ForegroundColor Cyan
    $okCount = ($allAlerts | Where-Object { $_.Status -eq "OK" }).Count
    $warningCount = ($allAlerts | Where-Object { $_.Status -eq "WARNING" }).Count

    Write-Host "Resume: " -NoNewline
    Write-Host "$okCount OK" -ForegroundColor Green -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "$warningCount WARNING" -ForegroundColor Yellow -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "$criticalCount CRITICAL" -ForegroundColor Red
    Write-Host "----------------------------------------`n" -ForegroundColor Cyan

    return $allAlerts
}

# Point d'entree principal
try {
    Write-Host "`n=== MONITEUR DE SANTE SYSTEME ===" -ForegroundColor Magenta
    Write-Host "Version 1.0.0`n" -ForegroundColor Magenta

    # Initialisation des repertoires
    Initialize-AlertDirectories -BasePath $basePath

    # Chargement de la configuration
    Write-Host "[*] Chargement de la configuration: $ConfigPath" -ForegroundColor Yellow
    $config = Import-MonitoringConfig -Path $ConfigPath
    Write-Host "[+] Configuration chargee avec succes" -ForegroundColor Green
    Write-Host "    - Services surveilles: $($config.services -join ', ')"
    Write-Host "    - Seuil CPU: $($config.thresholds.cpu_percent)%"
    Write-Host "    - Seuil RAM disponible: $($config.thresholds.memory_available_mb) MB"
    Write-Host "    - Seuil Disque libre: $($config.thresholds.disk_free_percent)%"

    if ($Continuous) {
        Write-Host "`n[!] Mode surveillance continue active (Ctrl+C pour arreter)" -ForegroundColor Magenta
        Write-Host "    Intervalle: $($config.check_interval_seconds) secondes`n"

        while ($true) {
            $alerts = Start-HealthCheck -Config $config -BasePath $basePath

            Write-Host "Prochaine verification dans $($config.check_interval_seconds) secondes..." -ForegroundColor DarkGray
            Start-Sleep -Seconds $config.check_interval_seconds
        }
    }
    else {
        # Execution unique
        $alerts = Start-HealthCheck -Config $config -BasePath $basePath

        Write-Host "[+] Verification terminee" -ForegroundColor Green
    }
}
catch {
    Write-Host "[ERREUR] $($_.Exception.Message)" -ForegroundColor Red
    Write-AlertLog -Message "Erreur fatale: $_" -Level "CRITICAL" -BasePath $basePath
    exit 1
}
