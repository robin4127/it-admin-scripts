# Exchange Online

## Get-EXOEwsInventory.ps1

Read-only inventory of Exchange Online settings relevant to EWS and cross-tenant availability/sharing. This is a **configuration inventory**, **not** proof of ongoing EWS usage or a definitive migration assessment.

### Prerequisites

- Windows PowerShell 5.1 or compatible PowerShell 7.
- [ExchangeOnlineManagement](https://learn.microsoft.com/en-us/powershell/exchange/connect-to-exchange-online-powershell).
- Exchange permissions to read organization configuration, Organization Relationships, Sharing Policies and mailbox properties.
- Local permissions to create the export directory.

### Usage

```powershell
# Install only when needed:
Install-Module ExchangeOnlineManagement -Scope CurrentUser

# Run from the repository root:
.\ExchangeOnline\Get-EXOEwsInventory.ps1

# Optional name/path overrides:
.\ExchangeOnline\Get-EXOEwsInventory.ps1 -OrganizationName 'Contoso' -OutputRoot 'D:\Reports'

# Help:
Get-Help .\ExchangeOnline\Get-EXOEwsInventory.ps1 -Full
```

### Collected information

1. Organization Relationships (Free/Busy, MailTips, domains and relevant endpoints).
2. Availability Address Spaces.
3. Sharing Policies.
4. Mailbox counts per sharing policy (no individual mailbox addresses).
5. EWS enabled status and allowed AppIDs (when retrievable).
6. Overall summary and retrieval warning count.

The script displays an operator-friendly console summary and creates six CSV files in an organization-specific timestamped folder:

```text
C:\Temp\Contoso_EXO-EWS_20261008_113734\
  OrganizationRelationships.csv
  AvailabilityAddressSpaces.csv
  SharingPolicies.csv
  SharingPolicyUsage.csv
  EwsConfiguration.csv
  Summary.csv
```

### Interpretation and limitations

- An Organization Relationship or Sharing Policy **does not prove active use**, that a partner is an Exchange Online tenant, or that migration is required.
- Null `EwsEnabled` means **not explicitly configured**, not that EWS is definitely enabled or disabled.
- An empty allowlist does not mean there are no EWS-dependent applications.
- Compare inventory data against actual EWS usage reports and confirm any external dependencies with partner administrators.
- Failed retrievals are reported as warnings; a reported count of zero can be an incomplete result.
- CSV files contain potentially sensitive configuration metadata: keep them in customer-approved storage, not GitHub.
- Operator reports one successful execution in one tenant. No additional live-tenant verification has been performed.

### Reference

[Microsoft: Migrate to Microsoft 365 Cross-Tenant Access Policies](https://learn.microsoft.com/en-us/exchange/sharing/migrate-to-m365-xtap)
