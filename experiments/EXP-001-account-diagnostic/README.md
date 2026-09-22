# EXP-001 — Trading Account Diagnostic

**Planned date:** 2026-09-22

**Execution record:** Operator-reported outputs reviewed; exact execution metadata not publicly recorded.

**Owner:** Meshal Al-Sultan

**Status:** Closed with limitations — empty-input variant reviewed; populated-history hypothesis inconclusive.

**Results:** [Review findings and evidence limits](RESULTS.md). The original protocol below is retained for future populated-history work. It is not a claim that original B/C were executed verbatim.

**Prompt:** [ACCOUNT-DIAGNOSTIC v0.1](../../prompts/account-analysis/ACCOUNT-DIAGNOSTIC-v0.1.md)

## Objective
Determine which demo-account data the MT5 AI assistant can actually retrieve, whether its diagnostic conclusions are supported by that data, and whether self-audit removes unsupported claims.

## Business Use Case
Evaluate the feasibility of a reproducible account diagnostic workflow for broker client education and Mask Trader consulting. This is a service hypothesis, not a validated offering.

## Hypothesis
Given accessible, sufficiently complete demo history, the assistant can calculate basic activity/performance metrics and distinguish supported observations from uncertain patterns. Self-audit may reduce unsupported claims; this must be measured.

## Environment

| Field | Value |
|---|---|
| Actual execution timestamp / timezone | Not recorded |
| MT5 build / OS | Not recorded |
| AI provider / model / version | Not recorded; start with available MQL5 Lite if present |
| AI settings, enabled tools and permissions | Not recorded |
| Account type | Demo required |
| Account alias / currency | Not recorded; no real account ID |
| Hedging or netting | Not recorded |
| Broker/server timezone | Not recorded |
| Symbols / history start and end | Not recorded |
| Orders / deals / closed trades / open positions | Not recorded |
| Dataset ID / export / checksum | Not recorded |
| Known gaps / fees / deposits / withdrawals | Not recorded |

No particular build or model capability is assumed. If demo history is insufficient, mark the diagnostic test blocked or limited; do not generate trades as part of this protocol.

## Preparation

- [ ] Record environment and permissions; use read-only access where available.
- [ ] Choose a fixed history range and note open positions separately.
- [ ] Save an original export privately; create an anonymized derivative for published checks.
- [ ] Define trade grouping, breakeven treatment and included costs.
- [ ] Record input row counts and a stable dataset ID.
- [ ] Capture sanitized settings evidence.

## Test A — Data Accessibility

**Prompt**
```text
Inspect my demo trading account and trading history in read-only mode.
Do not place, modify or close trades, change settings, or provide recommendations.
First list exactly which account, position, order, deal and historical fields you can actually access.
For each item state: observed value or record count, data source/tool, time coverage, and unavailable fields.
Distinguish permissions from successful retrieval. Do not claim access without retrieved evidence.
Report account currency, timestamp and timezone if available. Do not expose account identifiers or credentials.
If access fails, describe the failure and request the minimum sanitized export needed. Do not invent data.
```

**Expected output:** a field/access matrix with actual retrieval evidence and coverage.
**Pass criterion:** each claimed accessible field is supported by a retrieved value/count and independently compared with the terminal/export; unavailable fields are explicitly identified.
**Actual response:** Operator-pasted reports reviewed; see [RESULTS.md](RESULTS.md). Raw artifacts are not published.

**Outcome:** See RESULTS.md for the adapted empty-input outcome; original full acceptance criteria were not established.

**Evidence:** Editorial findings and operator attestation described in RESULTS.md; no screenshot/export provided.

## Test B — Diagnostic Capability

Run after Test A establishes usable data; otherwise mark Blocked.

