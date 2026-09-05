# NeoTech Toolkit

Boîte à outils d'administration et de diagnostic Windows, portable, signée Authenticode, sans dépendance externe.

Auteur : **Neo Soda** — [TechSentinel.fr](https://techsentinel.fr)
Copyright : (c) 2026 TechSentinel — Tous droits réservés.
Version : **1.0.0**

---

## Sommaire

1. [Pourquoi ce toolkit](#pourquoi-ce-toolkit)
2. [Fonctionnalités](#fonctionnalités)
3. [Installation / premier lancement](#installation--premier-lancement)
4. [Utilisation](#utilisation)
5. [Mode CLI / automatisation](#mode-cli--automatisation)
6. [Architecture](#architecture)
7. [Confiance Windows et antivirus](#confiance-windows-et-antivirus)
8. [Logs et diagnostic](#logs-et-diagnostic)
9. [Limitations connues](#limitations-connues)

---

## Pourquoi ce toolkit

- **Portable** : un seul dossier, copiable sur clé USB.
- **Fiable** : gestion d'erreurs par fonction, logs persistants avec rotation, pas d'`Invoke-Expression` caché.
- **Légitime** : scripts signés Authenticode, certificat importé dans le magasin de confiance Windows, métadonnées de version, pas de pattern `findstr|pipe-powershell` qui déclenche AMSI.
- **Lisible** : modules PowerShell bien découpés, un module = une responsabilité, comment-based-help.
- **Pas de dépendance externe** : aucun `Install-Module` requis, fonctionne hors-ligne.

---

## Fonctionnalités

### Audit matériel
- Synthèse machine et OS
- Inventaire CPU, RAM (avec type DDR), carte mère, GPU
- Inventaire des pilotes (tous + détection des pilotes anciens)
- Stockage : volumes, disques physiques, SMART (Storage Reliability Counter)
- Batterie (laptop) + rapport energy-report

### Réseau
- Audit complet : interfaces, IP v4/v6, DNS, passerelle, DHCP
- Connectivité (1.1.1.1, 8.8.8.8, google.com, microsoft.com, github.com)
- Profils Wi-Fi enregistrés
- Cache ARP
- Ports en écoute (avec processus propriétaire)
- Réparation : flush DNS, renouvellement DHCP, reset Winsock
- Reset complet pile réseau (avec confirmation)

### Sécurité
- TPM (présence, version, propriétaire)
- Secure Boot
- BitLocker (état par volume)
- Windows Defender (signatures, mode temps réel, tamper protection)
- Pare-feu (par profil)
- UAC (lecture registre des stratégies)
- Comptes locaux + membres du groupe Administrateurs
- Résultat de stratégie de groupe (gpresult)

### Logiciels
- Liste des logiciels installés (32/64 bits, user + machine)
- Windows Update (historique, en attente)
- Démarrage : registres Run + dossiers Startup + tâches planifiées
- Tâches planifiées (toutes sources, prochaine exécution)
- Services Windows (résumé + services Auto arrêtés)
- Processus (top CPU, top RAM, compteurs globaux)
- Observateur d'événements (erreurs System/Application 24h)
- Snapshot performance (CPU/RAM sur N secondes)

### Réparation
- Health check rapide (SFC verifyonly + espace disque)
- SFC /scannow
- DISM CheckHealth / ScanHealth / RestoreHealth
- Reset Windows Update (services + renommage SoftwareDistribution / catroot2)
- Nettoyage fichiers temporaires (utilisateur + Windows)

### Outils admin (lanceurs)
- Gestionnaire de périphériques, Connexions réseau, Gestion de l'ordinateur
- Observateur d'événements, Éditeur du registre, Services MMC
- Invite de commandes admin, Planificateur de tâches

### Rapport
- Export complet **TXT** (lisibilité brute)
- Export complet **HTML** (présentation propre, prêt à partager)
- Sur le bureau, horodaté par nom de machine

---

## Installation / premier lancement

### Sur une nouvelle machine

1. **Copier** le dossier `NeoTechToolkit\` où vous voulez (clé USB, `C:\Tools\`, bureau, etc.).
2. **Signer** les scripts (génère le certificat auto-signé) :
   ```powershell
   cd C:\chemin\vers\NeoTechToolkit\Tools
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Sign-NeoTech.ps1
   ```
3. **Importer** le certificat comme éditeur de confiance (UAC) :
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-TrustedPublisher.ps1
   ```
4. **Lancer** :
   - Double-clic sur `NeoTech Toolkit.bat`, **ou**
   - PowerShell : `.\NeoTech-Toolkit.ps1`

> **Important** : l'étape 3 doit être répétée sur chaque machine où vous voulez
> que Windows fasse confiance au toolkit sans alerte. Sinon, le .ps1 est bien
> signé mais Windows affiche "Éditeur inconnu" au premier lancement.

---

## Utilisation

### Menu interactif

Lancer `NeoTech Toolkit.bat` (ou `NeoTech-Toolkit.ps1` directement) ouvre le menu
numéroté. Tapez le numéro de la section et `Entrée`.

Sections principales :

- `[1–5]`  Audit matériel
- `[6–9]`  Réseau
- `[11–13]` Sécurité
- `[14–23]` Logiciels, démarrage, performances
- `[30–34]` Réparation système
- `[40–47]` Outils administrateur (MMC/CPL)
- `[R]`     Export rapport complet
- `[I]`     À propos
- `[Q]`     Quitter

### Raccourcis utiles

| Touche | Action |
|--------|--------|
| `R`    | Exporte rapport TXT + HTML sur le bureau |
| `I`    | Affiche la version, l'emplacement du log, l'état admin |
| `Q`    | Quitter proprement (log écrit) |

---

## Mode CLI / automatisation

Le script supporte l'exécution non-interactive :

```powershell
# Rapport complet (TXT + HTML sur le bureau) sans menu
.\NeoTech-Toolkit.ps1 -ReportOnly

# Sections spécifiques
.\NeoTech-Toolkit.ps1 -ReportOnly -Sections Overview,Hardware,Network

# Mode headless : pas d'attente clavier (utile dans un script)
.\NeoTech-Toolkit.ps1 -ReportOnly -Headless
```

Utile pour :
- Tâche planifiée hebdomadaire qui dépose un rapport HTML sur un partage réseau
- Diagnostic distant via WinRM / SSH PowerShell
- Intégration dans un RMM (NinjaOne, TacticalRMM, etc.)

---

## Architecture

```
NeoTechToolkit\
├── NeoTech Toolkit.bat              # Lanceur Windows (shim)
├── NeoTech-Toolkit.ps1              # Point d'entree, menu principal
├── README.md
├── Modules\
│   ├── NTCommon.psm1                # Logging, formatting, elevation, errors
│   ├── NTAudit.psm1                 # OS, hardware, drivers
│   ├── NTNetwork.psm1               # Reseau audit + reparation
│   ├── NTStorage.psm1               # Volumes, disques, SMART, temp
│   ├── NTSecurity.psm1              # TPM, BitLocker, Defender, UAC, GPO
│   ├── NTPower.psm1                 # Batterie, plans d'alimentation
│   ├── NTStartup.psm1               # Run, Startup, taches planifiees
│   ├── NTPerformance.psm1           # Processus, services, events, perf
│   ├── NTRepair.psm1                # SFC, DISM, reset WU, sante
│   └── NTReport.psm1                # Generation TXT + HTML
├── Tools\
│   ├── Sign-NeoTech.ps1             # Genere cert + signe scripts
│   ├── Install-TrustedPublisher.ps1 # Import cert en TrustedPeople
│   └── NeoTech-Toolkit.cer          # Cert exporte (apres signature)
├── Logs\                            # Logs rotatifs (2 MB max)
└── Reports\                         # Rapports (si generes via mode CLI)
```

Conventions :
- Préfixe `NT` partout (NeoTech) → collision impossible avec les cmdlets Microsoft.
- Préfixe `Get-`/`Set-`/`Repair-`/`Reset-`/`Clear-`/`Open-`/`Show-`/`Wait-`/`Read-`/`Request-`/`Assert-`/`Test-`/`Format-`/`Write-`/`Invoke-`/`New-`/`Export-`/`Import-`.
- Comment-based help (`<# .SYNOPSIS ... #>`) sur chaque fonction exportée.
- `Set-StrictMode -Version Latest` et `$ErrorActionPreference = 'Stop'` au démarrage.

---

## Confiance Windows et antivirus

### Pourquoi le `.bat` hybride d'origine se faisait flagguer

L'ancien `NeoTech Toolkit.bat` utilisait le pattern :
```bat
@findstr /v "^@findstr" "%~f0" | powershell.exe -NoProfile -ExecutionPolicy Bypass -Command -
```

C'est **exactement** la technique d'obfuscation de malware. AMSI et Defender
la détectent, à raison.

### Ce que fait la nouvelle version

1. **Fichiers .ps1 / .psm1 séparés** (pas de payload inline) — structure normale d'un outil IT.
2. **Pas de `-ExecutionPolicy Bypass` au lancement** — on utilise `RemoteSigned` (le script étant signé, il est exécuté sans warning).
3. **Pas de `Invoke-Expression`**, pas de chaînes encodées en Base64, pas de download cradles.
4. **Signature Authenticode** via `Tools\Sign-NeoTech.ps1` :
   - Certificat auto-signé RSA 2048 / SHA256, 5 ans
   - Timestamp DigiCert (la signature reste valide même après expiration du cert)
   - Tous les `.ps1` et `.psm1` sont signés
5. **Import du cert dans `Cert:\LocalMachine\TrustedPeople`** via `Tools\Install-TrustedPublisher.ps1` :
   - Après ça, Windows reconnaît le toolkit comme **éditeur de confiance**
   - SmartScreen ne crie plus
   - AMSI ne fait pas d'exception spéciale mais le code étant sain et signé, pas d'alerte

### Ce que cette méthode ne fait PAS

- **Pas de certificat EV** : la "réputation SmartScreen" n'est pas atteinte.
  - Conséquence : la première exécution sur une machine **avant** l'import du
    cert peut afficher un bandeau bleu « Windows a protégé votre ordinateur ».
  - L'utilisateur clique « Informations complémentaires → Exécuter quand même »,
    ou il lance `Install-TrustedPublisher.ps1` une fois et c'est terminé.

- **Pas de soumission à Microsoft** : on n'a pas demandé à MS d'analyser le
  binaire pour le whitelister. Si tu veux le faire, sors un `.exe` (ps2exe)
  signé et soumets-le via le portail Microsoft MAPP.

---

## Logs et diagnostic

Tout est tracé dans `Logs\NeoTech_<COMPUTERNAME>.log` (UTF-8, rotation à 2 MB).

Format :
```
[2026-09-05 10:54:32.123] [Info] [Main] Demarrage NeoTech Toolkit (admin OK)
[2026-09-05 10:54:35.456] [Error] [Network] ECHEC : Test 1.1.1.1 - timeout
```

Pour partager un diagnostic, envoie ce fichier `.log` (pas la stack trace
PowerShell dans la console — le log est la source de vérité).

---

## Limitations connues

- **SFC et DISM** demandent du temps (5 à 30 min). Le script attend la fin, ne
  pas l'interrompre. Le log CBS détaillé est dans `%WINDIR%\Logs\CBS\CBS.log`.
- **Reset Windows Update** arrête 4 services et renomme 2 dossiers. Un
  redémarrage est nécessaire ensuite.
- **Batterie** : `Get-CimInstance Win32_Battery` ne retourne rien sur certains
  modèles (rare, firmware exotique). Le rapport `powercfg /batteryreport`
  reste le fallback universel.
- **Windows Update COM** : si le service WUA est désactivé, la section Update
  échoue proprement avec un message clair (pas de crash).
- **Caractères accentués** : tous les fichiers sont en UTF-8 avec BOM pour
  une compatibilité maximale entre PowerShell 5.1 et 7+.

---

## Licence

MIT / Usage interne TechSentinel.
Toute redistribution doit conserver les métadonnées d'auteur et de copyright.

---

**TechSentinel.fr** — *L'informatique qui marche, pas celle qui parle.*
