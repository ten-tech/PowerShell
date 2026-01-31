<#
.SYNOPSIS
    Module de surveillance de l'etat des services Windows.
.DESCRIPTION
    Verifie l'etat des services Windows definis dans la configuration
    et retourne des alertes si des services sont arretes.
.NOTES
    Auteur: Tene
    Date: 2026-01-31
#>

function Get-ServiceHealth {
    <#
    .SYNOPSIS
        Verifie l'etat de sante des services Windows configures.
    .DESCRIPTION
        Parcourt la liste des services definis dans la configuration
        et verifie si chacun est en cours d'execution.
    .PARAMETER Services
        Tableau des noms de services a surveiller.
    .PARAMETER BasePath
        Chemin de base du projet pour le logging.
    .EXAMPLE
        Get-ServiceHealth -Services @("W3SVC", "MSSQLSERVER") -BasePath "C:\SystemHealthMonitor"
    .OUTPUTS
        Tableau d'objets PSCustomObject contenant le statut de chaque service.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Services,

        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    $results = @()

    foreach ($serviceName in $Services) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop

            $status = if ($service.Status -eq "Running") { "OK" } else { "CRITICAL" }
            $message = if ($service.Status -eq "Running") {
                "Service '$serviceName' est en cours d'execution"
            }
            else {
                "Service '$serviceName' est arrete (Status: $($service.Status))"
            }

            $alert = New-AlertObject `
                -Type "Service" `
                -Component $serviceName `
                -CurrentValue $service.Status.ToString() `
                -Threshold "Running" `
                -Status $status `
                -Message $message

            $results += $alert

            if ($status -eq "CRITICAL") {
                Write-AlertLog -Message $message -Level "CRITICAL" -BasePath $BasePath
            }
            else {
                Write-AlertLog -Message $message -Level "INFO" -BasePath $BasePath
            }
        }
        catch [Microsoft.PowerShell.Commands.ServiceCommandException] {
            $message = "Service '$serviceName' introuvable sur cette machine"

            $alert = New-AlertObject `
                -Type "Service" `
                -Component $serviceName `
                -CurrentValue "NotFound" `
                -Threshold "Running" `
                -Status "WARNING" `
                -Message $message

            $results += $alert
            Write-AlertLog -Message $message -Level "WARNING" -BasePath $BasePath
        }
        catch {
            $message = "Erreur lors de la verification du service '$serviceName': $_"

            $alert = New-AlertObject `
                -Type "Service" `
                -Component $serviceName `
                -CurrentValue "Error" `
                -Threshold "Running" `
                -Status "CRITICAL" `
                -Message $message

            $results += $alert
            Write-AlertLog -Message $message -Level "ERROR" -BasePath $BasePath
        }
    }

    return $results
}

function Start-ServiceRecovery {
    <#
    .SYNOPSIS
        Tente de redemarrer un service arrete.
    .DESCRIPTION
        Fonction optionnelle pour tenter de redemarrer automatiquement
        un service qui a ete detecte comme arrete.
    .PARAMETER ServiceName
        Nom du service a redemarrer.
    .PARAMETER BasePath
        Chemin de base du projet pour le logging.
    .EXAMPLE
        Start-ServiceRecovery -ServiceName "Spooler" -BasePath "C:\SystemHealthMonitor"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    try {
        Write-AlertLog -Message "Tentative de redemarrage du service '$ServiceName'..." -Level "WARNING" -BasePath $BasePath

        Start-Service -Name $ServiceName -ErrorAction Stop

        Start-Sleep -Seconds 5

        $service = Get-Service -Name $ServiceName
        if ($service.Status -eq "Running") {
            Write-AlertLog -Message "Service '$ServiceName' redemarre avec succes" -Level "INFO" -BasePath $BasePath
            return $true
        }
        else {
            Write-AlertLog -Message "Echec du redemarrage du service '$ServiceName'" -Level "ERROR" -BasePath $BasePath
            return $false
        }
    }
    catch {
        Write-AlertLog -Message "Erreur lors du redemarrage du service '$ServiceName': $_" -Level "ERROR" -BasePath $BasePath
        return $false
    }
}