**Prompt**
```text
Perform a diagnostic analysis using only the demo-account data retrieved in Test A.
First state dataset coverage, counts, account currency, timezone, and how deals are grouped into closed trades.
Separate deposits/withdrawals from trading P&L; identify partial closes and commissions, swaps and fees.
Analyze total activity, wins/losses/breakeven outcomes, average profit/loss, position sizing, lot changes after losses, loss streaks, trading frequency, symbol and buy/sell performance, and trading-time patterns.
Assess drawdown, exposure and margin only where the required historical data exists. Closed-trade history alone does not establish historical equity drawdown, peak margin usage or stop-loss presence at entry.
Describe unusual sizing and possible overtrading as hypotheses, not diagnoses of motive or psychology.
Separate: (1) facts supported by data, (2) inferred patterns, (3) unknown or unreliable conclusions.
For each metric show its definition, source fields, sample count and calculation. Cite anonymized evidence IDs.
Do not invent missing information or make trading recommendations. Do not execute any account action.
```

**Expected output:** reproducible metric table plus facts/inferences/unknowns.
**Pass criterion:** activity counts match exactly; monetary metrics match independent calculations to the reported currency precision after identical cost/grouping rules. Every major conclusion has traceable support or is qualified/removed.
**Actual response:** Operator-pasted reports reviewed; see [RESULTS.md](RESULTS.md). Raw artifacts are not published.

**Outcome:** See RESULTS.md for the adapted empty-input outcome; original full acceptance criteria were not established.

**Evidence:** Editorial findings and operator attestation described in RESULTS.md; no screenshot/export provided.

## Test C — Self Audit

**Prompt**
```text
Audit your previous diagnostic analysis.
For each major conclusion list the claim, exact supporting data/evidence ID, calculation, assumptions, and whether it is a fact, inference or unknown.
Recalculate where possible. Remove or qualify unsupported conclusions, including psychological explanations and historical equity/margin claims without the necessary data.
Produce a corrected report and a change log showing retained, revised and removed claims.
List checks a human must perform independently. This self-audit is not independent validation.
Remain read-only and do not execute account actions.
```

**Expected output:** claim-to-evidence matrix, corrections and unresolved issues.
**Pass criterion:** all major claims are audited; unsupported claims are removed or qualified. A separate human comparison confirms the corrected report.
**Actual response:** Operator-pasted reports reviewed; see [RESULTS.md](RESULTS.md). Raw artifacts are not published.

**Outcome:** See RESULTS.md for the adapted empty-input outcome; original full acceptance criteria were not established.

**Evidence:** Editorial findings and operator attestation described in RESULTS.md; no screenshot/export provided.

## Independent validation

Use the same sanitized dataset and grouping rules to recalculate activity count, wins/losses/breakeven, net P&L including costs, average winning/losing trade, and symbol/direction totals. Record values in [validation.csv](validation.csv). Require symbol and direction totals to reconcile with overall totals.

Record zero-trade and zero-loss denominators as unavailable where appropriate. Do not equate orders, deals and completed positions. Define the comparison tolerance before evaluating output. If data cannot support a metric, mark Not assessable rather than Pass.

Count unsupported major claims before and after Test C. A smaller count is an observation in this run, not proof of reliability across accounts.

## Evidence
See [evidence index](evidence/README.md). Raw responses should be saved after execution with run ID, prompt version, timestamp and sanitization note.

## What Worked
Empty-input response avoided invented metrics and behavioral conclusions.
## What Failed
Self-audit left technical errors requiring external review; see RESULTS.md.
## Limitations
Access, history completeness, timezone, deal grouping and historical equity/margin availability remain unknown. Self-audit is not independent validation.
## Findings
Empty-input handling was reviewed; populated-history diagnostic accuracy remains untested. Evidence limits are explicit in RESULTS.md.
## Business Value
Hypothesis: reduce diagnostic preparation effort while retaining human review. Measure actual time and correction burden in a later comparison.
## Product Opportunity
Unvalidated concept: Mask Trader Account Diagnostic workflow and evidence-based prompt pack.
## Broker Application
Unvalidated concept: client diagnostic clinic and education demonstration using sanitized demo data.
## Next Experiment
Continue the established Day 2 market/multi-timeframe plan. Revisit the original diagnostic hypothesis only when suitable data is available.
## Closeout
- [x] Reported tests and limits of operator verification recorded.
- [x] Public methodological findings linked; raw account details excluded.
- [x] Daily log and experiment register updated; closeout tracked in issue #1.
- [x] Inconclusive for the original hypothesis; adapted empty-input review completed with limitations.
