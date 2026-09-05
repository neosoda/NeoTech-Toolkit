# =============================================================================
# Module      : NTStorage
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Audit stockage (volumes, disques physiques, SMART, temperatures).
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'NTCommon.psm1') -Force -Global

function Get-NTStorageReport {
    <#
    .SYNOPSIS
        Rapport complet de stockage : volumes, disques physiques, S.M.A.R.T.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'STOCKAGE : VOLUMES ET DISQUES'

    Write-NTSubHeader 'VOLUMES LOGIQUES'
    $vols = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    if ($vols) {
        $vols | Select-Object DeviceID,
            VolumeName,
            FileSystem,
            @{N='Taille';E={Format-NTBytes -Bytes $_.Size}},
            @{N='Libre';E={Format-NTBytes -Bytes $_.FreeSpace}},
            @{N='% utilise';E={
                if ($_.Size -gt 0) { [math]::Round((1 - $_.FreeSpace/$_.Size)*100, 1) } else { 0 }
            }} | Format-Table -AutoSize
    } else { Write-NTStatus -Message 'Aucun volume fixe detecte.' -Status FAIL }

    Write-NTSubHeader 'DISQUES PHYSIQUES'
    $pdisks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    if ($pdisks) {
        $pdisks | Select-Object FriendlyName,
            MediaType,
            BusType,
            @{N='Taille';E={Format-NTBytes -Bytes $_.Size}},
            HealthStatus,
            OperationalStatus,
            SerialNumber,
            FirmwareRevision | Format-Table -AutoSize -Wrap
    } else {
        Write-NTStatus -Message 'Get-PhysicalDisk indisponible (old Windows?).' -Status WARN
        Get-CimInstance Win32_DiskDrive | Select-Object Model, InterfaceType,
            @{N='Taille';E={Format-NTBytes -Bytes $_.Size}}, Status | Format-Table -AutoSize
    }

    Write-NTSubHeader 'SANTE SMART (Storage Reliability Counter)'
    foreach ($d in $pdisks) {
        Write-Host "  --- $($d.FriendlyName) (SN: $($d.SerialNumber)) ---" -ForegroundColor Cyan
        $smart = Get-Disk -Number $d.DeviceId -ErrorAction SilentlyContinue |
            Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
        if ($smart) {
            [pscustomobject]@{
                'Temperature (C)'        = $smart.Temperature
                'PowerOnHours'           = $smart.PowerOnHours
                'Wear (SSD %)'           = $smart.Wear
                'ReadErrorsTotal'        = $smart.ReadErrorsTotal
                'WriteErrorsTotal'       = $smart.WriteErrorsTotal
                'ReadLatencyMax (ms)'    = $smart.ReadLatencyMax
                'WriteLatencyMax (ms)'   = $smart.WriteLatencyMax
            } | Format-List
        } else {
            Write-NTStatus -Message 'Compteurs SMART non disponibles (driver ou disque non supporte).' -Status WARN
        }
    }

    Wait-NTKey
}

function Get-NTDiskSpace {
    <#
    .SYNOPSIS
        Affiche uniquement l'espace disque (vue rapide).
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'ESPACE DISQUE (VUE RAPIDE)'
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $usedPct = if ($_.Size -gt 0) { [math]::Round((1 - $_.FreeSpace/$_.Size)*100, 1) } else { 0 }
        $bar = [string]::new([char]9608, [int]($usedPct/5))
        $color = if ($usedPct -gt 90) { 'Red' } elseif ($usedPct -gt 75) { 'Yellow' } else { 'Green' }
        Write-Host ("  {0}  {1,6}%  {2} / {3}  libre {4}" -f `
            $_.DeviceID, $usedPct, (Format-NTBytes -Bytes ($_.Size - $_.FreeSpace)), (Format-NTBytes -Bytes $_.Size), (Format-NTBytes -Bytes $_.FreeSpace)) `
            -ForegroundColor $color
    }
    Wait-NTKey
}

function Clear-NTTempFiles {
    <#
    .SYNOPSIS
        Nettoie les fichiers temporaires utilisateur et Windows.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'NETTOYAGE FICHIERS TEMPORAIRES'

    $targets = @(
        $env:TEMP,
        $env:TMP,
        "$env:LOCALAPPDATA\Temp",
        'C:\Windows\Temp',
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    )
    $totalFreed = 0
    foreach ($t in $targets) {
        if (Test-Path $t) {
            Write-Host "  -> Nettoyage : $t" -ForegroundColor DarkGray
            $r = Invoke-NTSafe -Component 'Storage' -Title "Clean $t" -ScriptBlock {
                $size = 0
                Get-ChildItem -Path $t -Recurse -Force -File -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        try {
                            $s = $_.Length
                            Remove-Item -Path $_.FullName -Force -ErrorAction Stop
                            $size += $s
                        } catch { }
                    }
                $size
            }
            if ($r.Success) { $totalFreed += $r.Data }
        }
    }
    Write-NTStatus -Message "Espace libere : $(Format-NTBytes -Bytes $totalFreed)" -Status OK
    Wait-NTKey
}

Export-ModuleMember -Function `
    Get-NTStorageReport, Get-NTDiskSpace, Clear-NTTempFiles

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUoZ7uz10BnUYg7+SoyahTOMJe
# jEKgggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUV59DfOCw0SKOy+P3QxMXzVhvbsQwDQYJKoZIhvcNAQEBBQAE
# ggEAzt9QQQGMxkVU4iJVpZo9VC2bkTRdR/fV+xTiDVo07TIkZb5Y6/fBfNA5kjK3
# qvZuaNj4OQFkVXMeqaA7CxQ2YEYylYbjofxzRhMET5wuhiThpDvYXzP10PqKOc95
# x2H+YAgFK5WK0HN5XcZE4nqDIYquVUCEOiXOTYcHrpgdAfwkMZFwyePyTQ6lKDUL
# zXcyOff7UKg//a5Y+fv9d+DEsSkJEP/xNhxEKPn88VJ4MSJ8JR7+7LEWA2oThNHt
# gB01Xm2yC6IU6bi/A/tZL41q46l5W5f5FaNdybpMdUWbS9QzifRO021/PaQzPyoe
# WK9r5QlL1aooRAVo0ckHllD9lA==
# SIG # End signature block
