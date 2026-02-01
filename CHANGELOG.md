# Changelog

Toutes les modifications notables de ce projet sont documentees ici.

Le format est base sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhere au [Semantic Versioning](https://semver.org/lang/fr/).

## [2.0.0] - 2026-02-01

### Ajoute
- Dashboard HTML interactif avec Tailwind CSS et Chart.js
- Score de sante global avec jauge animee
- Graphiques historiques des metriques (CPU, RAM, Sante)
- Graphique donut pour l'espace disque
- Historique des metriques sur 48 points
- Auto-refresh du dashboard toutes les 5 minutes
- Fichier de configuration exemple
- Script d'installation automatique
- Changelog et licence MIT

### Modifie
- Compatibilite PowerShell 5.1 (suppression de -AdditionalChildPath)
- Design responsive pour mobile et desktop
- Support Safari (prefixes webkit)

## [1.0.0] - 2026-01-31

### Ajoute
- Surveillance des services Windows
- Metriques systeme (CPU, RAM, Disque)
- Systeme d'alertes avec niveaux (OK, WARNING, CRITICAL)
- Logging journalier horodate
- Export des rapports au format CSV
- Configuration JSON flexible
- Mode surveillance continue (-Continuous)
- Documentation README complete
