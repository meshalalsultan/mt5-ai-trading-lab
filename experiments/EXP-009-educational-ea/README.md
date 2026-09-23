# EXP-009 — Educational EA integration

Status: scoped integration passed for observed paths; coverage remains incomplete.

[التقرير العربي](RESULTS.ar.md) · [Source and reproduction](../../mql5/experts/EXP009/README.md) · [Evidence](../../assets/results/EXP009-R5/README.md) · [Case study](../../case-studies/CS-002-close-confirmation.ar.md)

R5 core suite: 27 PASS / 0 FAIL; fill/deal suite: 28 PASS / 0 FAIL. Run 1 exposed a close-direction defect masked by incorrect mock fixtures. Run 2 confirmed three strategy closes and subsequent entries on later bar keys. Four SELL entries, seven adapter requests; the final position was closed by the tester. No BUY entry integration, profitability, robustness or live-account validation is claimed.
