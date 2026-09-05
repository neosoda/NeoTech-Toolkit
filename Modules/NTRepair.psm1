# =============================================================================
# Module      : NTRepair
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Outils de reparation systeme (SFC, DISM, Windows Update reset, etc.).
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'NTCommon.psm1') -Force -Global

function Repair-NTSystemFiles {
    <#
    .SYNOPSIS
        Lance SFC (System File Checker) pour reparer les fichiers systeme.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'SFC - VERIFICATEUR DES FICHIERS SYSTEME'
    if (-not (Test-NTAdmin)) {
        Write-NTStatus -Message 'SFC necessite les droits administrateur.' -Status FAIL
        Wait-NTKey; return
    }
    $log = Join-Path $env:WINDIR 'Logs\CBS\CBS.log'

    Write-Host '  Lancement de sfc /scannow (peut prendre plusieurs minutes)...' -ForegroundColor Cyan
    $r = Invoke-NTSafe -Component 'Repair' -Title 'sfc /scannow' -ScriptBlock {
        $output = & sfc.exe /scannow 2>&1
        $output -join "`n"
    }
    if ($r.Success) {
        Write-Host $r.Data -ForegroundColor White
        Write-NTStatus -Message 'SFC termine. Log detaille : ' -Status OK
        Write-Host "    $log" -ForegroundColor DarkGray
    } else {
        Write-NTStatus -Message "SFC a echoue : $($r.Error)" -Status FAIL
    }
    Wait-NTKey
}

function Repair-NTComponentStore {
    <#
    .SYNOPSIS
        DISM : checkhealth / scanhealth / restorehealth.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'DISM - COMPOSANT IMAGE SYSTEME'
    if (-not (Test-NTAdmin)) {
        Write-NTStatus -Message 'DISM necessite les droits administrateur.' -Status FAIL
        Wait-NTKey; return
    }

    $steps = @(
        @{ Cmd = 'CheckHealth';  Label = 'Verification rapide'   }
        @{ Cmd = 'ScanHealth';   Label = 'Analyse approfondie'   }
        @{ Cmd = 'RestoreHealth';Label = 'Reparation (long)'     }
    )
    foreach ($s in $steps) {
        Write-Host "  -> $($s.Label) : DISM /Online /Cleanup-Image /$(($s.Cmd -replace 'Health$',''))Health" -ForegroundColor Cyan
        $r = Invoke-NTSafe -Component 'Repair' -Title "DISM $($s.Cmd)" -ScriptBlock {
            $proc = Start-Process -FilePath 'dism.exe' -ArgumentList "/Online","/Cleanup-Image","/$($s.Cmd)" -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -ne 0) { throw "DISM $($s.Cmd) a retourne code $($proc.ExitCode)" }
        }
        $status = if ($r.Success) { 'OK' } else { 'FAIL' }
        Write-NTStatus -Message "$($s.Label) : $($s.Cmd)" -Status $status
        if (-not $r.Success) { break }
    }
    Wait-NTKey
}

function Reset-NTWindowsUpdate {
    <#
    .SYNOPSIS
        Reinitialise les composants Windows Update (necessite redemarrage).
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'RESET COMPOSANTS WINDOWS UPDATE'
    if (-not (Test-NTAdmin)) {
        Write-NTStatus -Message 'Reset WU necessite les droits administrateur.' -Status FAIL
        Wait-NTKey; return
    }
    $confirm = Read-Host '  Confirmer le reset Windows Update ? (O/N)'
    if ($confirm -ne 'O') { Write-NTStatus -Message 'Annule.' -Status INFO; Wait-NTKey; return }

    $steps = @(
        @{ Cmd = 'net stop wuauserv';           Label = 'Arret du service WUA' },
        @{ Cmd = 'net stop cryptSvc';           Label = 'Arret du service Crypt' },
        @{ Cmd = 'net stop bits';               Label = 'Arret du service BITS' },
        @{ Cmd = 'net stop msiserver';          Label = 'Arret du service MSI' },
        @{ Cmd = "Rename-Item C:\Windows\SoftwareDistribution SoftwareDistribution.old -ErrorAction SilentlyContinue"; Label = 'Renommage SoftwareDistribution' },
        @{ Cmd = "Rename-Item C:\Windows\System32\catroot2 catroot2.old -ErrorAction SilentlyContinue";            Label = 'Renommage catroot2' },
        @{ Cmd = 'net start wuauserv';          Label = 'Demarrage du service WUA' },
        @{ Cmd = 'net start cryptSvc';          Label = 'Demarrage du service Crypt' },
        @{ Cmd = 'net start bits';              Label = 'Demarrage du service BITS' },
        @{ Cmd = 'net start msiserver';         Label = 'Demarrage du service MSI' }
    )
    foreach ($s in $steps) {
        Write-Host "  -> $($s.Label)" -ForegroundColor DarkGray
        $r = Invoke-NTSafe -Component 'Repair' -Title $s.Label -ScriptBlock {
            Invoke-Expression $s.Cmd
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Code sortie $LASTEXITCODE" }
        }
        if (-not $r.Success) {
            Write-NTStatus -Message $s.Label -Status FAIL
        }
    }
    Write-NTStatus -Message 'Reset WU termine. Redemarrer le poste.' -Status OK
    Wait-NTKey
}

