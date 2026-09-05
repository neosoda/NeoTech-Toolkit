# =============================================================================
# Script      : NeoTech-Toolkit.ps1
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Site        : https://techsentinel.fr
# Version     : 1.0.0
# Description : Boite a outils tout-en-un pour diagnostic, audit et reparation
#               Windows (materiel, reseau, securite, performances, drivers, etc.)
#               Auto-elevant, journalise, signable, portable.
# =============================================================================

#requires -Version 5.1

[CmdletBinding()]
param(
    # Mode CLI : aucune interaction, genere directement un rapport
    [switch]$ReportOnly,
    # Mode headless : pas d'attente clavier entre sections
    [switch]$Headless,
    # Sections specifiques (CSV)
    [string[]]$Sections = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Trap global : affiche toute erreur et la journalise avant de quitter
#     (evite la fermeture silencieuse de la fenetre)
$ErrorActionPreference = 'Stop'
trap {
    $errMsg = $_.Exception.Message
    $errLine = $_.InvocationInfo.PositionMessage
    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor Red
    Write-Host '   ERREUR NON GEREE DANS NEOTECH TOOLKIT' -ForegroundColor Red
    Write-Host '  ============================================================' -ForegroundColor Red
    Write-Host "  Message : $errMsg" -ForegroundColor White
    Write-Host "  Emplacement : $errLine" -ForegroundColor DarkGray
    Write-Host ''
    # Log si possible
    try {
        $logDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Logs'
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $logFile = Join-Path $logDir "NeoTech_$($env:COMPUTERNAME).log"
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -Path $logFile -Value "[$stamp] [FATAL] $errMsg @ $errLine" -Encoding UTF8
        Write-Host "  Trace ecrite dans : $logFile" -ForegroundColor DarkGray
    } catch { }
    Write-Host ''
    Write-Host '  Appuyez sur Entree pour fermer cette fenetre...' -ForegroundColor DarkGray
    try { Read-Host | Out-Null } catch { Start-Sleep -Seconds 30 }
    exit 1
}

# --- Determinons le repertoire de base (portable : on suit l'emplacement du script)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModuleDir = Join-Path $ScriptDir 'Modules'
$LogDir    = Join-Path $ScriptDir 'Logs'
$ReportDir = Join-Path $ScriptDir 'Reports'

# Verif rapide que le dossier modules existe
if (-not (Test-Path $ModuleDir)) {
    Write-Host ''
    Write-Host "  ERREUR : dossier Modules introuvable : $ModuleDir" -ForegroundColor Red
    Write-Host "  Le script doit etre lance depuis son propre dossier." -ForegroundColor Yellow
    Write-Host "  Ouvrez une invite de commande dans le dossier NeoTechToolkit et lancez :" -ForegroundColor Yellow
    Write-Host "    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\NeoTech-Toolkit.ps1" -ForegroundColor Cyan
    Write-Host ''
    Read-Host '  Appuyez sur Entree pour fermer'
    exit 1
}

# --- Chargement des modules
$modules = @(
    'NTCommon',
    'NTAudit',
    'NTNetwork',
    'NTStorage',
    'NTSecurity',
    'NTPower',
    'NTStartup',
    'NTPerformance',
    'NTRepair',
    'NTReport'
)
foreach ($m in $modules) {
    $path = Join-Path $ModuleDir "$m.psm1"
    if (-not (Test-Path $path)) {
        Write-Host ''
        Write-Host "  ERREUR : module introuvable : $path" -ForegroundColor Red
        Write-Host "  Verifiez que le dossier Modules est present a cote du script." -ForegroundColor Yellow
        Read-Host '  Entree pour quitter'
        exit 1
    }
    try {
        Import-Module $path -Force -DisableNameChecking -ErrorAction Stop
    } catch {
        Write-Host ''
        Write-Host "  ERREUR import $m.psm1" -ForegroundColor Red
        Write-Host "  Details : $_" -ForegroundColor DarkGray
        Read-Host '  Entree pour quitter'
        exit 1
    }
}

# --- Verification Windows (apres import des modules)
Assert-NTWindows

# --- Auto-elevation : si pas admin, on relance en UAC
if (-not (Test-NTAdmin)) {
    Write-Host ''
    Write-Host '  NeoTech Toolkit necessite les droits administrateur.' -ForegroundColor Yellow
    Write-Host '  Une invite UAC va apparaitre...' -ForegroundColor Yellow
    Write-Host ''

    # Determiner le chemin de powershell.exe utilise pour ce process
    $psPath = (Get-Process -Id $PID -ErrorAction SilentlyContinue).Path
    if (-not $psPath) { $psPath = 'powershell.exe' }

    # Construction securisee des arguments (chemin quoté pour gérer les espaces)
    $quotedScript = '"' + (Join-Path $ScriptDir 'NeoTech-Toolkit.ps1') + '"'
    $argList = @('-NoProfile','-ExecutionPolicy','RemoteSigned','-File', $quotedScript)
    if ($ReportOnly) { $argList += '-ReportOnly' }
    if ($Headless)   { $argList += '-Headless' }
    foreach ($s in $Sections) { $argList += '-Sections'; $argList += $s }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName         = $psPath
    $psi.Arguments        = ($argList -join ' ')
    $psi.UseShellExecute  = $true
    $psi.Verb             = 'runas'
    $psi.WorkingDirectory = $ScriptDir

    try {
        $proc = [Diagnostics.Process]::Start($psi)
        Write-Host "  Processus élevé lancé (PID $($proc.Id)). Cette fenêtre va se fermer." -ForegroundColor DarkGray
        Start-Sleep -Seconds 2
    } catch {
        # L'utilisateur a peut-etre refusé UAC, ou UAC est désactivé
        Write-Host ''
        Write-Host "  Echec elevation : $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ''
        Write-Host "  Solutions :" -ForegroundColor Yellow
        Write-Host "    1) Accepter l'invite UAC quand elle apparait" -ForegroundColor White
        Write-Host "    2) Lancer directement depuis un PowerShell Administrateur :" -ForegroundColor White
        Write-Host "       $psPath -NoProfile -ExecutionPolicy RemoteSigned -File $quotedScript" -ForegroundColor Cyan
        Write-Host ''
        Write-Host "  Appuyez sur Entree pour fermer cette fenêtre..." -ForegroundColor DarkGray
        try { Read-Host | Out-Null } catch { Start-Sleep -Seconds 30 }
    }
    exit
}

# --- On est admin : init
Write-NTLog -Message "Demarrage NeoTech Toolkit (admin OK)" -Level Info -Component 'Main'

# Imposer taille et titre de fenetre tout de suite
Set-NTWindowSize -Width 130 -Height 42
Set-NTWindowTitle -Title "NeoTech Toolkit v$NTVersion - [Admin] $env:COMPUTERNAME"

# --- Mode CLI : rapport direct
if ($ReportOnly) {
    $sections = if ($Sections.Count -gt 0) { $Sections } else {
        @('Overview','Hardware','Storage','Network','Security','Software','Drivers','Startup','Services','Events')
    }
    $params = @{ IncludeSections = $sections }
    Export-NTReport @params
    exit 0
}

# --- Menu principal (hierarchique : 7 categories, navigation par sous-menus)
function Show-NTMainMenu {
    if (Get-NTInteractive) { Clear-Host }
    Write-NTTitle
    Write-NTStatusBar

    $W = 100
    $sep = [string]::new([char]0x2500, $W)

    Write-Host '   AUDIT ET DIAGNOSTIC' -ForegroundColor Yellow
    Write-Host ''
    Write-NTMenuItem -Key '1' -Label 'Audit materiel'        -Hint 'CPU, RAM, stockage, pilotes'
    Write-NTMenuItem -Key '2' -Label 'Reseau'                -Hint 'Audit, reparation, ports en ecoute'
    Write-NTMenuItem -Key '3' -Label 'Securite'              -Hint 'TPM, Defender, BitLocker, UAC, comptes'
    Write-Host ''
    Write-Host '   MAINTENANCE ET DEPANNAGE' -ForegroundColor Yellow
    Write-Host ''
    Write-NTMenuItem -Key '4' -Label 'Logiciels'             -Hint 'Installes, Windows Update, demarrage, taches'
    Write-NTMenuItem -Key '5' -Label 'Reparation systeme'    -Hint 'SFC, DISM, reset WU, nettoyage temp'
    Write-Host ''
    Write-Host '   OUTILS' -ForegroundColor Yellow
    Write-Host ''
    Write-NTMenuItem -Key '6' -Label 'Outils admin (MMC/CPL)' -Hint 'Periph., connexions, registre, services...'
    Write-NTMenuItem -Key '7' -Label 'Rapport complet'        -Hint 'Export TXT + HTML sur le bureau' -Highlight
    Write-Host ''
    Write-Host $sep -ForegroundColor DarkCyan
    Write-NTMenuItem -Key 'I' -Label 'Informations / Logs'
    Write-NTMenuItem -Key 'Q' -Label 'Quitter'
    Write-Host $sep -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host '   > ' -NoNewline -ForegroundColor Magenta
}

# --- Sous-menu : AUDIT MATERIEL
function Show-NTMenu-AuditMateriel {
    Show-NTSubMenu -Title 'AUDIT MATERIEL' -Options @(
        @{ Key = '1'; Label = 'Synthese machine et OS';        Action = { Get-NTOverview } }
        @{ Key = '2'; Label = 'CPU / RAM / Carte mere / GPU';  Action = { Get-NTHardwareSpecs } }
        @{ Key = '3'; Label = 'Pilotes (inventaire + ages)';   Action = { Get-NTDriverInventory } }
        @{ Key = '4'; Label = 'Stockage (volumes + SMART)';    Action = { Get-NTStorageReport } }
        @{ Key = '5'; Label = 'Espace disque (vue rapide)';    Action = { Get-NTDiskSpace } }
    )
}

# --- Sous-menu : RESEAU
function Show-NTMenu-Reseau {
    Show-NTSubMenu -Title 'RESEAU' -Options @(
        @{ Key = '1'; Label = 'Audit reseau complet';           Action = { Get-NTNetworkSummary } }
        @{ Key = '2'; Label = 'Reparation reseau (DNS/DHCP)';   Action = { Repair-NTNetwork } }
        @{ Key = '3'; Label = 'Reset complet pile reseau';      Action = { Reset-NTNetworkStack } }
        @{ Key = '4'; Label = 'Ports en ecoute';                Action = { Get-NTListeningPorts } }
    )
}

# --- Sous-menu : SECURITE
function Show-NTMenu-Securite {
    Show-NTSubMenu -Title 'SECURITE ET POSTURE' -Options @(
        @{ Key = '1'; Label = 'Posture securite globale (TPM, Defender, BitLocker, UAC, Firewall)'; Action = { Get-NTSecurityStatus } }
        @{ Key = '2'; Label = 'Comptes locaux et admins';                                          Action = { Get-NTLocalUsers } }
        @{ Key = '3'; Label = 'Strategie de groupe (gpresult)';                                    Action = { Get-NTGroupPolicy } }
    )
}

# --- Sous-menu : LOGICIELS
function Show-NTMenu-Logiciels {
    Show-NTSubMenu -Title 'LOGICIELS ET MAINTENANCE' -Options @(
        @{ Key = '1';  Label = 'Logiciels installes';                Action = { Get-NTInstalledSoftware } }
        @{ Key = '2';  Label = 'Etat Windows Update';                Action = { Get-NTWindowsUpdateStatus } }
        @{ Key = '3';  Label = 'Batterie (laptop)';                  Action = { Get-NTBattery } }
        @{ Key = '4';  Label = "Plans d'alimentation";              Action = { Get-NTPowerPlan } }
        @{ Key = '5';  Label = 'Demarrage (startup items)';         Action = { Get-NTStartupItems } }
        @{ Key = '6';  Label = 'Taches planifiees';                 Action = { Get-NTScheduledTasks } }
        @{ Key = '7';  Label = 'Services Windows';                  Action = { Get-NTServiceStatus } }
        @{ Key = '8';  Label = 'Processus (top CPU/RAM)';           Action = { Get-NTProcessSnapshot } }
        @{ Key = '9';  Label = 'Evenements (erreurs 24h)';          Action = { Get-NTEventLog } }
        @{ Key = '10'; Label = 'Snapshot performance';              Action = { Get-NTPerformanceSnapshot -DurationSec 5 } }
    )
}

# --- Sous-menu : REPARATION
function Show-NTMenu-Reparation {
    Show-NTSubMenu -Title 'REPARATION SYSTEME' -Options @(
        @{ Key = '1'; Label = 'Health check rapide (SFC + espace disque)'; Action = { Get-NTSystemHealth } }
        @{ Key = '2'; Label = 'SFC /scannow (fichiers systeme)';           Action = { Repair-NTSystemFiles } }
        @{ Key = '3'; Label = 'DISM (composant image)';                    Action = { Repair-NTComponentStore } }
        @{ Key = '4'; Label = 'Reset Windows Update';                       Action = { Reset-NTWindowsUpdate } }
        @{ Key = '5'; Label = 'Nettoyer fichiers temporaires';             Action = { Clear-NTTempFiles } }
    )
}

# --- Sous-menu : OUTILS ADMIN
function Show-NTMenu-OutilsAdmin {
    Show-NTSubMenu -Title 'OUTILS ADMIN (MMC / CPL)' -Options @(
        @{ Key = '1'; Label = 'Gestionnaire de peripheriques';  Action = { Open-NTAdminTool 'devmgmt.msc' } }
        @{ Key = '2'; Label = 'Connexions reseau';              Action = { Open-NTAdminTool 'ncpa.cpl' } }
        @{ Key = '3'; Label = 'Gestion de l ordinateur';        Action = { Open-NTAdminTool 'compmgmt.msc' } }
        @{ Key = '4'; Label = 'Observateur d evenements';       Action = { Open-NTAdminTool 'eventvwr.msc' } }
        @{ Key = '5'; Label = 'Editeur du registre';            Action = { Open-NTAdminTool 'regedit.exe' } }
        @{ Key = '6'; Label = 'Services (MMC)';                  Action = { Open-NTAdminTool 'services.msc' } }
        @{ Key = '7'; Label = 'Invite de commandes admin';      Action = { Open-NTAdminTool 'cmd.exe' } }
        @{ Key = '8'; Label = 'Planificateur de taches';        Action = { Open-NTAdminTool 'taskschd.msc' } }
    )
}

# --- Generateur de sous-menu (utilise par toutes les fonctions ci-dessus)
function Show-NTSubMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][array]$Options
    )
    if (Get-NTInteractive) { Clear-Host }
    Write-NTTitle
    $W = 100
    $bar = [string]::new([char]0x2550, $W)
    $sub = [string]::new([char]0x2500, $W)

    Write-Host $bar -ForegroundColor Cyan
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host $bar -ForegroundColor Cyan
    Write-Host ''

    foreach ($opt in $Options) {
        Write-NTMenuItem -Key $opt.Key -Label $opt.Label
    }

    Write-Host ''
    Write-Host $sub -ForegroundColor DarkCyan
    Write-NTMenuItem -Key '0'  -Label 'Retour au menu principal'
    Write-NTMenuItem -Key 'R'  -Label 'Rapport complet (TXT + HTML)' -Highlight
    Write-NTMenuItem -Key 'I'  -Label 'Informations'
    Write-NTMenuItem -Key 'Q'  -Label 'Quitter'
    Write-Host $sub -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host '   > ' -NoNewline -ForegroundColor Magenta

    $choice = (Read-Host).Trim().ToUpper()
    Write-Host ''

    # Recherche de l'action
    $selected = $Options | Where-Object { $_.Key -eq $choice } | Select-Object -First 1
    if ($selected) {
        & $selected.Action
    } elseif ($choice -eq '0') {
        return 'MAIN'
    } elseif ($choice -eq 'R') {
        Export-NTReport
    } elseif ($choice -eq 'I') {
        Show-NTInfo
    } elseif ($choice -eq 'Q') {
        return 'QUIT'
    } else {
        Write-Host "   Choix invalide : '$choice'" -ForegroundColor Red
        Start-Sleep -Milliseconds 600
    }
    return 'CONTINUE'
}

