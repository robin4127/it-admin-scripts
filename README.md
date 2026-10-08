# IT Admin Scripts

A curated collection of reusable PowerShell tools for Microsoft 365, Exchange Online, Entra ID, Intune, Windows and general IT administration.

> **Review scripts before running them.** Execute with the minimum permissions required. Scripts are provided as operational tools, not as guaranteed safe changes for every tenant.

## Scripts

| Category | Script | Purpose | Impact |
| --- | --- | --- | --- |
| Exchange Online | [Get-EXOEwsInventory.ps1](ExchangeOnline/Get-EXOEwsInventory.ps1) | Inventory Exchange Online organization relationships and EWS settings. | Read-only tenant access; creates local reports. |
| Exchange Online | [Test-M365SmtpRelay.ps1](ExchangeOnline/Test-M365SmtpRelay.ps1) | Test SMTP submission, STARTTLS, negotiated TLS protocol and cipher. | Plain mode sends a real test email; STARTTLS defaults to handshake-only. |

For requirements, commands, expected output and limitations, see the [Exchange Online documentation](ExchangeOnline/README.md).

## Quick start

Clone the repository, inspect the script, then run it from PowerShell:

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
.\ExchangeOnline\Get-EXOEwsInventory.ps1
```

The inventory script uses interactive Exchange Online sign-in and writes reports to `C:\Temp` by default. Supply `-OutputRoot` to use a different location.

To download just the script after this PR is merged: [view source](ExchangeOnline/Get-EXOEwsInventory.ps1) or [download raw file](https://raw.githubusercontent.com/robin4127/it-admin-scripts/main/ExchangeOnline/Get-EXOEwsInventory.ps1). Avoid piping remotely downloaded code straight into execution.

## Layout

- `ExchangeOnline/` — Exchange Online configuration and reporting
- `EntraID/` — Microsoft Entra ID
- `Intune/` — Microsoft Intune and endpoint management
- `Microsoft365/` — Cross-service Microsoft 365 utilities
- `Windows/` — Windows administration
- `Utilities/` — General-purpose tools
- `.github/` — Automated quality checks

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md). New scripts require comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, parameter documentation, examples and notes. Pull requests undergo static quality checks.

## Security and privacy

This repository must not contain customer-specific CSV reports, email addresses, tenant settings exports, credentials, private keys or access tokens. Inventory results may reveal internal configuration and should be stored and shared according to your organization's policies.

**Testing:** The Exchange Online script has been run manually in one tenant as reported by its operator; automated live-service verification is not performed by this repository's GitHub Actions workflow.