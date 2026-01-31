# System Health Monitor

Moniteur de sante systeme PowerShell pour surveiller l'etat des services Windows et des ressources systeme (CPU, RAM, Disque).

## Fonctionnalites

- **Surveillance des services Windows** : Verifie l'etat des services critiques configures
- **Metriques systeme** : Collecte CPU, memoire et espace disque
- **Alertes** : Detection automatique des depassements de seuils
- **Logging** : Fichiers logs horodates journaliers
- **Rapports CSV** : Export des alertes pour analyse

## Prerequis

- Windows PowerShell 5.1+ ou PowerShell Core 7+
- Droits administrateur (pour certaines metriques et services)

## Structure du projet

```
SystemHealthMonitor/
├── config/
│   └── monitoring-config.json    # Configuration
├── logs/
│   └── alerts-YYYY-MM-DD.log     # Logs journaliers
├── reports/
│   └── health-report-YYYY-MM-DD.csv  # Rapports CSV
├── src/
│   ├── Start-HealthMonitoring.ps1    # Script principal
│   ├── Get-ServiceHealth.ps1         # Module services
│   ├── Get-SystemResources.ps1       # Module ressources
│   └── Send-Alert.ps1                # Module alertes
└── README.md
```

## Configuration

Editez le fichier `config/monitoring-config.json` :

```json
{
  "services": [
    "W3SVC",
    "MSSQLSERVER",
    "Spooler"
  ],
  "thresholds": {
    "cpu_percent": 80,
    "memory_available_mb": 1024,
    "disk_free_percent": 20
  },
  "check_interval_seconds": 300,
  "alert_email": "devops@example.com"
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

## Exemples de sortie

### Console

```
=== MONITEUR DE SANTE SYSTEME ===
Version 1.0.0

[*] Chargement de la configuration...
[+] Configuration chargee avec succes

========================================
  VERIFICATION DE SANTE SYSTEME
  2026-01-31 14:30:00
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

----------------------------------------
Resume: 3 OK | 1 WARNING | 2 CRITICAL
----------------------------------------
```

### Fichier log (logs/alerts-2026-01-31.log)

```
[2026-01-31 14:30:00] [INFO] Service 'Spooler' est en cours d'execution
[2026-01-31 14:30:00] [CRITICAL] Service 'W3SVC' est arrete (Status: Stopped)
[2026-01-31 14:30:01] [INFO] Utilisation CPU: 45% (Seuil: 80%)
[2026-01-31 14:30:01] [CRITICAL] Disque C: - Espace libre: 15% (Seuil minimum: 20%)
```

### Rapport CSV (reports/health-report-2026-01-31.csv)

```csv
Timestamp,Type,Component,CurrentValue,Threshold,Status,Message,ComputerName
2026-01-31 14:30:00,Service,Spooler,Running,Running,OK,Service 'Spooler' est en cours d'execution,SERVEUR01
2026-01-31 14:30:00,CPU,Processor,45%,80%,OK,Utilisation CPU: 45%,SERVEUR01
```

## Planification avec Task Scheduler

Pour executer le moniteur automatiquement :

1. Ouvrir le Planificateur de taches Windows
2. Creer une nouvelle tache
3. Configurer le declencheur (ex: toutes les 5 minutes)
4. Action : Demarrer un programme
   - Programme : `powershell.exe`
   - Arguments : `-ExecutionPolicy Bypass -File "C:\SystemHealthMonitor\src\Start-HealthMonitoring.ps1"`

## Personnalisation

### Ajouter un service a surveiller

Editez `config/monitoring-config.json` et ajoutez le nom du service :

```json
{
  "services": [
    "W3SVC",
    "MSSQLSERVER",
    "Spooler",
    "MonNouveauService"
  ]
}
```

### Modifier les seuils d'alerte

```json
{
  "thresholds": {
    "cpu_percent": 90,
    "memory_available_mb": 2048,
    "disk_free_percent": 10
  }
}
```

## Evolutions futures (V2)

- [ ] Envoi d'emails via SMTP
- [ ] Webhooks Slack/Teams
- [ ] Monitoring multi-machines (PowerShell Remoting)
- [ ] Dashboard HTML avec graphiques
- [ ] Historique des metriques

## Auteur

Tene - Janvier 2026

## Licence

Ce projet est destine a l'apprentissage PowerShell dans un contexte DevOps.
