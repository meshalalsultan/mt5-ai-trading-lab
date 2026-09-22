# EXP002-R02 — Public data manifest / وصف البيانات المنشورة

هذه إعادة استرجاع للتحقق، وليست لقطة Test A الأصلية المفقودة. لا توجد مقارنة تثبت تطابقهما الكامل. الملفات تحتوي أسعار شموع فقط؛ أزيلت مسارات الجهاز من هذا الوصف العام.

- Symbol: XAUUSD.
- Source reported by operator: MetaTrader 5 MCP get_chart_history.
- Retrieval reported: 2026-09-22T12:08:21Z.
- Timestamp meaning: candle opening time as returned; timezone unresolved. No timezone conversion applied.
- datetime_from inclusive / datetime_to exclusive, according to supplied manifest.
- Original export inputs and counts:

| File | From (inclusive) | To (exclusive) | Rows |
|---|---|---|---|
| xauusd_h4.csv | 2026-08-28T20:00:00 | 2026-09-22T12:00:00 | 100 |
| xauusd_h1.csv | 2026-09-16T06:00:00 | 2026-09-22T14:00:00 | 100 |
| xauusd_m15.csv | 2026-09-21T12:00:00 | 2026-09-22T14:00:00 | 100 |

Columns: symbol,timeframe,time,open,high,low,close.
The original manifest reported no hashes; the reviewer computed the following from the supplied files:

| File | SHA-256 |
|---|---|
| xauusd_h4.csv | DB16218E45AE452108777F57852C3E20CBD85CDC3066C9CC3A3066B0ACE346A7 |
| xauusd_h1.csv | 09E099130EDFAA908304BB7ECC4F5165F3198473D9851FEE1C8725A90DD7533A |
| xauusd_m15.csv | C05AD2F6EA3FDD04B714987E11EC4EA23685D3C2F415244DCEBAAB33B0D23BCA |

See [Arabic independent review](../../../experiments/EXP-002-multi-timeframe-analysis/RESULTS.ar.md) for all pivots, gaps, boundary exclusions and aggregation checks. Hashes identify file bytes, not accuracy of prices or timezone. Source-data licensing is not changed by this repository's code/documentation license.
