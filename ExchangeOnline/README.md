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

---

## Test-M365SmtpRelay.ps1

Anonymous SMTP/25 diagnostic for a Microsoft 365 MX endpoint. Its modes **Plain**, **StartTls**, and **Both** run independently. STARTTLS reports the negotiated TLS protocol and, where available on the local .NET runtime, the cipher suite.

### Requirements

- Windows PowerShell 5.1 or PowerShell 7; outbound TCP/25.
- `Resolve-DnsName` for MX discovery or an explicitly specified `-SmtpServer`.
- No Microsoft 365 admin privileges; test sender and recipient must be authorized.

### Examples

```powershell
# Original test: sends one message without TLS.
.\ExchangeOnline\Test-M365SmtpRelay.ps1

# TLS handshake only (NO email sent).
.\ExchangeOnline\Test-M365SmtpRelay.ps1 -Mode StartTls -Sender 'scanner@contoso.com'

# Send one plaintext message and test TLS in a second connection.
.\ExchangeOnline\Test-M365SmtpRelay.ps1 -Mode Both -Sender 'scanner@contoso.com' -Recipient 'test@example.net'

# Send a test message AFTER STARTTLS negotiation.
.\ExchangeOnline\Test-M365SmtpRelay.ps1 -Mode StartTls -SendAfterTls -Sender 'scanner@contoso.com' -Recipient 'test@example.net'

Get-Help .\ExchangeOnline\Test-M365SmtpRelay.ps1 -Full
```

Use `-SmtpServer` if the domain's external MX is a third-party filtering provider; supply a *verified* Microsoft 365 hostname.

### Read results carefully

- **TLS details are from the test computer, NOT the printer.** A successful workstation STARTTLS handshake does not prove that printer firmware supports the same protocol/cipher. Check device settings, firmware, logs or a device-side capture for that.
- A successful message submission to an *internal* recipient may be Direct Send. It does not prove connector-based relay to external addresses; test with an authorized external recipient and corroborate with message trace and connector settings.
- Sending uses the source IP of the workstation's connection, which can differ from the printer's egress IP.
- `Plain` sends an unencrypted SMTP message; `StartTls` does not send until explicitly requested with `-SendAfterTls`. `Both -SendAfterTls` sends two test messages.
- The script uses standard certificate and hostname validation for STARTTLS, does not authenticate, and does not verify final delivery.
- This script was **not independently tested against a live Exchange Online SMTP endpoint** as part of this PR. GitHub Actions only validates syntax, help, and static issues.

Microsoft: [How to set up a multifunction device to send email using Microsoft 365](https://learn.microsoft.com/en-us/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-microsoft-365-or-office-365).
