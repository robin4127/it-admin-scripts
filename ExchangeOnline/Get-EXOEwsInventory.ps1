#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only inventarisatie van Exchange Online EWS- en agenda-uitwisseling.
.DESCRIPTION
    Toont direct een consoleoverzicht en exporteert CSV's naar
    C:\Temp\<Organisatie>_EXO-EWS_yyyyMMdd_HHmmss.
    Er worden geen wijzigingen in de Exchange Online-configuratie gedaan.
    Een inventarisatie toont configuratie, niet daadwerkelijk gebruik.
.PARAMETER OrganizationName
    Optional display name override for the organization and report directory.
    Defaults to the organization name returned by Exchange Online.
.PARAMETER OutputRoot
    Parent directory for CSV exports. Defaults to C:\Temp.
.EXAMPLE
    .\Get-EXOEwsInventory.ps1
.EXAMPLE
    .\Get-EXOEwsInventory.ps1 -OrganizationName 'Contoso'
.EXAMPLE
    .\Get-EXOEwsInventory.ps1 -OutputRoot 'D:\Inventarisaties'
.NOTES
    Version: 0.1.0
    Requirements: ExchangeOnlineManagement and appropriate Exchange read permissions.
    PowerShell: Windows PowerShell 5.1 or compatible PowerShell 7.
    Impact: Read-only for Exchange Online; creates local CSV reports.
    Limitations: Reports configuration, not actual EWS traffic or active sharing.
    Privacy: Reports may include tenant domains and configuration identifiers.
#>
[CmdletBinding()]
param(
    [string]$OrganizationName,
    [string]$OutputRoot = 'C:\Temp'
)

$ErrorActionPreference = 'Stop'
$issues = [System.Collections.Generic.List[string]]::new()

function Export-InventoryCsv {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Columns,
        [AllowEmptyCollection()][object[]]$Rows = @()
    )

    $path = Join-Path -Path $folder -ChildPath $FileName
    if (@($Rows).Count -gt 0) {
        $Rows | Select-Object -Property $Columns |
            Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
    } else {
        # Ook bij 0 resultaten een geldige CSV met kolomkoppen bewaren.
        ($Columns | ForEach-Object { '"' + ($_ -replace '"', '""') + '"' }) -join ',' |
            Set-Content -LiteralPath $path -Encoding UTF8
    }
}

Write-Host "`nExchange Online | EWS & Cross-Tenant Inventory" -ForegroundColor Cyan
Write-Host ('-' * 59)

Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop

