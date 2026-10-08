# AGENTS.md — IT Admin Scripts

These instructions apply to the entire repository, including contributions made by AI coding agents.

## Purpose and scope

Maintain trustworthy, reusable **PowerShell tools** for Microsoft 365, Exchange Online, Entra ID, Intune, Windows and general IT administration. Prefer straightforward, auditable scripts over unnecessary frameworks.

## Mandatory PowerShell standards

- Each `.ps1` file **MUST** provide accurate comment-based help: `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.NOTES`, and `.PARAMETER` for every public parameter. Add `.OUTPUTS` and `.LINK` where useful.
- Use approved Verb-Noun names (for example `Get-EXOEwsInventory.ps1`), PascalCase for parameters, and readable, descriptive variables.
- Declare the supported PowerShell version explicitly; support Windows PowerShell 5.1 when required by the scenario, and PowerShell 7 when compatible. Never change runtime requirements silently.
- Document required modules, privileges/roles, relevant API permissions, impact (read-only versus modifying), limitations, and usage examples.
- Prefer supported Microsoft cmdlets/APIs, avoid new dependencies on deprecated interfaces, and do not invent unverified behavior or output.
- Provide meaningful console status for operator-facing scripts; use pipeline output for machine-readable objects and `Write-Verbose` for detailed diagnostics.

## Safety and customer data

- Prefer **read-only** scripts. Changes to tenants, users, devices, policies or access MUST be clearly documented and gated by explicit intent; use `SupportsShouldProcess` (`-WhatIf`/`-Confirm`) where appropriate.
- Do not automatically change access controls, reduce security protections or install dependencies to work around errors.
- Never commit customer exports, tenant identifiers, domains, usernames, mailboxes, credentials, tokens, secrets or private logs. Examples must use fictional data such as `contoso.com`.
- Use least privilege; no hardcoded environment-specific values. Keep report paths and tenant names configurable; sanitize filesystem names.
- Treat reports as potentially sensitive metadata. Prefer aggregation to exporting personal data.
- Do not upload or print real customer data in tests, PR descriptions or documentation.

## Reliability and error handling

- Use `[CmdletBinding()]`, validation and predictable parameter defaults where appropriate.
- Stop on critical errors and surface noncritical collection failures distinctly from a genuine empty result.
- Use `try/catch/finally` for connections and resource cleanup. Avoid swallowing exceptions without an actionable warning.
- Do not claim that a live tenant was tested unless it was. Keep scripts idempotent where feasible.
- Do not introduce interactive prompts unless needed for authorization or a dangerous operation.

## Structure and documentation

- Place each script in its appropriate topic folder: `ExchangeOnline/`, `EntraID/`, `Intune/`, `Microsoft365/`, `Windows/` or `Utilities/`.
- Update the root README and relevant topic README whenever a script is added, moved, or its public behavior changes.
- Include executable examples, requirements, expected output locations, impact, and limitations in the topic README.
- Avoid committing output artifacts (CSV, logs, diagnostic dumps). Respect `.gitignore`.

## Checks required for every PR

1. Parse every changed PowerShell file; fix all parser errors.
2. Run PSScriptAnalyzer, fix blocking diagnostics, and document any warning that cannot reasonably be eliminated.
3. Verify comment-based help and examples, and cross-check paths and parameter names.
4. Review permissions, customer data leakage risks, and the difference between read-only and modifying operations.
5. Record what was actually tested and what remains untested. Never invent test results.

The `PowerShell quality` GitHub Actions workflow provides a baseline automatic check. It cannot replace testing with representative services and permissions.