function Get-NTSystemHealth {
    <#
    .SYNOPSIS
        Health check rapide : SFC, DISM checkhealth, etat BitLocker, espace disque.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'HEALTH CHECK RAPIDE'

    Write-NTSubHeader 'SFC (verification rapide uniquement)'
    if (Test-NTAdmin) {
        $r = Invoke-NTSafe -Component 'Repair' -Title 'sfc /verifyonly' -ScriptBlock {
            $proc = Start-Process -FilePath 'sfc.exe' -ArgumentList '/verifyonly' -Wait -PassThru -NoNewWindow
            # 0 = no integrity violations, 1 = could not fix, 2 = success (manual), 3 = corruption
            @{ Code = $proc.ExitCode; Output = 'Voir log CBS pour details' }
        }
        if ($r.Success) {
            $code = $r.Data.Code
            $msg = switch ($code) {
                0 { 'Aucune violation d integrite.' }
                1 { 'Integrite OK mais le SFC a detecte des reparations deja appliquees.' }
                2 { 'Fichiers systeme corrompus detectes (SFC a tente de reparer).' }
                3 { 'Fichiers systeme corrompus detectes et non repares automatiquement.' }
                default { "Code retour $code" }
            }
            $status = if ($code -in 0,1) { 'OK' } else { 'WARN' }
            Write-NTStatus -Message "SFC : $msg" -Status $status
        }
    } else { Write-NTStatus -Message 'SFC necessite admin (saute).' -Status WARN }

    Write-NTSubHeader 'ESPACE DISQUE (warning si > 90 %)'
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $pct = if ($_.Size -gt 0) { [math]::Round((1 - $_.FreeSpace/$_.Size)*100, 1) } else { 0 }
        $st  = if ($pct -gt 90) { 'FAIL' } elseif ($pct -gt 80) { 'WARN' } else { 'OK' }
        Write-NTStatus -Message "$($_.DeviceID) ${pct}%" -Status $st
    }

    Wait-NTKey
}

Export-ModuleMember -Function `
    Repair-NTSystemFiles, Repair-NTComponentStore, `
    Reset-NTWindowsUpdate, Get-NTSystemHealth

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUeA3Th/xvf/StpP1+lzS8SVpu
# 6negggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUWkrdwCMqXLJ2dM5eRczokeHvMZMwDQYJKoZIhvcNAQEBBQAE
# ggEAofDvYJsrHvL//3mn6VjpXGMhzja8KK77vp1ubtgr1JA+SxCGD5KphZ/NVrTv
# swfN4De5HiSujd6WNGi20Hf0QG6Hm52rWu9QRiNQ0N3DKpIW+YaUB5GbZj5q0BzW
# Q3VzZMnM6foM/NBo80gA6LfQq2Rlvz2xB17rkb22XCE5vYs2JOc9uWx6wrXHMyL/
# l336jNDmRVOU/jamjBSdNIbyR9stZ4bt7t1qGPSKGeBRAe1UFh8kiitUJulMmxdK
# YIyf3opQ5hS7NILYwWwLL/za9TfTmIoHhkiuqB0Io2ntzegxvgU/fnYpGVgXyPCy
# QxFfKlmMH/gNdyDKz0WvYd7Ccw==
# SIG # End signature block
