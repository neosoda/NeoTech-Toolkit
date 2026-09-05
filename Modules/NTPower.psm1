# =============================================================================
# Module      : NTPower
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Alimentation et batterie (laptop).
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'NTCommon.psm1') -Force -Global

function Get-NTBattery {
    <#
    .SYNOPSIS
        Etat detaille de la batterie (laptop uniquement).
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'BATTERIE'

    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if (-not $battery) {
        Write-NTStatus -Message 'Pas de batterie detectee (machine de bureau ou non exposee par WMI).' -Status INFO
        Wait-NTKey; return
    }

    foreach ($b in $battery) {
        [pscustomobject]@{
            'Nom'                    = $b.Name
            'Statut'                 = $b.Status
            'Etat (BatteryStatus)'   = switch ($b.BatteryStatus) {
                1 {'Decharge en cours'}
                2 {'Secteur (charge)'}
                3 {'Pleine'}
                4 {'Critique'}
                5 {'En charge'}
                6 {'En charge (haute)'}
                7 {'En charge (faible)'}
                8 {'En charge (crit.)'}
                9 {'Inconnue'}
                default {"Code $($b.BatteryStatus)"}
            }
            'Charge restante (%)'    = $b.EstimatedChargeRemaining
            'Temps restant (min)'    = $b.EstimatedRunTime
            'Type chimie'            = $b.Chemistry
        } | Format-List
    }

    Write-NTSubHeader 'RAPPORT DE BATTERIE WINDOWS (energy-report)'
    $reportPath = Join-Path $env:USERPROFILE 'Desktop\battery-report.html'
    $r = Invoke-NTSafe -Component 'Power' -Title 'powercfg /batteryreport' -ScriptBlock {
        & powercfg.exe /batteryreport /output $reportPath 2>&1 | Out-Null
        if (Test-Path $reportPath) { $reportPath } else { throw "Rapport non genere" }
    }
    if ($r.Success) {
        Write-NTStatus -Message "Rapport detaille : $($r.Data)" -Status OK
    } else {
        Write-NTStatus -Message 'Echec generation du rapport.' -Status FAIL
    }

    Wait-NTKey
}

function Get-NTPowerPlan {
    <#
    .SYNOPSIS
        Plans d'alimentation actifs et disponibles.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'PLANS D ALIMENTATION'

    Write-NTSubHeader 'PLAN ACTIF'
    $active = (Get-CimInstance -Namespace 'root\cimv2\power' -ClassName Win32_PowerPlan -ErrorAction SilentlyContinue |
        Where-Object { $_.IsActive }) | Select-Object -First 1
    if ($active) { Write-Host "  $($active.ElementName) (GUID $($active.InstanceID.Split('\')[-1]))" -ForegroundColor Green }

    Write-NTSubHeader 'PLANS DISPONIBLES'
    powercfg.exe /list 2>&1 | ForEach-Object {
        if ($_ -match 'GUID: (\S+)  \((.+)\)') {
            $guid = $Matches[1]
            $name = $Matches[2]
            $mark = if ($name -match '\*$') { '* ACTIF' } else { '' }
            Write-Host ("  {0,-38} {1} {2}" -f $guid, $name, $mark)
        }
    }

    Wait-NTKey
}

Export-ModuleMember -Function `
    Get-NTBattery, Get-NTPowerPlan

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUIeHL8mVES4mfBCS8JZ4SKHjK
# 0/qgggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUd9X7jw9BpaG4EIltS3/CCOTiVGQwDQYJKoZIhvcNAQEBBQAE
# ggEAbaAt2cpoHIvWE2Cmm58CCkXMWFts0xY4LxqG/L29VfgYVlN9i/apLdb4oath
# 4PTdeNRiyWJ2SxCJRahRPmm2GppJV3TeNYBwDj8F3uawCqL3Qhu4xXPX2jH6T61B
# dyQ/T73/mS5dP+pbs06vGVb8sRF1WUb96PnFhFNT3Jx91tJfBQNtpVQOzu/rpGCv
# qwgv5/6Jhn1Gh6/PkkHldKRBtDWImpst004lbgIopU6LrFY2B8JQ844BhUPA/h2x
# NGqQKD5uiNpuEquj0ZvQuRDKvaibJ73VYoDHhbqlZhdDexMMViG1cjK0X72sldfY
# WOWfZU4Jft++UdIVQaHXSj50zw==
# SIG # End signature block
