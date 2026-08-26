---
globs: [".github/workflows/**"]
---
# CI supply-chain (always relevant when workflow files are touched)
- Third-party GitHub Actions (anything not under `actions/`) must be
  SHA-pinned with a trailing `# vX.Y.Z` comment, not left on a mutable tag —
  same reasoning as `mcp-governance.md`'s MCP-server rule: a tag can be
  repointed without the workflow diff showing it.
- Adding or re-pinning a third-party Action => new ADR (`docs/adr/`) that
  records: how the SHA was resolved (a reproducible command, not just
  "checked the API"), whether the pinned version is current or a currency
  trade-off is being made deliberately, and the failure mode if the pin
  ever fails to resolve (which job breaks, how it presents, how to revert).
- First-party `actions/*` Actions may stay tag-pinned (`@v4`, `@v5`) —
  lower supply-chain risk, same posture GitHub itself uses in its own
  starter workflows. This is a deliberate, narrower bar than third-party.