try {
    $config = Get-OrganizationConfig -ErrorAction Stop

    # Geen tweede Entra/Graph-login nodig. Handmatige naam blijft optioneel.
    $nameCandidates = @($OrganizationName, $config.DisplayName, $config.Name, [string]$config.Identity)
    $orgName = $nameCandidates |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
        Select-Object -First 1
    if (-not $orgName) { $orgName = 'OnbekendeOrganisatie' }

    # Windows-onveilige tekens verwijderen; mapnaam beheersbaar houden.
    $safeName = ([string]$orgName -replace '[<>:"/\\|?*\x00-\x1F]', '_').Trim(' ', '.')
    if (-not $safeName) { $safeName = 'OnbekendeOrganisatie' }
    if ($safeName.Length -gt 60) { $safeName = $safeName.Substring(0, 60).Trim(' ', '.') }

    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    $folder = Join-Path -Path $OutputRoot -ChildPath (
        '{0}_EXO-EWS_{1}' -f $safeName, (Get-Date -Format 'yyyyMMdd_HHmmss')
    )
    New-Item -ItemType Directory -Path $folder -Force | Out-Null

    Write-Host "Organisatie : $orgName"
    Write-Host "Exportmap   : $folder"
    Write-Host "Opgehaald   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    # 1. Organization Relationships
    $relationships = @()
    try {
        $relationships = @(Get-OrganizationRelationship -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                Name                  = [string]$_.Name
                DomainNames           = ($_.DomainNames -join ';')
                Enabled               = $_.Enabled
                FreeBusyAccessEnabled = $_.FreeBusyAccessEnabled
                FreeBusyAccessLevel   = [string]$_.FreeBusyAccessLevel
                FreeBusyAccessScope   = [string]$_.FreeBusyAccessScope
                MailTipsAccessEnabled = $_.MailTipsAccessEnabled
                TargetSharingEpr      = [string]$_.TargetSharingEpr
                TargetAutodiscoverEpr = [string]$_.TargetAutodiscoverEpr
                TargetApplicationUri  = [string]$_.TargetApplicationUri
            }
        })
    } catch {
        $issues.Add("Organization Relationships niet opgehaald: $($_.Exception.Message)")
    }
    Export-InventoryCsv -FileName 'OrganizationRelationships.csv' -Rows $relationships -Columns @(
        'Name','DomainNames','Enabled','FreeBusyAccessEnabled','FreeBusyAccessLevel',
        'FreeBusyAccessScope','MailTipsAccessEnabled','TargetSharingEpr',
        'TargetAutodiscoverEpr','TargetApplicationUri'
    )

    # 2. Availability Address Spaces
    $addressSpaces = @()
    try {
        $addressSpaces = @(Get-AvailabilityAddressSpace -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                ForestName            = [string]$_.ForestName
                AccessMethod          = [string]$_.AccessMethod
                TargetTenantId        = [string]$_.TargetTenantId
                TargetAutodiscoverEpr = [string]$_.TargetAutodiscoverEpr
                TargetServiceEpr      = [string]$_.TargetServiceEpr
            }
        })
    } catch {
        $issues.Add("Availability Address Spaces niet opgehaald: $($_.Exception.Message)")
    }
    Export-InventoryCsv -FileName 'AvailabilityAddressSpaces.csv' -Rows $addressSpaces -Columns @(
        'ForestName','AccessMethod','TargetTenantId','TargetAutodiscoverEpr','TargetServiceEpr'
    )

    # 3. Sharing Policies
    $policies = @()
    try {
        $policies = @(Get-SharingPolicy -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                Name    = [string]$_.Name
                Enabled = $_.Enabled
                Default = $_.Default
                Domains = ($_.Domains -join ';')
            }
        })
    } catch {
        $issues.Add("Sharing Policies niet opgehaald: $($_.Exception.Message)")
    }
    Export-InventoryCsv -FileName 'SharingPolicies.csv' -Rows $policies -Columns @(
        'Name','Enabled','Default','Domains'
    )

    # 4. Mailbox-toewijzingen (alleen aantallen, geen persoonsgegevens)
    $usage = @()
    try {
        $usage = @(Get-EXOMailbox -ResultSize Unlimited `
            -RecipientTypeDetails UserMailbox,SharedMailbox `
            -Properties SharingPolicy -ErrorAction Stop |
            Group-Object -Property SharingPolicy | ForEach-Object {
                [pscustomobject]@{
                    SharingPolicy = if ([string]::IsNullOrWhiteSpace($_.Name)) {
                        '(Standaardpolicy / niet expliciet ingesteld)'
                    } else { $_.Name }
                    Count = $_.Count
                }
            })
    } catch {
        $issues.Add("Sharing Policy-mailboxgebruik niet opgehaald: $($_.Exception.Message)")
    }
    Export-InventoryCsv -FileName 'SharingPolicyUsage.csv' -Rows $usage -Columns @(
        'SharingPolicy','Count'
    )

    # 5. EWS-configuratie en AppID-allowlist
    $ewsEnabled = if ($null -eq $config.EwsEnabled) {
        'Niet expliciet ingesteld'
    } elseif ($config.EwsEnabled -eq $true) {
        'True'
    } else {
        'False'
    }

    $appIdState = 'Opgehaald'
    $appIds = @()
    try {
        $ewsPolicy = Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy -ErrorAction Stop
        $appIds = @($ewsPolicy.EwsAllowedAppIDs | Where-Object { $_ })
    } catch {
        $appIdState = 'Niet opgehaald'
        $issues.Add("EWS AppID-allowlist niet opgehaald: $($_.Exception.Message)")
    }

    $ewsRows = @([pscustomobject]@{
        EwsEnabled        = $ewsEnabled
        EwsAllowedAppIDs  = ($appIds -join ';')
        AllowListReadState = $appIdState
    })
    Export-InventoryCsv -FileName 'EwsConfiguration.csv' -Rows $ewsRows -Columns @(
        'EwsEnabled','EwsAllowedAppIDs','AllowListReadState'
    )

    # Direct leesbaar overzicht in de console
    Write-Host "`n1. ORGANIZATION RELATIONSHIPS ($($relationships.Count))" -ForegroundColor Cyan
    if ($relationships.Count -eq 0) {
        Write-Host '  Geen relaties gevonden (of ophalen mislukt; zie waarschuwingen).'
    }
    foreach ($r in $relationships) {
        $color = if ($r.Enabled -and ($r.FreeBusyAccessEnabled -or $r.MailTipsAccessEnabled)) {
            'Yellow'
        } else { 'Gray' }
        Write-Host "  - $($r.Name)" -ForegroundColor $color
        Write-Host "    Domeinen  : $($r.DomainNames)"
        Write-Host "    Enabled   : $($r.Enabled) | Free/Busy: $($r.FreeBusyAccessEnabled) ($($r.FreeBusyAccessLevel)) | MailTips: $($r.MailTipsAccessEnabled)"
    }

    Write-Host "`n2. AVAILABILITY ADDRESS SPACES ($($addressSpaces.Count))" -ForegroundColor Cyan
    if ($addressSpaces.Count -eq 0) {
        Write-Host '  Geen address spaces gevonden (of ophalen mislukt; zie waarschuwingen).'
    }
    foreach ($a in $addressSpaces) {
        Write-Host "  - $($a.ForestName) | $($a.AccessMethod) | Tenant: $($a.TargetTenantId)"
    }

    Write-Host "`n3. SHARING POLICIES ($($policies.Count))" -ForegroundColor Cyan
    if ($policies.Count -eq 0) {
        Write-Host '  Geen sharing policies gevonden (of ophalen mislukt; zie waarschuwingen).'
    }
    foreach ($p in $policies) {
        Write-Host "  - $($p.Name) | Enabled: $($p.Enabled) | Default: $($p.Default)"
        Write-Host "    Domeinen/rechten: $($p.Domains)"
    }

    Write-Host "`n4. MAILBOXEN PER SHARING POLICY" -ForegroundColor Cyan
    if ($usage.Count -eq 0) {
        Write-Host '  Geen mailboxgegevens gevonden (of ophalen mislukt; zie waarschuwingen).'
    }
    foreach ($u in $usage) {
        Write-Host "  - $($u.SharingPolicy): $($u.Count) mailboxen"
    }

    Write-Host "`n5. EWS-CONFIGURATIE" -ForegroundColor Cyan
    Write-Host "  EwsEnabled       : $ewsEnabled"
    Write-Host "  Allowlist-status : $appIdState"
    Write-Host "  AppIDs           : $($appIds.Count) geretourneerd"
    if ($appIds.Count -gt 0) { Write-Host "  AppID-lijst      : $($appIds -join '; ')" }

    $activeRel = @($relationships | Where-Object {
        $_.Enabled -and ($_.FreeBusyAccessEnabled -or $_.MailTipsAccessEnabled)
    })
    $orgWide = @($addressSpaces | Where-Object { $_.AccessMethod -eq 'OrgWideFBToken' })
    Write-Host "`nAANDACHTSPUNTEN" -ForegroundColor Yellow
    if ($activeRel.Count -gt 0) {
        Write-Host "  - $($activeRel.Count) actieve relatie(s) met Free/Busy en/of MailTips: controleer of de externe tenant M365 is."
    }
    if ($orgWide.Count -gt 0) {
        Write-Host "  - $($orgWide.Count) address space(s) met OrgWideFBToken: beoordeel bij migratie."
    }
    if (@($policies | Where-Object { $_.Enabled }).Count -gt 0) {
        Write-Host '  - Sharing Policies gevonden: controleer of externe uitnodigingen werkelijk gebruikt worden.'
    }
    if ($ewsEnabled -eq 'Niet expliciet ingesteld') {
        Write-Host '  - EwsEnabled is null: dit is NIET gelijk aan expliciet ingeschakeld of uitgeschakeld.'
    }
    Write-Host '  - Controleer EWS-appgebruik apart; deze inventarisatie bewijst geen feitelijk gebruik.'

    if ($issues.Count -gt 0) {
        Write-Host "`nWAARSCHUWINGEN ($($issues.Count))" -ForegroundColor Red
        foreach ($issue in $issues) { Write-Host "  - $issue" -ForegroundColor Red }
    }

    $mailboxCount = 0
    foreach ($u in $usage) { $mailboxCount += [int]$u.Count }
    $summary = @([pscustomobject]@{
        Organization          = [string]$orgName
        CollectedAt           = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Relationships         = $relationships.Count
        ActiveRelationships   = $activeRel.Count
        AvailabilitySpaces    = $addressSpaces.Count
        SharingPolicies       = $policies.Count
        MailboxesChecked      = $mailboxCount
        EwsEnabled            = $ewsEnabled
        EwsAppIdsReturned     = $appIds.Count
        RetrievalWarnings     = $issues.Count
    })
    Export-InventoryCsv -FileName 'Summary.csv' -Rows $summary -Columns @(
        'Organization','CollectedAt','Relationships','ActiveRelationships',
        'AvailabilitySpaces','SharingPolicies','MailboxesChecked',
        'EwsEnabled','EwsAppIdsReturned','RetrievalWarnings'
    )

    Write-Host "`nKLAAR - 6 CSV-bestanden in: $folder" -ForegroundColor Green
    Write-Host 'Let op: read-only tenantconfiguratie; geen automatische migratiebeslissing.'
} finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}