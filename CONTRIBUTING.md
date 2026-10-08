# Contributing

Changes are welcome via pull requests. Keep each PR focused and reviewable.

## Before opening a PR

1. Place scripts under the appropriate category folder and use approved PowerShell Verb-Noun naming.
2. Include `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.NOTES` and `.PARAMETER` entries for all public parameters. Explain required roles, modules, side effects and limitations.
3. Default to read-only behavior; modifying scripts should use `SupportsShouldProcess` where practical and avoid hidden changes.
4. Update the root and topic README with usage examples and impact.
5. Run the CI quality checker locally if PowerShell is available:

   ```powershell
   Install-Module PSScriptAnalyzer -Scope CurrentUser
   .\.github\scripts\Test-PowerShellQuality.ps1
   ```

6. Review for secrets and customer-specific configuration data. Do not commit CSV exports or logs.
7. Describe tests actually performed, affected products and outstanding limitations in your PR.

## Pull request checklist

- [ ] Documentation and examples match the actual script.
- [ ] Public parameters documented and validated as appropriate.
- [ ] Read-only/change impact explicitly stated.
- [ ] Security/privacy review completed; no customer data committed.
- [ ] Static checks completed, or known issues explained.
- [ ] Live-service behavior clearly marked as tested or not tested.

`AGENTS.md` describes the detailed standards used by AI coding assistants.