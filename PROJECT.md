# Execution board

This file is the usable project-board fallback. A live GitHub Project is not claimed.

Columns: **Backlog → Today → Testing → Documenting → Product Candidate → Completed**.
Product Candidate is optional; completed research need not become a product.
Move an item into Testing when execution starts, Documenting when outputs exist, and Completed only after the workflow checklist is met.

Suggested fields: ID, owner, status, priority, target date, experiment link, evidence, next action.
Suggested labels (create when needed): experiment, documentation, prompt, mql5, case-study, product-candidate, blocked.

| ID | Task | Status | Priority | Owner | Target | Next action |
|---|---|---|---|---|---|---|
| EXP-001 | Trading Account Diagnostic | Completed with limitations | High | Meshal Al-Sultan | 2026-09-22 | Empty-input review complete; original hypothesis deferred |
| EXP-002 | Market and multi-timeframe analysis | Backlog | Medium | Meshal Al-Sultan | After EXP-001 review | Define hypothesis |
| CS-001 | Account diagnostic case study | Backlog | Medium | Meshal Al-Sultan | After validation | Evaluate EXP-001 evidence |
| WEEK-01 | Weekly research review | Backlog | Medium | Meshal Al-Sultan | Day 7 | Aggregate daily logs |

## EXP-001 closeout

[Issue #1](https://github.com/meshalalsultan/mt5-ai-trading-lab/issues/1) tracks the scoped empty-input review.
[Findings](experiments/EXP-001-account-diagnostic/RESULTS.md) describe methodology, remaining errors and evidence limits.

- [x] Operator-supplied reports reviewed
- [x] Manual-check attestation distinguished from direct evidence
- [x] Failures and limitations documented
- [x] Daily log and register updated
- [ ] Original populated-history diagnostic hypothesis tested (deferred)

Completion refers to the adapted review, not full validation of diagnostic capability.
