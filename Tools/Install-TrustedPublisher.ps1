# =============================================================================
# Script      : Install-TrustedPublisher.ps1
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Importe le certificat NeoTech Toolkit dans le magasin
#               LocalMachine\TrustedPeople (magasin de confiance Windows).
#               Permet a Windows de reconnaitre les scripts signes par ce cert
#               comme "editeur de confiance" -> pas de SmartScreen/AMSI alert.
# =============================================================================

#requires -Version 5.1

[CmdletBinding()]
param(
    [string]$ToolkitRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Auto-elevation
if (-not (
    [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ''
    Write-Host '  Elevation requise (magasin LocalMachine).' -ForegroundColor Yellow
    $psPath = (Get-Process -Id $PID).Path
    if (-not $psPath) { $psPath = 'powershell.exe' }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psPath
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.UseShellExecute = $true
    $psi.Verb = 'runas'
    try { [Diagnostics.Process]::Start($psi) | Out-Null } catch {
        Write-Host "  Echec elevation : $_" -ForegroundColor Red
        pause; exit 1
    }
    exit
}

$root  = (Resolve-Path $ToolkitRoot).Path
$tools = Join-Path $root 'Tools'
$cert  = Join-Path $tools 'NeoTech-Toolkit.cer'

Write-Host ''
Write-Host '  NeoTech Toolkit - Installation editeur de confiance' -ForegroundColor Cyan
Write-Host ('=' * 60) -ForegroundColor Cyan

if (-not (Test-Path $cert)) {
    Write-Host ''
    Write-Host "  Certificat introuvable : $cert" -ForegroundColor Red
    Write-Host "  Lancez d'abord Tools\Sign-NeoTech.ps1 pour generer le certificat." -ForegroundColor Yellow
    Write-Host ''
    pause
    exit 1
}

Write-Host "  Certificat : $cert" -ForegroundColor White
Write-Host ''
Write-Host "  Ce script va importer le certificat dans :" -ForegroundColor White
Write-Host "    Cert:\LocalMachine\TrustedPeople" -ForegroundColor Cyan
Write-Host ''
$confirm = Read-Host '  Confirmer l installation ? (O/N)'
if ($confirm -ne 'O') {
    Write-Host "  Annule." -ForegroundColor Yellow
    pause; exit
}

try {
    Import-Certificate -FilePath $cert -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' -ErrorAction Stop | Out-Null
    Write-Host ''
    Write-Host "  OK : certificat importe dans LocalMachine\TrustedPeople" -ForegroundColor Green
} catch {
    Write-Host ''
    Write-Host "  Echec : $_" -ForegroundColor Red
    pause; exit 1
}

# Verif
$store = Get-ChildItem -Path 'Cert:\LocalMachine\TrustedPeople' -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -like '*NeoTech*' }
if ($store) {
    Write-Host ''
    Write-Host "  Certificat verifie dans le magasin :" -ForegroundColor Green
    Write-Host "    Sujet     : $($store.Subject)" -ForegroundColor White
    Write-Host "    Empreinte : $($store.Thumbprint)" -ForegroundColor White
    Write-Host "    Expire le : $($store.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor White
} else {
    Write-Host "  ATTENTION : certificat non trouve dans le magasin apres import." -ForegroundColor Yellow
}

Write-Host ''
Write-Host "  Vous pouvez maintenant executer NeoTech-Toolkit.ps1 sans alerte." -ForegroundColor Green
Write-Host ''
pause

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/VqXuxU+ri8lkH/WloJAI9W8
# h0ugggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUWjZslhInwLriYcWJcKhcEcWAG1EwDQYJKoZIhvcNAQEBBQAE
# ggEAlaK1ByhmitamLsWBWvmNfohr3T2KFTx/XtNF11dTaZOyAfe8OOIt2PzxoaXA
# curFbE/czsVH5XH9ea3WCeAyXw9gsdgsYIWV2LlmsnrkVvxvsvl+W+FVmt+IsbBb
# ZdXzxf1EuAy/IzPNUs7MOOiK6V0eTMEk5IeAcLdlRlu6LkXYsgXe5qMN20DoW+QM
# 0imeXuyC7gmDgIkGeR0BjqXKZyhLNnOpGasVW6iaF3vqI87Z3VLlJgyHjJ55NGsi
# 0qfkWSRvcFUl81QbRJLsqW7wBYIa/lQkakrz+miMZiHXLMRd/Y3LLc6gCdTeNVZS
# corU9cCUiY+/rl2NbXsRlDA40A==
# SIG # End signature block
