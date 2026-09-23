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
| EXP-002 | Market and multi-timeframe analysis | Completed with limitations | Medium | Meshal Al-Sultan | 2026-09-22 | R02 report and data published |
| EXP-003 | History and risk: synthetic exercise | Completed with corrections | Medium | Meshal Al-Sultan | After EXP-002 | Arithmetic verified; see results |
| EXP-004 | [Margin analysis](experiments/EXP-004-margin-analysis/RESULTS.ar.md) | Completed educational scope with limitations | Medium | Meshal Al-Sultan | 2026-09-22 | Actual account margin remains unverified |
| EXP-005 | [Margin Call / Stop Out](experiments/EXP-005-margin-call/RESULTS.ar.md) | Completed synthetic scope with limitations | Medium | Meshal Al-Sultan | 2026-09-23 | Arithmetic verified; no actual liquidation |
| EXP-006 | [Indicator discovery](experiments/EXP-006-indicator-demo/README.md) | Completed adapted scope | Medium | Meshal Al-Sultan | After EXP-005 | Manual demo; see documented limitations |
| CS-001 | Account diagnostic case study | Backlog | Medium | Meshal Al-Sultan | After validation | Evaluate EXP-001 evidence |
| WEEK-01 | [Phase review](reports/weekly/WEEK-01.ar.md) | Completed | Medium | Meshal Al-Sultan | 2026-09-23 | Six scoped experiments reviewed |
| EXP-007 | [Signal specification](experiments/EXP-007-signal-specification/README.md) | Completed scoped review | Medium | Meshal Al-Sultan | Plan task 8 | No full trading strategy or MQL5 implementation |
| EXP-008 | [MQL5 indicator](experiments/EXP-008-mql5-indicator/README.md) | Today — Test A prepared | Medium | Meshal Al-Sultan | Plan task 9 | Review design and numeric policy before code |

## EXP-001 closeout

[Issue #1](https://github.com/meshalalsultan/mt5-ai-trading-lab/issues/1) tracks the scoped empty-input review.
[Findings](experiments/EXP-001-account-diagnostic/RESULTS.md) describe methodology, remaining errors and evidence limits.

- [x] Operator-supplied reports reviewed
- [x] Manual-check attestation distinguished from direct evidence
- [x] Failures and limitations documented
- [x] Daily log and register updated
- [ ] Original populated-history diagnostic hypothesis tested (deferred)

Completion refers to the adapted review, not full validation of diagnostic capability.
