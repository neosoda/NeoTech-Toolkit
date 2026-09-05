# =============================================================================
# Script      : Sign-NeoTech.ps1
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Genere (ou reutilise) un certificat auto-signe Code-Signing,
#               puis signe Authenticode tous les .ps1/.psm1 du toolkit.
#               Le certificat est stocke dans Cert:\CurrentUser\My (utilisateur).
#               La cle publique est exportee en NeoTech-Toolkit.cer dans Tools\.
# =============================================================================

#requires -Version 5.1

[CmdletBinding()]
param(
    [string]$ToolkitRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CertSubject = 'CN=NeoTech Toolkit (TechSentinel), O=TechSentinel, L=Toulouse, C=FR',
    [int]$ValidYears     = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Text, [string]$Color = 'Cyan')
    Write-Host ''
    Write-Host "  $Text" -ForegroundColor $Color
    Write-Host ('-' * 60) -ForegroundColor DarkGray
}

# --- Localisation des scripts
$root = (Resolve-Path $ToolkitRoot).Path
$tools = Join-Path $root 'Tools'
if (-not (Test-Path $tools)) { New-Item -ItemType Directory -Path $tools -Force | Out-Null }
$certPath = Join-Path $tools 'NeoTech-Toolkit.cer'

Write-Step "NeoTech Toolkit - Signature Authenticode"
Write-Host "  Racine   : $root" -ForegroundColor DarkGray
Write-Host "  Sujet    : $CertSubject" -ForegroundColor DarkGray
Write-Host "  Duree    : $ValidYears ans" -ForegroundColor DarkGray

# --- Etape 1 : cert existant ?
$existing = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -eq $CertSubject } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1

if ($existing) {
    Write-Step "Certificat Code-Signing existant detecte" 'Green'
    Write-Host "  Sujet     : $($existing.Subject)" -ForegroundColor White
    Write-Host "  Empreinte : $($existing.Thumbprint)" -ForegroundColor White
    Write-Host "  Expire le : $($existing.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor White
    $cert = $existing
} else {
    Write-Step "Generation d'un nouveau certificat auto-signe" 'Yellow'

    # Besoin d'un provider moderne pour SHA256 + RSA 2048
    # New-SelfSignedCertificate est disponible PS5.1+ / Windows 10+
    $cert = New-SelfSignedCertificate `
        -Subject $CertSubject `
        -Type CodeSigningCert `
        -CertStoreLocation 'Cert:\CurrentUser\My' `
        -KeyUsage DigitalSignature `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddYears($ValidYears) `
        -KeyExportPolicy Exportable `
        -KeySpec Signature `
        -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3')  # Code Signing EKU

    if (-not $cert) {
        Write-Error "Echec de la creation du certificat."
        exit 1
    }
    Write-Host "  Certificat cree." -ForegroundColor Green
    Write-Host "  Sujet     : $($cert.Subject)" -ForegroundColor White
    Write-Host "  Empreinte : $($cert.Thumbprint)" -ForegroundColor White
    Write-Host "  Expire le : $($cert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor White
}

# --- Etape 2 : export de la cle publique (.cer)
Write-Step "Export de la cle publique" 'Cyan'
Export-Certificate -Cert $cert -FilePath $certPath -Type CERT | Out-Null
Write-Host "  Exporte vers : $certPath" -ForegroundColor Green

# --- Etape 3 : signature de tous les .ps1 et .psm1
Write-Step "Signature Authenticode des scripts" 'Cyan'

$targets = Get-ChildItem -Path $root -Recurse -Include '*.ps1','*.psm1' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\Tools\\Sign-NeoTech\.ps1$' }  # on ne se signe pas soi-meme

$signCount = 0
$failCount = 0
foreach ($f in $targets) {
    Write-Host "  Signature : $($f.FullName.Substring($root.Length+1))" -ForegroundColor DarkGray
    try {
        $sig = Get-AuthenticodeSignature -FilePath $f.FullName
        $alreadyOk = $sig -and $sig.SignerCertificate -and ($sig.SignerCertificate.Thumbprint -eq $cert.Thumbprint) -and ($sig.Status -eq 'Valid')
        if ($alreadyOk) {
            Write-Host "    (deja signe, OK)" -ForegroundColor DarkGray
            continue
        }
        $r = Set-AuthenticodeSignature -FilePath $f.FullName -Certificate $cert -IncludeChain 'NotRoot' -TimestampServer 'http://timestamp.digicert.com' -ErrorAction Stop
        if ($r.Status -eq 'Valid') {
            $signCount++
        } else {
            Write-Host "    Echec status : $($r.Status) - $($r.StatusMessage)" -ForegroundColor Red
            $failCount++
        }
    } catch {
        Write-Host "    Exception : $_" -ForegroundColor Red
        $failCount++
    }
}

Write-Step "RESULTAT" 'Green'
Write-Host "  Scripts signes OK : $signCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Scripts en echec  : $failCount" -ForegroundColor Red
}
Write-Host "  Certificat (.cer) : $certPath" -ForegroundColor Green
Write-Host ""
Write-Host "  PROCHAINE ETAPE : executez Install-TrustedPublisher.ps1" -ForegroundColor Yellow
Write-Host "  pour importer ce certificat dans LocalMachine\TrustedPeople" -ForegroundColor Yellow
Write-Host "  (necessite elevation UAC)." -ForegroundColor Yellow
Write-Host ""

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUqeKU1Ns+83nZv8zr9rZqCzzy
# 28+gggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUu6lHJAeYIc0epB9/Cwmb/N8l4ocwDQYJKoZIhvcNAQEBBQAE
# ggEAVrdsa/bNOdyhwnfLlr28HNCBf3AvgbQYP1VFEIPTM5Wr6Ony6Df59b4+GTCx
# rV70LLMf2p72WN2qlx4HEMzFVmxrcBBKYBMYM8eOKnFkrDdQWfu46sn0WbCu5nA5
# Ld0TrMSRDsONkd/e/xxjPzEtGXXLf+De4B2YtT1qH4FysG6bROjBJaJeypUVCgrS
# IFsDnQv8j4M3hgzSXLq2hTidnRfWaWc725agLK6/81m19e8TJ2X/wceUKEDKb1gf
# JxoFP/J3VhXYnpEHw5W4jRxJUYIsLi9Grw0yDEW434MVnmmmuvCGSAudOIN8BBbp
# aRsOBwq4Z1FyiNXEy6Pb/6FpVg==
# SIG # End signature block