function Open-NTAdminTool {
    param([string]$Command)
    if (Test-NTAdmin) {
        [Diagnostics.Process]::Start($Command) | Out-Null
    } else {
        [Diagnostics.Process]::Start($Command, '-verb', 'runas') | Out-Null
    }
}

function Show-NTInfo {
    if (Get-NTInteractive) { Clear-Host }
    Write-NTTitle
    $W = 100
    $bar = [string]::new([char]0x2550, $W)
    Write-Host $bar -ForegroundColor Cyan
    Write-Host '   A PROPOS' -ForegroundColor Cyan
    Write-Host $bar -ForegroundColor Cyan
    Write-Host ''
    $info = Get-NTScriptInfo
    [pscustomobject]@{
        Version      = $info.Version
        Copyright    = $info.Copyright
        Site         = $info.Site
        'PowerShell' = $info.PowerShell
        OS           = $info.OS
        Admin        = $info.IsAdmin
        'Dossier'    = $ScriptDir
        'Log'        = $info.LogFile
    } | Format-List
    Write-Host ''
    Write-Host '   Ce toolkit est un logiciel libre mis a disposition par TechSentinel.' -ForegroundColor White
    Write-Host '   Aucune donnee n est transmise. Tout s execute en local.' -ForegroundColor White
    Write-Host ''
    Wait-NTKey
}

