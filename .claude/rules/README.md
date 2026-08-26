# rules/
Path-scoped conventions. Each file uses frontmatter `globs:` so it only loads
when Claude touches matching paths — cheaper than putting everything in CLAUDE.md.

Example (`scoring.md`):
---
globs: ["apps/risk_scorer/**"]
---
- All scoring outputs are `RiskScore` objects; never raw floats.
- Feature computation lives only in feature_engine.py.
