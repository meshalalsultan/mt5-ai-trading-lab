# EXP-004 — تحليل الهامش / Margin analysis
Date: 2026-09-22  
Status: Closed educational scope with corrections and limitations.

[النتائج والتصحيحات بالعربية](RESULTS.ar.md)

## Objective / الهدف
اختبار قدرة المساعد على اكتشاف مدخلات الهامش الناقصة وشرح نموذج حسابي دون اختلاق إعدادات أو تنفيذ تداول.

## Hypothesis
The assistant can distinguish reported platform fields from assumptions, compute a declared synthetic margin model, and constrain its conclusions.

## Environment and evidence
Operator-supplied MT5 MCP reports for Test A; synthetic inputs only for B/C. Raw platform logs and actual margin-calculator output are unavailable. Model/version and exact original prompt text are not retained here.

## Tests and outcome
- A: Reported access to symbol/account specifications; leverage and directional rates unavailable. Actual margin validation remains inconclusive.
- B: Four synthetic cases computed: USD 40, 400, 800, 600.
- C: Self-audit followed by separate arithmetic review. Arithmetic passed; terminology and liquidation/cost generalizations corrected.

## Business use case
Broker education about margin inputs, units and limits of AI explanations. Potential teaching material, not a validated commercial product.

## Scope
No claim of verified account margin, portfolio margin, liquidation risk or strategy performance. See the Arabic report for reproducible inputs and limitations.

Next: EXP-005 Margin Call / Stop Out educational investigation, not yet executed.
