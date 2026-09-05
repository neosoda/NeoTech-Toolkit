# =============================================================================
# Script      : NeoTech-Toolkit-GUI.ps1
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Site        : https://techsentinel.fr
# Version     : 1.0.0
# Description : Interface graphique WPF pour NeoTech Toolkit.
#               Meme moteur metier que la version console, mais avec une vraie
#               fenetre, sidebar de categories, sous-menus et zone de sortie.
# =============================================================================

#requires -Version 5.1

[CmdletBinding()]
param(
    # Permet d'ouvrir l'UI non-elovee (lecture seule possible)
    [switch]$NoElevation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor Red
    Write-Host '   ERREUR NEOTECH TOOLKIT GUI' -ForegroundColor Red
    Write-Host '  ============================================================' -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor White
    Write-Host ''
    Read-Host 'Entree pour quitter'
    exit 1
}

# --- Localisation
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModuleDir = Join-Path $ScriptDir 'Modules'

# --- Import des modules metier
$modules = @('NTCommon','NTAudit','NTNetwork','NTStorage','NTSecurity','NTPower',
             'NTStartup','NTPerformance','NTRepair','NTReport','NTGUI')
foreach ($m in $modules) {
    Import-Module (Join-Path $ModuleDir "$m.psm1") -Force -DisableNameChecking -ErrorAction Stop
}

# --- Helper : Open-NTAdminTool (necessaire au module GUI)
function Open-NTAdminTool {
    param([string]$Command)
    if (Test-NTAdmin) {
        [Diagnostics.Process]::Start($Command) | Out-Null
    } else {
        try {
            [Diagnostics.Process]::Start($Command, '-verb', 'runas') | Out-Null
        } catch {
            Write-Warning "Impossible d'ouvrir $Command : $_"
        }
    }
}

# --- Elevation optionnelle (l'UI fonctionne aussi sans admin, certaines actions
#     demanderont une elevation via UAC)
if (-not (Test-NTAdmin) -and -not $NoElevation) {
    $psPath = (Get-Process -Id $PID -ErrorAction SilentlyContinue).Path
    if (-not $psPath) { $psPath = 'powershell.exe' }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName         = $psPath
    $psi.Arguments        = "-NoProfile -ExecutionPolicy RemoteSigned -STA -File `"$PSCommandPath`""
    $psi.UseShellExecute  = $true
    $psi.Verb             = 'runas'
    $psi.WorkingDirectory = $ScriptDir
    try {
        [Diagnostics.Process]::Start($psi) | Out-Null
        exit
    } catch {
        Write-Warning "Elevation refusee, demarrage sans admin (lecture seule)."
    }
}

# --- Lancement de l'UI
Start-NTGui

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUwDS/mILwnQaaOofcXgW/8X+4
# mgGgggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUsRCf0TaEUlW2EvRdn6LCUVXeG6UwDQYJKoZIhvcNAQEBBQAE
# ggEAdEffplPxzErmOciIiU9lDlN+2cqTYVLhkkI/vfTllPZ13/6endM0GuFKuCzY
# kMupmTtJ5MzEdg/yflRi6Vtsxc3mrTxy+Eu09+J4/YUZD03/dGOQrg+5E/l0orcV
# RPYXvBhNNt3r4DPvWYyi2ZqDRD5Cznqt3JrA64oBZypA6aY8zUnNuU6teuhedWZZ
# wfAPjJkmXrh7bAsZ2N6o0JWNqe26yCGAUJV9lllDgeF/+OXjkZEt5SnL9CXkx0I+
# bnimnT5AxAzEbM3lFr/cRkWbzWzR57S68Q0ufFYVAFE//bvtcYvEzJRnhOJh1WkN
# VFG1/ajYIHSE7p+tTwtAwp4M3g==
# SIG # End signature block
