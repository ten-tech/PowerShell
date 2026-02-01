<#
.SYNOPSIS
    Script d'installation du System Health Monitor.
.DESCRIPTION
    Configure l'environnement, cree les repertoires necessaires,
    et optionnellement configure une tache planifiee Windows.
.PARAMETER InstallPath
    Chemin d'installation (par defaut: C:\SystemHealthMonitor)
.PARAMETER CreateScheduledTask
    Cree une tache planifiee pour executer le monitoring automatiquement.
.PARAMETER TaskInterval
    Intervalle en minutes pour la tache planifiee (par defaut: 5).
.EXAMPLE
    .\Install-HealthMonitor.ps1
    Installation standard.
.EXAMPLE
    .\Install-HealthMonitor.ps1 -CreateScheduledTask -TaskInterval 10
    Installation avec tache planifiee toutes les 10 minutes.
.NOTES
    Auteur: Tene
    Date: 2026-02-01
    Necessite des droits administrateur pour la tache planifiee.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InstallPath = "C:\SystemHealthMonitor",

    [Parameter(Mandatory = $false)]
    [switch]$CreateScheduledTask,

    [Parameter(Mandatory = $false)]
    [int]$TaskInterval = 5
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[-] $Message" -ForegroundColor Red
}

# Banner
Write-Host @"

  ____            _                   _   _            _ _   _
 / ___| _   _ ___| |_ ___ _ __ ___   | | | | ___  __ _| | |_| |__
 \___ \| | | / __| __/ _ \ '_ ` _ \  | |_| |/ _ \/ _` | | __| '_ \
  ___) | |_| \__ \ ||  __/ | | | | | |  _  |  __/ (_| | | |_| | | |
 |____/ \__, |___/\__\___|_| |_| |_| |_| |_|\___|\__,_|_|\__|_| |_|
        |___/
                    Monitor Installer v2.0.0

"@ -ForegroundColor Magenta

try {
    # Verification des droits admin si tache planifiee demandee
    if ($CreateScheduledTask) {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            throw "Les droits administrateur sont requis pour creer une tache planifiee. Relancez en tant qu'administrateur."
        }
    }

    # Determination du chemin source
    $scriptRoot = Split-Path -Path $PSScriptRoot -Parent

    Write-Step "Installation vers: $InstallPath"

    # Creation du repertoire d'installation
    if (-not (Test-Path -Path $InstallPath)) {
        New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
        Write-Success "Repertoire cree: $InstallPath"
    }

    # Copie des fichiers
    Write-Step "Copie des fichiers..."

    $folders = @("src", "config")
    foreach ($folder in $folders) {
        $source = Join-Path -Path $scriptRoot -ChildPath $folder
        $dest = Join-Path -Path $InstallPath -ChildPath $folder
        if (Test-Path -Path $source) {
            Copy-Item -Path $source -Destination $dest -Recurse -Force
            Write-Success "Copie: $folder/"
        }
    }

    # Creation des repertoires de donnees
    $dataFolders = @("logs", "reports")
    foreach ($folder in $dataFolders) {
        $path = Join-Path -Path $InstallPath -ChildPath $folder
        if (-not (Test-Path -Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            Write-Success "Cree: $folder/"
        }
    }

    # Verification de la configuration
    $configPath = Join-Path -Path $InstallPath -ChildPath "config\monitoring-config.json"
    $examplePath = Join-Path -Path $InstallPath -ChildPath "config\monitoring-config.example.json"

    if (-not (Test-Path -Path $configPath) -and (Test-Path -Path $examplePath)) {
        Copy-Item -Path $examplePath -Destination $configPath
        Write-Success "Configuration creee a partir de l'exemple"
        Write-Host "    -> Editez $configPath selon vos besoins" -ForegroundColor Yellow
    }

    # Creation de la tache planifiee
    if ($CreateScheduledTask) {
        Write-Step "Creation de la tache planifiee..."

        $taskName = "SystemHealthMonitor"
        $scriptPath = Join-Path -Path $InstallPath -ChildPath "src\Start-HealthMonitoring.ps1"

        # Suppression de l'ancienne tache si elle existe
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Host "    Ancienne tache supprimee" -ForegroundColor Yellow
        }

        # Creation de la nouvelle tache
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $TaskInterval)
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null

        Write-Success "Tache planifiee creee: $taskName (toutes les $TaskInterval minutes)"
    }

    # Resume
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  INSTALLATION TERMINEE AVEC SUCCES" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`nChemin d'installation: $InstallPath"
    Write-Host "`nPour lancer manuellement:"
    Write-Host "  powershell -File `"$InstallPath\src\Start-HealthMonitoring.ps1`"" -ForegroundColor Cyan
    Write-Host "`nPour le mode continu:"
    Write-Host "  powershell -File `"$InstallPath\src\Start-HealthMonitoring.ps1`" -Continuous" -ForegroundColor Cyan

    if ($CreateScheduledTask) {
        Write-Host "`nTache planifiee: SystemHealthMonitor (active)" -ForegroundColor Green
    }
}
catch {
    Write-Fail "Erreur lors de l'installation: $_"
    exit 1
}
