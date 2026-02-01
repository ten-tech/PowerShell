<#
.SYNOPSIS
    Module de generation du dashboard HTML pour le moniteur de sante systeme.
.DESCRIPTION
    Genere une page HTML interactive avec graphiques pour visualiser
    l'etat des services et des ressources systeme.
    Design professionnel avec Tailwind CSS et Chart.js.
.NOTES
    Auteur: Tene
    Date: 2026-02-01
    Version: 2.0.0
#>

function New-HtmlDashboard {
    <#
    .SYNOPSIS
        Genere un dashboard HTML moderne a partir des alertes collectees.
    .PARAMETER Alerts
        Tableau d'objets contenant les alertes et metriques.
    .PARAMETER BasePath
        Chemin de base du projet SystemHealthMonitor.
    .PARAMETER DashboardFileName
        Nom du fichier HTML a generer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Alerts,

        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $false)]
        [string]$DashboardFileName = "dashboard.html"
    )

    try {
        $reportsPath = Join-Path -Path $BasePath -ChildPath "reports"
        $dashboardPath = Join-Path -Path $reportsPath -ChildPath $DashboardFileName

        # Preparation des donnees
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $computerName = $env:COMPUTERNAME
        $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption
        $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $uptimeStr = "{0}j {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes

        # Comptage des statuts
        $okCount = ($Alerts | Where-Object { $_.Status -eq "OK" }).Count
        $warningCount = ($Alerts | Where-Object { $_.Status -eq "WARNING" }).Count
        $criticalCount = ($Alerts | Where-Object { $_.Status -eq "CRITICAL" }).Count
        $totalCount = $Alerts.Count

        # Calcul du score de sante global
        $healthScore = if ($totalCount -gt 0) {
            [math]::Round((($okCount * 100 + $warningCount * 50) / $totalCount), 0)
        } else { 100 }

        $healthStatus = if ($criticalCount -gt 0) { "critical" }
                        elseif ($warningCount -gt 0) { "warning" }
                        else { "healthy" }

        # Separation par type
        $serviceAlerts = $Alerts | Where-Object { $_.Type -eq "Service" }
        $cpuAlerts = $Alerts | Where-Object { $_.Type -eq "CPU" }
        $memoryAlerts = $Alerts | Where-Object { $_.Type -eq "Memory" }
        $diskAlerts = $Alerts | Where-Object { $_.Type -eq "Disk" }

        # Extraction des valeurs (format: "45%" ou "1234.56 MB")
        $cpuValue = 0
        $cpuThreshold = 80
        if ($cpuAlerts) {
            # CPU: extraire le nombre avant le %
            $cpuValue = [int](($cpuAlerts[0].CurrentValue -split '%')[0])
            $cpuThreshold = [int](($cpuAlerts[0].Threshold -split '%')[0])
        }

        $memoryValue = 0
        $memoryThreshold = 1024
        if ($memoryAlerts) {
            # Memory: extraire le nombre avant " MB"
            $memoryValue = [math]::Round([double](($memoryAlerts[0].CurrentValue -split ' ')[0]))
            $memoryThreshold = [math]::Round([double](($memoryAlerts[0].Threshold -split ' ')[0]))
        }
        $memoryTotal = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
        $memoryUsed = $memoryTotal - $memoryValue
        $memoryPercent = [math]::Round(($memoryUsed / $memoryTotal) * 100, 1)

        # Generation HTML des services
        $servicesHtml = ""
        foreach ($svc in $serviceAlerts) {
            $statusColor = switch ($svc.Status) {
                "OK" { "emerald" }
                "WARNING" { "amber" }
                "CRITICAL" { "red" }
            }
            $statusIcon = switch ($svc.Status) {
                "OK" { '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>' }
                "WARNING" { '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>' }
                "CRITICAL" { '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>' }
            }
            $servicesHtml += @"
            <div class="flex items-center justify-between p-4 bg-slate-800/50 rounded-xl border border-slate-700/50 hover:border-$statusColor-500/50 transition-all duration-300">
                <div class="flex items-center gap-3">
                    <div class="p-2 bg-$statusColor-500/20 rounded-lg text-$statusColor-400">
                        $statusIcon
                    </div>
                    <div>
                        <p class="font-semibold text-white">$($svc.Component)</p>
                        <p class="text-sm text-slate-400">$($svc.CurrentValue)</p>
                    </div>
                </div>
                <span class="px-3 py-1 text-xs font-medium bg-$statusColor-500/20 text-$statusColor-400 rounded-full">
                    $($svc.Status)
                </span>
            </div>
"@
        }

        # Generation HTML des disques
        $disksHtml = ""
        $diskLabels = @()
        $diskUsedData = @()
        $diskFreeData = @()
        foreach ($disk in $diskAlerts) {
            # Disk: extraire le nombre avant le % (format: "45.67%")
            $diskFree = [math]::Round([double](($disk.CurrentValue -split '%')[0]))
            $diskUsed = 100 - $diskFree
            $diskThreshold = [math]::Round([double](($disk.Threshold -split '%')[0]))
            $statusColor = switch ($disk.Status) {
                "OK" { "emerald" }
                "WARNING" { "amber" }
                "CRITICAL" { "red" }
            }
            $diskLabels += "'$($disk.Component)'"
            $diskUsedData += $diskUsed
            $diskFreeData += $diskFree

            $disksHtml += @"
            <div class="p-4 bg-slate-800/50 rounded-xl border border-slate-700/50">
                <div class="flex justify-between items-center mb-3">
                    <span class="font-medium text-white">$($disk.Component)</span>
                    <span class="text-$statusColor-400 font-semibold">${diskFree}% libre</span>
                </div>
                <div class="h-3 bg-slate-700 rounded-full overflow-hidden">
                    <div class="h-full bg-gradient-to-r from-$statusColor-500 to-$statusColor-400 rounded-full transition-all duration-500" style="width: ${diskUsed}%"></div>
                </div>
                <div class="flex justify-between mt-2 text-xs text-slate-500">
                    <span>Utilise: ${diskUsed}%</span>
                    <span>Seuil: ${diskThreshold}%</span>
                </div>
            </div>
"@
        }

        # Gestion de l'historique
        $historyPath = Join-Path -Path $reportsPath -ChildPath "metrics-history.json"
        $historyList = [System.Collections.ArrayList]::new()

        if (Test-Path -Path $historyPath) {
            try {
                $jsonContent = Get-Content -Path $historyPath -Raw | ConvertFrom-Json
                # S'assurer qu'on a un tableau d'objets valides
                foreach ($item in $jsonContent) {
                    if ($item.Timestamp -and $item.PSObject.Properties['CPU']) {
                        [void]$historyList.Add($item)
                    }
                }
            } catch {
                # Fichier corrompu, on repart de zero
                $historyList.Clear()
            }
        }

        # Ajout nouvelle entree
        $newEntry = [PSCustomObject]@{
            Timestamp       = $timestamp
            CPU             = $cpuValue
            MemoryPercent   = $memoryPercent
            MemoryAvailable = $memoryValue
            HealthScore     = $healthScore
        }
        [void]$historyList.Add($newEntry)

        # Garder les 48 dernieres entrees
        while ($historyList.Count -gt 48) {
            $historyList.RemoveAt(0)
        }

        # Sauvegarder en JSON (forcer le tableau)
        $jsonOutput = ConvertTo-Json -InputObject @($historyList) -Depth 3
        Set-Content -Path $historyPath -Value $jsonOutput -Encoding UTF8

        # Preparation donnees Chart.js
        $historyLabels = ($historyList | ForEach-Object {
            if ($_.Timestamp) { "'$(($_.Timestamp -split ' ')[1].Substring(0,5))'" } else { "'--:--'" }
        }) -join ","
        $historyCpu = ($historyList | ForEach-Object { if ($null -ne $_.CPU) { $_.CPU } else { 0 } }) -join ","
        $historyMem = ($historyList | ForEach-Object { if ($null -ne $_.MemoryPercent) { [math]::Max(0, $_.MemoryPercent) } else { 0 } }) -join ","
        $historyHealth = ($historyList | ForEach-Object { if ($null -ne $_.HealthScore) { $_.HealthScore } else { 100 } }) -join ","

        $diskLabelsStr = $diskLabels -join ","
        $diskUsedStr = $diskUsedData -join ","

        # Template HTML avec Tailwind CSS
        $htmlContent = @"
<!DOCTYPE html>
<html lang="fr" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="300">
    <title>System Health Monitor | $computerName</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    animation: {
                        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
                        'gradient': 'gradient 8s linear infinite',
                    },
                    keyframes: {
                        gradient: {
                            '0%, 100%': { backgroundPosition: '0% 50%' },
                            '50%': { backgroundPosition: '100% 50%' },
                        }
                    }
                }
            }
        }
    </script>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
        body { font-family: 'Inter', sans-serif; }
        .glass { -webkit-backdrop-filter: blur(12px); backdrop-filter: blur(12px); }
        .gradient-border { background: linear-gradient(135deg, #3b82f6, #8b5cf6, #ec4899); }
        .health-ring { transition: stroke-dashoffset 1s ease-in-out; }
        ::-webkit-scrollbar { width: 8px; height: 8px; }
        ::-webkit-scrollbar-track { background: #1e293b; }
        ::-webkit-scrollbar-thumb { background: #475569; border-radius: 4px; }
        ::-webkit-scrollbar-thumb:hover { background: #64748b; }
    </style>
</head>
<body class="bg-slate-950 text-slate-100 min-h-screen">
    <!-- Background Effects -->
    <div class="fixed inset-0 overflow-hidden pointer-events-none">
        <div class="absolute -top-40 -right-40 w-80 h-80 bg-blue-500/10 rounded-full blur-3xl"></div>
        <div class="absolute -bottom-40 -left-40 w-80 h-80 bg-purple-500/10 rounded-full blur-3xl"></div>
    </div>

    <div class="relative z-10 p-6 max-w-[1800px] mx-auto">
        <!-- Header -->
        <header class="mb-8">
            <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
                <div>
                    <div class="flex items-center gap-3 mb-2">
                        <div class="p-2 bg-gradient-to-br from-blue-500 to-purple-600 rounded-xl">
                            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                            </svg>
                        </div>
                        <h1 class="text-3xl font-bold bg-gradient-to-r from-blue-400 via-purple-400 to-pink-400 bg-clip-text text-transparent">
                            System Health Monitor
                        </h1>
                    </div>
                    <p class="text-slate-400">Surveillance en temps reel de l'infrastructure</p>
                </div>
                <div class="flex flex-wrap items-center gap-4 text-sm">
                    <div class="flex items-center gap-2 px-4 py-2 bg-slate-800/50 rounded-xl border border-slate-700/50">
                        <svg class="w-4 h-4 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2"/>
                        </svg>
                        <span class="text-slate-300 font-medium">$computerName</span>
                    </div>
                    <div class="flex items-center gap-2 px-4 py-2 bg-slate-800/50 rounded-xl border border-slate-700/50">
                        <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                        <span class="text-slate-300">Uptime: <span class="font-medium">$uptimeStr</span></span>
                    </div>
                    <div class="flex items-center gap-2 px-4 py-2 bg-slate-800/50 rounded-xl border border-slate-700/50">
                        <svg class="w-4 h-4 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                        <span class="text-slate-300">$timestamp</span>
                    </div>
                </div>
            </div>
        </header>

        <!-- Main Grid -->
        <div class="grid grid-cols-12 gap-6">
            <!-- Health Score Card -->
            <div class="col-span-12 lg:col-span-3">
                <div class="h-full p-6 bg-slate-900/50 glass rounded-2xl border border-slate-800/50">
                    <h3 class="text-sm font-medium text-slate-400 uppercase tracking-wider mb-4">Score de Sante</h3>
                    <div class="flex flex-col items-center">
                        <div class="relative w-48 h-48">
                            <svg class="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
                                <circle cx="50" cy="50" r="45" fill="none" stroke="#1e293b" stroke-width="8"/>
                                <circle cx="50" cy="50" r="45" fill="none"
                                    stroke="url(#healthGradient)"
                                    stroke-width="8"
                                    stroke-linecap="round"
                                    stroke-dasharray="283"
                                    stroke-dashoffset="$(283 - (283 * $healthScore / 100))"
                                    class="health-ring"/>
                                <defs>
                                    <linearGradient id="healthGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                                        $(if ($healthStatus -eq "healthy") { '<stop offset="0%" stop-color="#10b981"/><stop offset="100%" stop-color="#34d399"/>' }
                                          elseif ($healthStatus -eq "warning") { '<stop offset="0%" stop-color="#f59e0b"/><stop offset="100%" stop-color="#fbbf24"/>' }
                                          else { '<stop offset="0%" stop-color="#ef4444"/><stop offset="100%" stop-color="#f87171"/>' })
                                    </linearGradient>
                                </defs>
                            </svg>
                            <div class="absolute inset-0 flex flex-col items-center justify-center">
                                <span class="text-5xl font-bold text-white">$healthScore</span>
                                <span class="text-slate-400 text-sm">/ 100</span>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center gap-2">
                            <span class="w-3 h-3 rounded-full $(if ($healthStatus -eq 'healthy') { 'bg-emerald-500' } elseif ($healthStatus -eq 'warning') { 'bg-amber-500' } else { 'bg-red-500' }) animate-pulse"></span>
                            <span class="font-medium $(if ($healthStatus -eq 'healthy') { 'text-emerald-400' } elseif ($healthStatus -eq 'warning') { 'text-amber-400' } else { 'text-red-400' })">
                                $(if ($healthStatus -eq 'healthy') { 'Systeme Operationnel' } elseif ($healthStatus -eq 'warning') { 'Attention Requise' } else { 'Intervention Critique' })
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Status Cards -->
            <div class="col-span-12 lg:col-span-9">
                <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    <!-- Total Checks -->
                    <div class="p-5 bg-slate-900/50 glass rounded-2xl border border-slate-800/50 hover:border-blue-500/50 transition-all duration-300">
                        <div class="flex items-center justify-between mb-3">
                            <span class="text-slate-400 text-sm">Total Checks</span>
                            <div class="p-2 bg-blue-500/20 rounded-lg">
                                <svg class="w-5 h-5 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                                </svg>
                            </div>
                        </div>
                        <p class="text-3xl font-bold text-white">$totalCount</p>
                        <p class="text-xs text-slate-500 mt-1">Verifications actives</p>
                    </div>

                    <!-- OK Status -->
                    <div class="p-5 bg-slate-900/50 glass rounded-2xl border border-slate-800/50 hover:border-emerald-500/50 transition-all duration-300">
                        <div class="flex items-center justify-between mb-3">
                            <span class="text-slate-400 text-sm">OK</span>
                            <div class="p-2 bg-emerald-500/20 rounded-lg">
                                <svg class="w-5 h-5 text-emerald-400" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                                </svg>
                            </div>
                        </div>
                        <p class="text-3xl font-bold text-emerald-400">$okCount</p>
                        <div class="mt-2 h-1.5 bg-slate-700 rounded-full overflow-hidden">
                            <div class="h-full bg-emerald-500 rounded-full" style="width: $(if ($totalCount -gt 0) { [math]::Round(($okCount / $totalCount) * 100) } else { 0 })%"></div>
                        </div>
                    </div>

                    <!-- Warning Status -->
                    <div class="p-5 bg-slate-900/50 glass rounded-2xl border border-slate-800/50 hover:border-amber-500/50 transition-all duration-300">
                        <div class="flex items-center justify-between mb-3">
                            <span class="text-slate-400 text-sm">Warning</span>
                            <div class="p-2 bg-amber-500/20 rounded-lg">
                                <svg class="w-5 h-5 text-amber-400" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
                                </svg>
                            </div>
                        </div>
                        <p class="text-3xl font-bold text-amber-400">$warningCount</p>
                        <div class="mt-2 h-1.5 bg-slate-700 rounded-full overflow-hidden">
                            <div class="h-full bg-amber-500 rounded-full" style="width: $(if ($totalCount -gt 0) { [math]::Round(($warningCount / $totalCount) * 100) } else { 0 })%"></div>
                        </div>
                    </div>

                    <!-- Critical Status -->
                    <div class="p-5 bg-slate-900/50 glass rounded-2xl border border-slate-800/50 hover:border-red-500/50 transition-all duration-300">
                        <div class="flex items-center justify-between mb-3">
                            <span class="text-slate-400 text-sm">Critical</span>
                            <div class="p-2 bg-red-500/20 rounded-lg">
                                <svg class="w-5 h-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
                                </svg>
                            </div>
                        </div>
                        <p class="text-3xl font-bold text-red-400">$criticalCount</p>
                        <div class="mt-2 h-1.5 bg-slate-700 rounded-full overflow-hidden">
                            <div class="h-full bg-red-500 rounded-full" style="width: $(if ($totalCount -gt 0) { [math]::Round(($criticalCount / $totalCount) * 100) } else { 0 })%"></div>
                        </div>
                    </div>
                </div>

                <!-- CPU & Memory Gauges -->
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mt-4">
                    <!-- CPU -->
                    <div class="p-5 bg-slate-900/50 glass rounded-2xl border border-slate-800/50">
                        <div class="flex items-center justify-between mb-4">
                            <div class="flex items-center gap-3">
                                <div class="p-2 bg-cyan-500/20 rounded-lg">
                                    <svg class="w-5 h-5 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/>
                                    </svg>
                                </div>
                                <div>
                                    <h4 class="font-semibold text-white">CPU</h4>
                                    <p class="text-xs text-slate-400">Utilisation processeur</p>
                                </div>
                            </div>
                            <span class="text-2xl font-bold $(if ($cpuValue -gt $cpuThreshold) { 'text-red-400' } elseif ($cpuValue -gt $cpuThreshold * 0.8) { 'text-amber-400' } else { 'text-cyan-400' })">$cpuValue%</span>
                        </div>
                        <div class="h-3 bg-slate-700 rounded-full overflow-hidden">
                            <div class="h-full rounded-full transition-all duration-500 $(if ($cpuValue -gt $cpuThreshold) { 'bg-gradient-to-r from-red-500 to-red-400' } elseif ($cpuValue -gt $cpuThreshold * 0.8) { 'bg-gradient-to-r from-amber-500 to-amber-400' } else { 'bg-gradient-to-r from-cyan-500 to-cyan-400' })" style="width: $cpuValue%"></div>
                        </div>
                        <p class="text-xs text-slate-500 mt-2">Seuil d'alerte: $cpuThreshold%</p>
                    </div>

                    <!-- Memory -->
                    <div class="p-5 bg-slate-900/50 glass rounded-2xl border border-slate-800/50">
                        <div class="flex items-center justify-between mb-4">
                            <div class="flex items-center gap-3">
                                <div class="p-2 bg-violet-500/20 rounded-lg">
                                    <svg class="w-5 h-5 text-violet-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                                    </svg>
                                </div>
                                <div>
                                    <h4 class="font-semibold text-white">Memoire RAM</h4>
                                    <p class="text-xs text-slate-400">$memoryValue MB disponible / $memoryTotal MB</p>
                                </div>
                            </div>
                            <span class="text-2xl font-bold $(if ($memoryValue -lt $memoryThreshold) { 'text-red-400' } else { 'text-violet-400' })">$memoryPercent%</span>
                        </div>
                        <div class="h-3 bg-slate-700 rounded-full overflow-hidden">
                            <div class="h-full bg-gradient-to-r from-violet-500 to-violet-400 rounded-full transition-all duration-500" style="width: $memoryPercent%"></div>
                        </div>
                        <p class="text-xs text-slate-500 mt-2">Seuil minimum disponible: $memoryThreshold MB</p>
                    </div>
                </div>
            </div>

            <!-- Services -->
            <div class="col-span-12 lg:col-span-4">
                <div class="h-full p-6 bg-slate-900/50 glass rounded-2xl border border-slate-800/50">
                    <div class="flex items-center justify-between mb-4">
                        <h3 class="text-lg font-semibold text-white">Services Windows</h3>
                        <span class="px-3 py-1 text-xs font-medium bg-slate-700 text-slate-300 rounded-full">
                            $($serviceAlerts.Count) services
                        </span>
                    </div>
                    <div class="space-y-3 max-h-80 overflow-y-auto pr-2">
                        $servicesHtml
                    </div>
                </div>
            </div>

            <!-- Disk Usage -->
            <div class="col-span-12 lg:col-span-4">
                <div class="h-full p-6 bg-slate-900/50 glass rounded-2xl border border-slate-800/50">
                    <div class="flex items-center justify-between mb-4">
                        <h3 class="text-lg font-semibold text-white">Espace Disque</h3>
                        <span class="px-3 py-1 text-xs font-medium bg-slate-700 text-slate-300 rounded-full">
                            $($diskAlerts.Count) volumes
                        </span>
                    </div>
                    <div class="space-y-4">
                        $disksHtml
                    </div>
                </div>
            </div>

            <!-- Disk Chart -->
            <div class="col-span-12 lg:col-span-4">
                <div class="h-full p-6 bg-slate-900/50 glass rounded-2xl border border-slate-800/50">
                    <h3 class="text-lg font-semibold text-white mb-4">Repartition Disques</h3>
                    <div class="h-64">
                        <canvas id="diskChart"></canvas>
                    </div>
                </div>
            </div>

            <!-- History Chart -->
            <div class="col-span-12">
                <div class="p-6 bg-slate-900/50 glass rounded-2xl border border-slate-800/50">
                    <div class="flex items-center justify-between mb-4">
                        <h3 class="text-lg font-semibold text-white">Historique des Metriques</h3>
                        <div class="flex items-center gap-4 text-sm">
                            <span class="flex items-center gap-2">
                                <span class="w-3 h-3 rounded-full bg-cyan-500"></span>
                                <span class="text-slate-400">CPU</span>
                            </span>
                            <span class="flex items-center gap-2">
                                <span class="w-3 h-3 rounded-full bg-violet-500"></span>
                                <span class="text-slate-400">RAM</span>
                            </span>
                            <span class="flex items-center gap-2">
                                <span class="w-3 h-3 rounded-full bg-emerald-500"></span>
                                <span class="text-slate-400">Sante</span>
                            </span>
                        </div>
                    </div>
                    <div class="h-72">
                        <canvas id="historyChart"></canvas>
                    </div>
                </div>
            </div>
        </div>

        <!-- Footer -->
        <footer class="mt-8 text-center text-slate-500 text-sm">
            <p>System Health Monitor v2.0.0 | Dashboard auto-genere toutes les 5 minutes</p>
            <p class="mt-1">$osInfo</p>
        </footer>
    </div>

    <script>
        // Configuration globale Chart.js
        Chart.defaults.color = '#94a3b8';
        Chart.defaults.borderColor = 'rgba(51, 65, 85, 0.5)';
        Chart.defaults.font.family = 'Inter, sans-serif';

        // Graphique Historique
        const historyCtx = document.getElementById('historyChart').getContext('2d');
        const historyGradientCpu = historyCtx.createLinearGradient(0, 0, 0, 300);
        historyGradientCpu.addColorStop(0, 'rgba(6, 182, 212, 0.3)');
        historyGradientCpu.addColorStop(1, 'rgba(6, 182, 212, 0)');

        const historyGradientMem = historyCtx.createLinearGradient(0, 0, 0, 300);
        historyGradientMem.addColorStop(0, 'rgba(139, 92, 246, 0.3)');
        historyGradientMem.addColorStop(1, 'rgba(139, 92, 246, 0)');

        new Chart(historyCtx, {
            type: 'line',
            data: {
                labels: [$historyLabels],
                datasets: [
                    {
                        label: 'CPU %',
                        data: [$historyCpu],
                        borderColor: '#06b6d4',
                        backgroundColor: historyGradientCpu,
                        fill: true,
                        tension: 0.4,
                        pointRadius: 0,
                        pointHoverRadius: 6,
                        pointHoverBackgroundColor: '#06b6d4',
                        borderWidth: 2
                    },
                    {
                        label: 'RAM %',
                        data: [$historyMem],
                        borderColor: '#8b5cf6',
                        backgroundColor: historyGradientMem,
                        fill: true,
                        tension: 0.4,
                        pointRadius: 0,
                        pointHoverRadius: 6,
                        pointHoverBackgroundColor: '#8b5cf6',
                        borderWidth: 2
                    },
                    {
                        label: 'Sante %',
                        data: [$historyHealth],
                        borderColor: '#10b981',
                        backgroundColor: 'transparent',
                        fill: false,
                        tension: 0.4,
                        pointRadius: 0,
                        pointHoverRadius: 6,
                        pointHoverBackgroundColor: '#10b981',
                        borderWidth: 2,
                        borderDash: [5, 5]
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: { intersect: false, mode: 'index' },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: 'rgba(15, 23, 42, 0.9)',
                        titleColor: '#f8fafc',
                        bodyColor: '#cbd5e1',
                        borderColor: 'rgba(51, 65, 85, 0.5)',
                        borderWidth: 1,
                        padding: 12,
                        cornerRadius: 8,
                        displayColors: true,
                        boxPadding: 4
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        grid: { color: 'rgba(51, 65, 85, 0.3)', drawBorder: false },
                        ticks: { padding: 10 }
                    },
                    x: {
                        grid: { display: false },
                        ticks: { padding: 10, maxRotation: 0 }
                    }
                }
            }
        });

        // Graphique Disques
        const diskCtx = document.getElementById('diskChart').getContext('2d');
        new Chart(diskCtx, {
            type: 'doughnut',
            data: {
                labels: [$diskLabelsStr],
                datasets: [{
                    data: [$diskUsedStr],
                    backgroundColor: [
                        'rgba(6, 182, 212, 0.8)',
                        'rgba(139, 92, 246, 0.8)',
                        'rgba(16, 185, 129, 0.8)',
                        'rgba(245, 158, 11, 0.8)',
                        'rgba(239, 68, 68, 0.8)'
                    ],
                    borderColor: '#0f172a',
                    borderWidth: 3,
                    hoverOffset: 10
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '65%',
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            padding: 20,
                            usePointStyle: true,
                            pointStyle: 'circle'
                        }
                    },
                    tooltip: {
                        backgroundColor: 'rgba(15, 23, 42, 0.9)',
                        titleColor: '#f8fafc',
                        bodyColor: '#cbd5e1',
                        borderColor: 'rgba(51, 65, 85, 0.5)',
                        borderWidth: 1,
                        padding: 12,
                        cornerRadius: 8,
                        callbacks: {
                            label: function(context) {
                                return context.label + ': ' + context.raw + '% utilise';
                            }
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
"@

        # Ecriture du fichier HTML
        $htmlContent | Set-Content -Path $dashboardPath -Encoding UTF8

        Write-Verbose "Dashboard genere: $dashboardPath"
        return $dashboardPath
    }
    catch {
        Write-Error "Erreur lors de la generation du dashboard: $_"
        throw
    }
}
