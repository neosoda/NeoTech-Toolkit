# =============================================================================
# Module      : NTNetwork
# Auteur      : Neo Soda - TechSentinel.fr
# Copyright   : (c) 2026 TechSentinel. Tous droits reserves.
# Description : Audit et reparation reseau.
# Version     : 1.0.0
# =============================================================================

#requires -Version 5.1

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'NTCommon.psm1') -Force -Global

function Get-NTNetworkSummary {
    <#
    .SYNOPSIS
        Audit reseau complet avec timeouts pour eviter les blocages.
    #>
    [CmdletBinding()]
    param()
    Write-NTHeader 'AUDIT RESEAU COMPLET'

    Write-NTSubHeader 'INTERFACES ACTIVES'
    $nics = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
    if (-not $nics) {
        Write-NTStatus -Message 'Aucune interface active.' -Status WARN
    } else {
        foreach ($nic in $nics) {
            $ipv4Obj = Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $ipv4 = if ($ipv4Obj) { ($ipv4Obj | ForEach-Object { $_.IPAddress }) -join ', ' } else { '' }
            $ipv6Obj = Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv6 -ErrorAction SilentlyContinue
            $ipv6 = if ($ipv6Obj) { ($ipv6Obj | Where-Object { $_.IPAddress -notmatch '^fe80' } | ForEach-Object { $_.IPAddress }) -join ', ' } else { '' }
            $gwObj = Get-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue
            $gw   = if ($gwObj) { ($gwObj | ForEach-Object { $_.NextHop }) -join ', ' } else { '' }
            $dnsObj = Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $dns  = if ($dnsObj) { ($dnsObj | ForEach-Object { $_.ServerAddresses }) -join ', ' } else { '' }
            $dhcpObj = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "Index=$($nic.ifIndex)" -ErrorAction SilentlyContinue
            $dhcp = if ($dhcpObj) { $dhcpObj.DHCPEnabled } else { $null }
            [pscustomobject]@{
                Interface    = $nic.Name
                Description  = $nic.InterfaceDescription
                Vitesse      = $nic.LinkSpeed
                MAC          = $nic.MacAddress
                IPv4         = if ($ipv4) { $ipv4 } else { 'N/A' }
                IPv6Global   = if ($ipv6) { $ipv6 } else { 'N/A' }
                Passerelle   = if ($gw)   { $gw   } else { 'Aucune' }
                DNS          = if ($dns)  { $dns  } else { 'N/A' }
                DHCP         = if ($null -ne $dhcp) { if ($dhcp) { 'Oui' } else { 'Non' } } else { 'N/D' }
            } | Format-List
        }
    }

    Write-NTSubHeader 'TESTS CONNECTIVITE (timeout 5s / test, skip si bloque)'
    $tests = @(
        @{ Name = 'IP publique 1.1.1.1';     Host = '1.1.1.1' }
        @{ Name = 'IP publique 8.8.8.8';     Host = '8.8.8.8' }
        @{ Name = 'Resolution google.com';   Host = 'google.com' }
        @{ Name = 'Resolution microsoft.com';Host = 'microsoft.com' }
        @{ Name = 'Resolution github.com';   Host = 'github.com' }
    )
    foreach ($t in $tests) {
        $result = Invoke-NTWithTimeout -TimeoutSec 5 -Component 'Network' -Label $t.Name -ScriptBlock {
            Test-NetConnection -ComputerName $t.Host -InformationLevel Quiet -WarningAction SilentlyContinue
        }
        if ($null -eq $result) {
            # WARN deja emis par Invoke-NTWithTimeout
        } elseif ($result) {
            Write-NTStatus -Message $t.Name -Status OK
        } else {
            Write-NTStatus -Message $t.Name -Status FAIL
        }
    }

    Write-NTSubHeader 'PROFILS WI-FI (timeout 5s)'
    $ssids = Invoke-NTWithTimeout -TimeoutSec 5 -Component 'Network' -Label 'Profils Wi-Fi' -ScriptBlock {
        $out = & netsh.exe wlan show profiles 2>$null
        $out | Select-String 'Profil Tous les utilisateurs|All User Profile' |
            ForEach-Object { ($_ -split ':', 2)[1].Trim() }
    }
    if ($ssids -and $ssids.Count -gt 0) {
        $ssids | ForEach-Object { Write-Host "   -> SSID : $_" }
    } else {
        Write-NTStatus -Message 'Aucun profil Wi-Fi (ou timeout).' -Status INFO
    }

    Write-NTSubHeader 'CACHE ARP (timeout 5s)'
    $arp = Invoke-NTWithTimeout -TimeoutSec 5 -Component 'Network' -Label 'Table ARP' -ScriptBlock {
        Get-NetNeighbor -ErrorAction Stop | Where-Object { $_.State -ne 'Unreachable' -and $_.IPAddress }
    }
    if ($arp) {
        $arp | Select-Object IPAddress, LinkLayerAddress, State, InterfaceAlias | Format-Table -AutoSize
    } else {
        Write-NTStatus -Message 'Aucun voisin ARP (ou timeout).' -Status INFO
    }

    Wait-NTKey
}

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU8cMTLQixm7ZT4XsQJUqWvXtI
# HXegggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUt/inOF8q7cUpZMPiKIpepMYEXOswDQYJKoZIhvcNAQEBBQAE
# ggEAqpDRgjjnd95S4SY1uiwSNqaeY1TzutQ6nEUH5nWPMXtommLk/jlSM87gopT2
# DUP+nqzdTxXf+0G7kX315CYlvQBgVQlVVKazSL1ZDtTPkA5p95yiSe2fOfcrzoO1
# g/ynhwKf42AakDYx8jFavZqeQybDC1lmg3+IpTE6FAaHUvl2B47OUXNh1hX6MVAM
# a3v4YuSlQZLgLYKdcDceAu4QToYF9Skp+vQRW6AReU2GxpRMTgg+F3sK/Q3gEhbj
# Pbw/WT3HQ2ky6rUsraRz6ZNTDY9kxvFV6kMXQ/wQczQ2T88HWXPA/VrTIDHrwiGM
# pTYjzNj8jz2z4fLAsLxIos5Ehg==
# SIG # End signature block

# SIG # Begin signature block
# MIIGPwYJKoZIhvcNAQcCoIIGMDCCBiwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUQu6+OckLeLCegQ9+r5zW5cmI
# AKGgggOUMIIDkDCCAnigAwIBAgIQO+7SyralWaVEZNPsB84DmDANBgkqhkiG9w0B
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
# hkiG9w0BCQQxFgQUTiMrXkyYl2xuJMQeD2ez/N/4J0swDQYJKoZIhvcNAQEBBQAE
# ggEAa8ZShG4m6F6OaCPp5u/4Wn6wgAJnhziRDh5HqoXQFQrFmhnNvdlrJmYUevIn
# hr6mab9HOWBVwsn+jIQvCdYiISeUJY/kw64fBPzTZVkhUPpqTrbG/NP95uwdibbd
# Uaoziw61tx2/XaWfMjnyIOamtwUjzLd3PlEl8Oi+zJ39RDr/Z5TjbaKKC0s7rL0+
# NalUy3VTcNQ6FiKwpOLdwJpLa3YwzD0z6YBvbzS48iepiWE5d4TxBWXv2wR3HqyI
# Tp+Ay8oA6GmAlnuATbCfaPaNbY0DIYfh1K4OG6+VTFVg0Z7u3derSOgKXtH7n9qY
# +PgRCWIsa6CS59Iwdmzrkqs4lw==
# SIG # End signature block