# --- Boucle principale (navigation entre menu principal et sous-menus)
do {
    Show-NTMainMenu
    $choice = (Read-Host).Trim().ToUpper()
    Write-Host ''

    $nav = switch ($choice) {
        '1'  { Show-NTMenu-AuditMateriel }
        '2'  { Show-NTMenu-Reseau }
        '3'  { Show-NTMenu-Securite }
        '4'  { Show-NTMenu-Logiciels }
        '5'  { Show-NTMenu-Reparation }
        '6'  { Show-NTMenu-OutilsAdmin }
        '7'  { Export-NTReport }
        'I'  { Show-NTInfo }
        'Q'  { 'QUIT' }
        default {
            if ($choice) {
                Write-Host "   Choix invalide : '$choice'" -ForegroundColor Red
                Start-Sleep -Milliseconds 500
            }
            'CONTINUE'
        }
    }

    if ($nav -eq 'QUIT') {
        if (Get-NTInteractive) { Clear-Host }
        $bar = [string]::new([char]0x2550, 60)
        Write-Host ''
        Write-Host $bar -ForegroundColor Cyan
        Write-Host "   NeoTech Toolkit ferme. A bientot." -ForegroundColor Cyan
        Write-Host $bar -ForegroundColor Cyan
        Write-Host ''
        Write-NTLog -Message "Arret par utilisateur" -Level Info -Component 'Main'
    }
} while ($nav -ne 'QUIT')

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUdS2OtOzuhUk+Js6xsQNpcc05
# NJugggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
# AQsFADBgMQswCQYDVQQGEwJGUjERMA8GA1UEBwwIVG91bG91c2UxFTATBgNVBAoM
# DFRlY2hTZW50aW5lbDEnMCUGA1UEAwweTmVvVGVjaCBUb29sa2l0IChUZWNoU2Vu
# dGluZWwpMB4XDTI2MDkwNTA4NTMxMVoXDTMxMDkwNTA5MDMxMVowYDELMAkGA1UE
# BhMCRlIxETAPBgNVBAcMCFRvdWxvdXNlMRUwEwYDVQQKDAxUZWNoU2VudGluZWwx
# JzAlBgNVBAMMHk5lb1RlY2ggVG9vbGtpdCAoVGVjaFNlbnRpbmVsKTCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBANmhOxXsQR0O5n0zofF9w368BLZYjxWn
# eJn+nZHgDOZv9xjrvB6d+TPRQshHHFxdAHvYcf7l5a7nDf6UNma27fPYmUut3Lnq
# o9pjsQRHqBOKWGnMEJKV9fZDDxpCuiTfuD6Wf3qOdUvJqTSv8g+a5VFJrY/ZvXl5
# rsRGQIQOMfDKbG3tjAGuKIqVG6zjGi2ZHbJczPmApj2gFtrKKA0cY03xFSZte7dP
# qvAY7YFaNZnms5PociatNhCdcSfHTFGI2WTUlYW69BaX5eUrOGaqAec6eL+avgdg
# CUpEN6cgHLxbTxDID4IOqHVdFdA7oqXw8CN6+zKxYyROxK3BdXdD1HUCAwEAAaNG
# MEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQW
# BBRCPPTmQoHDrrP/39dmsxIWEoG0MTANBgkqhkiG9w0BAQsFAAOCAQEApk/OCP+k
# PnuPJw1lKwpv8BEWPNqFvKUYy9C697uL5AzyZMiOnZ31H+TYZlBeRjY8LCusKYai
# ZKP+376jMRoDTsTehNbYlBNEbCQHGMwUOUXrNrdARa601DlKNaUyLkpdmHyzKL9A
# eK1Q0gD12fCGd9Nzne3ZLeNDUQB3F+ZeyCy217JapJltBsgY8F7hQH1TnfuKX4pG
# a8iQLW0NXe5UEzytpokllsp9AKmkTIoLTFkLiaFZeQ2w1VlQy9D52w0b1OvNts+f
# 4zhMa11HLrJd0dGluJhXp2SFthz4iKjgK6J0sswy58fxIBHwguwo8rHuKvi3Aqkg
# v3dyED6MOWrTgTGCAhUwggIRAgEBMHQwYDELMAkGA1UEBhMCRlIxETAPBgNVBAcM
# CFRvdWxvdXNlMRUwEwYDVQQKDAxUZWNoU2VudGluZWwxJzAlBgNVBAMMHk5lb1Rl
# Y2ggVG9vbGtpdCAoVGVjaFNlbnRpbmVsKQIQO+7SyralWaVEZNPsB84DmDAJBgUr
# DgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMx
# DAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkq
# hkiG9w0BCQQxFgQU6Ggp70Gg0MD65FKpjYlLcZrIebswDQYJKoZIhvcNAQEBBQAE
# ggEAtth/sO454ONPKrRMrdBA/qsWuCB48KG45OlSf7JATirV99QeKlvIvVtCoDMH
# Sjjmkf8vupsi+XhBBfmxybXf9S2/KVGsLTaQfnqdoV67qvGa2qrKsoeqMC6XOx0T
# /xAl62Fqanbhjyf00/M1+JYtjoVXj10WEYdED5vDhrBUf2+nHbW4AYnNqYZSnpzh
# kNJb2j8wB/RWMjOCuHkRhU7ssR0zsAoojR3KDu8sYMRbAelGNQ6XvvSam6s5K1yO
# gCMB/Bgix5ZJh8HMP3E//A/hxRTelkVmaK78lC0EdOJvSlQe4wVLBdIKNC2Y1rI7
# CIkZ2uKHBcFnG88tOkSS65B0hg==
# SIG # End signature block
