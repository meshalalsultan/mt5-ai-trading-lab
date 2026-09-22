# ACCOUNT-DIAGNOSTIC — v0.1

- Status: Draft — not executed
- Created: 2026-09-22
- Author: Meshal Al-Sultan
- Experiment: [EXP-001](../../experiments/EXP-001-account-diagnostic/README.md)
- Required inputs: demo environment, fixed history range, recorded timezone, known permissions and sanitized evidence IDs.
- Model and settings: record at execution.
- Output contract: access matrix, diagnostic metric table, facts/inferences/unknowns, claim audit.
- Guardrails: read-only; no trade actions; no invented data; no account identifiers.
- Run sequentially in the same session; archive all responses and independent validation.

## Test A
```text
Inspect my demo trading account and trading history in read-only mode.
Do not place, modify or close trades, change settings, or provide recommendations.
First list exactly which account, position, order, deal and historical fields you can actually access.
For each item state: observed value or record count, data source/tool, time coverage, and unavailable fields.
Distinguish permissions from successful retrieval. Do not claim access without retrieved evidence.
Report account currency, timestamp and timezone if available. Do not expose account identifiers or credentials.
If access fails, describe the failure and request the minimum sanitized export needed. Do not invent data.
```
## Test B
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
## Test C
```text
Audit your previous diagnostic analysis.
For each major conclusion list the claim, exact supporting data/evidence ID, calculation, assumptions, and whether it is a fact, inference or unknown.
Recalculate where possible. Remove or qualify unsupported conclusions, including psychological explanations and historical equity/margin claims without the necessary data.
Produce a corrected report and a change log showing retained, revised and removed claims.
List checks a human must perform independently. This self-audit is not independent validation.
Remain read-only and do not execute account actions.
```

## Version history
| Version | Date | Change | Evaluation |
|---|---|---|---|
| v0.1 | 2026-09-22 | Initial three-step protocol with provenance and independent checks | Not tested |

## Known limitations
Access and calculation quality are unverified. Prompts do not enforce platform permissions. Do not interpret self-audit as independent evidence.
