# EXP-001 — Empty-input handling review

## Scope and outcome
**Status: Closed with limitations.** The original populated-history diagnostic hypothesis remains **inconclusive / not tested**.

The operator supplied assistant-generated reports for accessibility, empty-input handling and self-audit. This public note documents methodology and review findings only. It excludes financial values, account fields, broker details, identifiers, session timestamps and raw account reports.

## Protocol adaptation
The original v0.1 B/C protocol assumed usable trading history. Instead, an empty-input variant was supplied before B: do not invent performance metrics, do not infer trading behavior, distinguish funding from trading performance, and state missing inputs.
The targeted C variant requested claim classification, metric-specific requirements and correction of unsupported sample-size thresholds.
The original v0.1 prompt remains unchanged. The exact prompts actually submitted were not independently captured.

## Review findings
- B marked performance metrics not assessable and avoided unsupported behavioral conclusions.
- C removed unsupported universal sample-size thresholds and unnecessary universal SL/TP input requirements.
- C still incorrectly required both winners and losers for Profit Factor. Positive gross loss with zero gross profit gives PF zero; zero-denominator cases require explicit treatment.
- Historical equity reconstruction requires equity observations or adequate price/position/valuation data; trades and funding alone do not establish the floating P&L path.
- Requested query boundaries must not be presented as proof of observed coverage beyond retrieval time.
- Reported read-only actions do not prove that execution permissions were restricted.

Definitions: [MT5 testing report](https://www.metatrader5.com/en/terminal/help/algotrading/testing_report), [MT5 trading report](https://www.metatrader5.com/en/terminal/help/trading/report). These references support definitions, not execution claims.

## Evidence limits
The operator confirmed the expected empty-trading-input condition by a manual platform check. This is written operator attestation, not a screenshot, export or direct terminal inspection by this reviewer.
Assistant outputs were pasted into the conversation; raw MCP transcripts, reproducible input artifacts and the model/version were not supplied. Self-audit was not independent validation. No complete before/after error score was measured.

## Disposition
The scoped empty-input review is complete with documented limitations. It does not establish diagnostic accuracy on populated history or general model reliability.

## Business hypothesis
An empty-input precheck and human review may be useful in a diagnostic intake workflow or educational exercise. No customer outcome, time saving, demand or revenue is claimed.

## Next step
Continue the established Day 2 market/multi-timeframe roadmap. Strategy optimization remains deferred. Revisit populated-history diagnostics only when suitable authorized data is available; no trading is required to manufacture a dataset.
