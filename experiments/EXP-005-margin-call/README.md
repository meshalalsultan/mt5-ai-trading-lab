# EXP-005 — Margin Call / Stop Out
Date: 2026-09-23  
Status: Completed synthetic educational scope with terminology corrections and limitations.

[التقرير العربي الكامل](RESULTS.ar.md)

## Objective
Evaluate whether the assistant correctly computes margin snapshots, handles threshold equality and separates a Stop Out condition from executed liquidation.

## Evidence and method
User-supplied A/B/C responses; a declared synthetic fixture only. Separate arithmetic recomputation verified five snapshots and 15 identities. No platform calls, account exports or broker execution validation are claimed.

## Outcome
S3 is the first supplied warning snapshot (100%); S5 is the first supplied Stop Out-condition snapshot (50%). Negative free margin alone is insufficient under these rules. Balance remains 1000 USD; no realized closure is modeled.

## Business use
Potential broker-education exercise, not a validated commercial service. Full assumptions, reproducible inputs and limitations are in the Arabic report.

Next: EXP-006 indicator capability discovery and demonstration; execution results pending.
