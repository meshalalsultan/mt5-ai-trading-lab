# EXP-002 — تحليل السوق عبر أطر متعددة / Multi-timeframe analysis

**الحالة:** مغلقة بحدود — تحقق حسابي من R02؛ اللقطة الأصلية غير قابلة للإعادة.
**Date:** 2026-09-22. **Owner:** Meshal Al-Sultan.

[التقرير العربي التفصيلي](RESULTS.ar.md) · [البيانات ووصفها](../../assets/results/EXP002-R02/manifest.md)

## الهدف / Objective
Test whether a market-analysis assistant can retrieve closed candles, apply an explicit swing rule consistently across H4/H1/M15, and support conclusions with retained evidence.

## المنهج والفرضية
نختبر إمكانية إعادة الحساب، لا صحة توصية تداول. القمة أعلى من الشموع الثلاث السابقة واللاحقة، والقاع أدنى منها بمقارنة صارمة. أول وآخر ثلاث شموع غير مؤهلة. نقارن آخر قمتين وآخر قاعين داخل النافذة.

## Execution record
- A: operator-reported access to 100 closed candles per timeframe; timezone ambiguity recorded.
- B: operator-pasted analysis stated too few confirmed pivots and classified all frames inconclusive.
- C: self-audit corrected some descriptive errors but admitted the original arrays were unavailable. Original classifications remain unverified.
- R02: operator supplied a new retrieval as three CSV files and a manifest. Reviewer read those files directly and recalculated every eligible pivot plus complete overlapping OHLC aggregations.

Actual prompt submissions/model version and original arrays were not independently captured. Conversation prompts and pasted reports are not substitutes for raw tool logs.

## النتيجة
| Frame | High pivots | Low pivots | Classification under stated rule |
|---|---|---|---|
| H4 | 8 | 10 | Mixed structure (“range” in the rule) |
| H1 | 9 | 7 | Mixed structure (“range” in the rule) |
| M15 | 13 | 12 | Rising last confirmed highs and lows |

All files have 100 ordered unique rows and valid OHLC relationships. All 51 complete overlapping aggregation comparisons match; they are not statistically independent observations. Incomplete windows were excluded explicitly.

## What worked / ما نجح
Retained CSVs enabled direct verification, exact row references and file hashes. Complete overlapping aggregations were internally consistent.

## What failed / ما فشل
Original evidence was not preserved. B/C contained counting, field-label and interpretation errors. Self-audit did not establish a full pivot scan.

## Limits / الحدود
R02 is not proven identical to A. Timezone and broker session schedule remain unresolved. Internal consistency is not independent market-source authentication. Results describe this historical snapshot and rule only; they do not imply profitable trading or current market direction.

## Business value / القيمة المحتملة
An evidence-retention and human-review workflow for market-analysis education or brokerage research. No measured savings, customers or revenue claimed.

## Next / التالي
Day 3: trading-history and risk analysis. Because populated account history is unavailable, prepare a clearly labeled synthetic arithmetic exercise; it will not count as real-account validation. Strategy optimization remains deferred.
