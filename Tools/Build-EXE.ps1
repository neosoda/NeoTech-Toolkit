# =============================================================================
# Script      : Build-EXE.ps1
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Compile NeoTech-Toolkit-GUI.ps1 en .exe unique via ps2exe.
#               Le .exe est ensuite signe avec le certificat NeoTech.
# =============================================================================

#requires -Version 5.1

[CmdletBinding()]
param(
    [string]$ToolkitRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root   = (Resolve-Path $ToolkitRoot).Path
$tools  = Join-Path $root 'Tools'
$output = Join-Path $tools 'NeoTech-Toolkit.exe'
$input  = Join-Path $root  'NeoTech-Toolkit-GUI.ps1'
$icon   = $null   # ajouter un .ico si disponible

Write-Host ''
Write-Host '  NeoTech Toolkit - Build EXE (ps2exe)' -ForegroundColor Cyan
Write-Host ('=' * 60) -ForegroundColor Cyan
Write-Host "  Input  : $input"
Write-Host "  Output : $output"
Write-Host ''

# --- Verifier / installer ps2exe ---------------------------------------------
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host '  Installation de ps2exe...' -ForegroundColor Yellow
    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
}
Import-Module ps2exe -ErrorAction Stop

# --- Verifier que ps2exe est compatible (PS 5.1) ------------------------------
$psv = $PSVersionTable.PSVersion
Write-Host "  PowerShell : $psv"

# --- Build --------------------------------------------------------------------
if ((Test-Path $output) -and -not $Force) {
    Write-Host ''
    $confirm = Read-Host "  $output existe deja. Ecraser ? (O/N)"
    if ($confirm -ne 'O') { Write-Host '  Annule.' -ForegroundColor Yellow; exit }
}

Write-Host ''
Write-Host '  Compilation en cours...' -ForegroundColor Cyan

# Options ps2exe :
#   -noConsole    : GUI, pas de fenetre console en arriere-plan
#   -requireAdmin : demande elevation UAC au lancement
#   -sta          : mode STA (obligatoire pour WPF)
#   -embed        : embarque les modules dans l'exe
#   -version      : infos de version
try {
    $params = @{
        inputFile    = $input
        outputFile   = $output
        noConsole    = $true
        requireAdmin = $true
        STA          = $true
        title        = 'NeoTech Toolkit'
        description  = 'NeoTech Toolkit - Administration et diagnostic Windows'
        company      = 'TechSentinel'
        product      = 'NeoTech Toolkit'
        copyright    = '(c) 2026 TechSentinel - Neo Soda'
        version      = '1.0.0.0'
    }
    Invoke-ps2exe @params -ErrorAction Stop
    Write-Host '  Compile OK' -ForegroundColor Green
} catch {
    Write-Host "  ERREUR de compilation : $_" -ForegroundColor Red
    Write-Host ''
    Write-Host '  Note : ps2exe dans PS 5.1 peut avoir des soucis avec certains parametres.' -ForegroundColor Yellow
    Write-Host '  Si echec, essayez de compiler depuis PowerShell 7 :' -ForegroundColor Yellow
    Write-Host "    pwsh -File '$PSCommandPath'" -ForegroundColor Cyan
    exit 1
}

# --- Signer le .exe -----------------------------------------------------------
Write-Host ''
Write-Host '  Signature Authenticode du .exe...' -ForegroundColor Cyan
$cert = Get-ChildItem -Path 'Cert:\CurrentUser\My' -CodeSigningCert |
    Where-Object { $_.Subject -like '*NeoTech*' } |
    Select-Object -First 1
if ($cert) {
    try {
        Set-AuthenticodeSignature -FilePath $output -Certificate $cert -IncludeChain 'NotRoot' -ErrorAction Stop | Out-Null
        Write-Host "  Signe : $($cert.Subject)" -ForegroundColor Green
    } catch {
        Write-Host "  AVERTISSEMENT : signature a echoue : $_" -ForegroundColor Yellow
        Write-Host '  Le .exe fonctionne mais Windows affichera une alerte de editeur inconnu.' -ForegroundColor Yellow
    }
} else {
    Write-Host '  Cert NeoTech introuvable. Lancez Tools\Sign-NeoTech.ps1 d abord.' -ForegroundColor Yellow
}

# --- Verif --------------------------------------------------------------------
Write-Host ''
Write-Host '  Resultat :' -ForegroundColor Cyan
if (Test-Path $output) {
    $size = [math]::Round((Get-Item $output).Length/1MB, 1)
    Write-Host "    $output ($size MB)" -ForegroundColor Green
} else {
    Write-Host '    ECHEC : le .exe n a pas ete cree' -ForegroundColor Red
}
Write-Host ''

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUdFfGEFQWqRcoYJuMehq/b21P
# ds+gggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUPwrUkrcKi2V/ksH8+mnKSBTj0RQwDQYJKoZIhvcNAQEBBQAE
# ggEAMx3Z1yozZ0pIfhRDglzs7cPGUOJk3ugnava6meKXpZAOki1thuS/gzhm5OlF
# Lc1JXp5ifleJU7Fa1iJEqf3/bs5Os/pW8bnG1T7WSHTJjdza3/tTaC9/YLcw+BBo
# TIeozWn2uyqsuWZocoixFBCjS8I4Fq7TKDtoaFMVlnmlq/aX/XTDTCS2B1iNAWrz
# chYVBVLeKPheKAqTkusgML8ZZlLaQjdurQ5EbysS1dLN//eJTwur5sSfs92vOtlV
# 790N5jfdogBe+GKH+SdqFsJJGsk1KRBtqaHiPQImvW0g41loraX5VVxn3kWntKvM
# G/nRUX8Bi4SFig3AoxmbfG3ATA==
# SIG # End signature block
