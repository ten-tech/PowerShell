<#
.SYNOPSIS
    Module de gestion des alertes et du logging pour le moniteur de sante systeme.
.DESCRIPTION
    Contient les fonctions pour ecrire des logs horodates et exporter les alertes au format CSV.
.NOTES
    Auteur: Tene
    Date: 2026-01-31
#>

function Initialize-AlertDirectories {
    <#
    .SYNOPSIS
        Cree les repertoires logs et reports s'ils n'existent pas.
    .PARAMETER BasePath
        Chemin de base du projet SystemHealthMonitor.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    $logsPath = Join-Path -Path $BasePath -ChildPath "logs"
    $reportsPath = Join-Path -Path $BasePath -ChildPath "reports"

    try {
        if (-not (Test-Path -Path $logsPath)) {
            New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Repertoire logs cree: $logsPath"
        }

        if (-not (Test-Path -Path $reportsPath)) {
            New-Item -Path $reportsPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Repertoire reports cree: $reportsPath"
        }
    }
    catch {
        Write-Error "Erreur lors de la creation des repertoires: $_"
        throw
    }
}

function Write-AlertLog {
    <#
    .SYNOPSIS
        Ecrit une entree dans le fichier de log horodate.
    .PARAMETER Message
        Message a logger.
    .PARAMETER Level
        Niveau de severite (INFO, WARNING, ERROR, CRITICAL).
    .PARAMETER BasePath
        Chemin de base du projet SystemHealthMonitor.
    .EXAMPLE
        Write-AlertLog -Message "Service W3SVC arrete" -Level "ERROR" -BasePath "C:\SystemHealthMonitor"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $dateForFile = Get-Date -Format "yyyy-MM-dd"
        $logFileName = "alerts-$dateForFile.log"
        $logPath = Join-Path -Path (Join-Path -Path $BasePath -ChildPath "logs") -ChildPath $logFileName

        $logEntry = "[$timestamp] [$Level] $Message"

        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8

        switch ($Level) {
            "INFO" { Write-Verbose $logEntry }
            "WARNING" { Write-Warning $Message }
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "CRITICAL" { Write-Host $logEntry -ForegroundColor DarkRed -BackgroundColor Yellow }
        }
    }
    catch {
        Write-Error "Erreur lors de l'ecriture du log: $_"
    }
}

function Export-AlertReport {
    <#
    .SYNOPSIS
        Exporte les alertes et metriques dans un fichier CSV.
    .PARAMETER Alerts
        Tableau d'objets contenant les alertes a exporter.
    .PARAMETER BasePath
        Chemin de base du projet SystemHealthMonitor.
    .EXAMPLE
        Export-AlertReport -Alerts $alertsArray -BasePath "C:\SystemHealthMonitor"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Alerts,

        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    try {
        $dateForFile = Get-Date -Format "yyyy-MM-dd"
        $reportFileName = "health-report-$dateForFile.csv"
        $reportPath = Join-Path -Path (Join-Path -Path $BasePath -ChildPath "reports") -ChildPath $reportFileName

        if (Test-Path -Path $reportPath) {
            $Alerts | Export-Csv -Path $reportPath -Append -NoTypeInformation -Encoding UTF8
        }
        else {
            $Alerts | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
        }

        Write-Verbose "Rapport exporte vers: $reportPath"
        return $reportPath
    }
    catch {
        Write-Error "Erreur lors de l'export du rapport CSV: $_"
        throw
    }
}

function New-AlertObject {
    <#
    .SYNOPSIS
        Cree un objet alerte standardise.
    .PARAMETER Type
        Type d'alerte (Service, CPU, Memory, Disk).
    .PARAMETER Component
        Nom du composant concerne.
    .PARAMETER CurrentValue
        Valeur actuelle mesuree.
    .PARAMETER Threshold
        Seuil d'alerte configure.
    .PARAMETER Status
        Statut (OK, WARNING, CRITICAL).
    .PARAMETER Message
        Message descriptif de l'alerte.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Component,

        [Parameter(Mandatory = $false)]
        [string]$CurrentValue = "",

        [Parameter(Mandatory = $false)]
        [string]$Threshold = "",

        [Parameter(Mandatory = $true)]
        [ValidateSet("OK", "WARNING", "CRITICAL")]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    return [PSCustomObject]@{
        Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Type         = $Type
        Component    = $Component
        CurrentValue = $CurrentValue
        Threshold    = $Threshold
        Status       = $Status
        Message      = $Message
        ComputerName = $env:COMPUTERNAME
    }
}
