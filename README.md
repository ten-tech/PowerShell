# System Health Monitor

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Version](https://img.shields.io/badge/Version-2.0.0-green.svg)](CHANGELOG.md)

Moniteur de sante systeme PowerShell pour surveiller l'etat des services Windows et des ressources systeme (CPU, RAM, Disque). Inclut un dashboard HTML interactif avec graphiques en temps reel.

## Fonctionnalites

- **Surveillance des services Windows** : Verifie l'etat des services critiques configures
- **Metriques systeme** : Collecte CPU, memoire et espace disque
- **Alertes** : Detection automatique des depassements de seuils
- **Dashboard HTML** : Interface web interactive avec graphiques Chart.js
- **Score de sante** : Indicateur global de l'etat du systeme
- **Historique** : Suivi des metriques sur 48 points
- **Logging** : Fichiers logs horodates journaliers
- **Rapports CSV** : Export des alertes pour analyse
- **Installation automatisee** : Script d'installation avec tache planifiee

## Apercu du Dashboard

Le dashboard genere automatiquement affiche:
- Score de sante global avec jauge animee
- Etat des services Windows
- Utilisation CPU et RAM avec barres de progression
- Espace disque avec graphique donut
- Historique des metriques sur graphique

## Prerequis

- Windows PowerShell 5.1+ ou PowerShell Core 7+
- Droits administrateur (pour certaines metriques et tache planifiee)

## Structure du projet

```
SystemHealthMonitor/
├── config/
│   ├── monitoring-config.json          # Configuration active
│   └── monitoring-config.example.json  # Template de configuration
├── logs/
│   └── alerts-YYYY-MM-DD.log           # Logs journaliers
├── reports/
│   ├── health-report-YYYY-MM-DD.csv    # Rapports CSV
│   ├── dashboard.html                  # Dashboard interactif
│   └── metrics-history.json            # Historique des metriques
├── scripts/
│   └── Install-HealthMonitor.ps1       # Script d'installation
├── src/
│   ├── Start-HealthMonitoring.ps1      # Script principal
│   ├── Get-ServiceHealth.ps1           # Module services
│   ├── Get-SystemResources.ps1         # Module ressources
│   ├── Send-Alert.ps1                  # Module alertes
│   └── New-HtmlDashboard.ps1           # Module dashboard
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Installation rapide

### Option 1: Installation manuelle

```powershell
git clone git@github.com:ten-tech/PowerShell.git
cd PowerShell
.\src\Start-HealthMonitoring.ps1
```

### Option 2: Installation automatisee

```powershell
# Installation standard
.\scripts\Install-HealthMonitor.ps1

# Installation avec tache planifiee (toutes les 5 minutes)
.\scripts\Install-HealthMonitor.ps1 -CreateScheduledTask -TaskInterval 5
```

## Configuration

Copiez le fichier exemple et editez selon vos besoins:

```powershell
Copy-Item config/monitoring-config.example.json config/monitoring-config.json
```

### Fichier de configuration

```json
{
  "services": ["W3SVC", "MSSQLSERVER", "Spooler"],
  "thresholds": {
    "cpu_percent": 80,
    "memory_available_mb": 1024,
    "disk_free_percent": 20
  },
  "check_interval_seconds": 300,
  "alert_email": "devops@example.com",
  "dashboard": {
    "enabled": true,
    "auto_open": false,
    "history_entries": 24
  }
}
```

### Parametres

| Parametre | Description |
|-----------|-------------|
| `services` | Liste des noms de services Windows a surveiller |
| `thresholds.cpu_percent` | Seuil d'alerte CPU (%) |
| `thresholds.memory_available_mb` | Seuil minimum de RAM disponible (MB) |
| `thresholds.disk_free_percent` | Seuil minimum d'espace disque libre (%) |
| `check_interval_seconds` | Intervalle entre les verifications en mode continu |
| `dashboard.enabled` | Active/desactive la generation du dashboard |
| `dashboard.history_entries` | Nombre de points dans l'historique |

## Utilisation

### Execution unique

```powershell
# Avec configuration par defaut
.\src\Start-HealthMonitoring.ps1

# Avec configuration personnalisee
.\src\Start-HealthMonitoring.ps1 -ConfigPath "C:\chemin\vers\config.json"

# Mode verbose
.\src\Start-HealthMonitoring.ps1 -Verbose
```

### Mode surveillance continue

```powershell
# Lance la surveillance en boucle (Ctrl+C pour arreter)
.\src\Start-HealthMonitoring.ps1 -Continuous
```

### Acces au dashboard

Apres execution, ouvrez le fichier genere:

```powershell
Start-Process "reports\dashboard.html"
```

## Exemples de sortie

### Console

```
=== MONITEUR DE SANTE SYSTEME ===
Version 2.0.0

[*] Chargement de la configuration...
[+] Configuration chargee avec succes

========================================
  VERIFICATION DE SANTE SYSTEME
  2026-02-01 10:30:00
  Machine: SERVEUR01
========================================

[*] Verification des services Windows...
    [OK] Spooler: Running
    [CRITICAL] W3SVC: Stopped
    [WARNING] MSSQLSERVER: NotFound

[*] Verification des ressources systeme...
    [OK] CPU - Processor: 45%
    [OK] Memory - RAM: 4096 MB
    [CRITICAL] Disk - Drive_C: 15%

[*] Rapport exporte: reports\health-report-2026-02-01.csv
[*] Dashboard HTML: reports\dashboard.html

----------------------------------------
Resume: 3 OK | 1 WARNING | 2 CRITICAL
----------------------------------------
```

### Fichier log (logs/alerts-2026-02-01.log)

```
[2026-02-01 10:30:00] [INFO] Service 'Spooler' est en cours d'execution
[2026-02-01 10:30:00] [CRITICAL] Service 'W3SVC' est arrete (Status: Stopped)
[2026-02-01 10:30:01] [INFO] Utilisation CPU: 45% (Seuil: 80%)
[2026-02-01 10:30:01] [CRITICAL] Disque C: - Espace libre: 15% (Seuil minimum: 20%)
```

## Planification automatique

### Avec le script d'installation

```powershell
# Installe et cree une tache planifiee
.\scripts\Install-HealthMonitor.ps1 -CreateScheduledTask -TaskInterval 5
```

### Manuellement avec Task Scheduler

1. Ouvrir le Planificateur de taches Windows
2. Creer une nouvelle tache
3. Configurer le declencheur (ex: toutes les 5 minutes)
4. Action : Demarrer un programme
   - Programme : `powershell.exe`
   - Arguments : `-ExecutionPolicy Bypass -File "C:\SystemHealthMonitor\src\Start-HealthMonitoring.ps1"`

## Evolutions futures (V2)

- [ ] Envoi d'emails via SMTP
- [ ] Webhooks Slack/Teams
- [ ] Monitoring multi-machines (PowerShell Remoting)
- [x] Dashboard HTML avec graphiques
- [x] Historique des metriques
- [x] Script d'installation automatise

## Changelog

Voir [CHANGELOG.md](CHANGELOG.md) pour l'historique des versions.

## Auteur

Tene - 2026

## Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de details.
