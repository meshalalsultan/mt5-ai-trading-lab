# EXP009 R5 — tester-only educational EA

Copy the contents of this directory's MQL5/ into the terminal's MQL5/ preserving paths. Dependency: copy Include/MASK_EDU/MASK_SMA20_CROSS_EDU_shared.mqh from [EXP008 source](../../indicators/MASK_SMA20_CROSS_EDU/) into the matching terminal Include folder. Its original SHA-256 is 26487050e847d1537963a92ae38c4f8034679d2ad174c25b9cf3500754f42ca0.

Compile the EA and both test runners in MetaEditor. No EX5 binaries are distributed. The core runner also requires EXP009_mock.mqh and EXP009_tests.mqh (included).

Run the MOCK and FILL runners separately to reproduce component suites. They deliberately return INIT_FAILED after writing results to Common/Files; inspect the fresh result files and journal, not the tester status alone.

The supplied integration.ini preserves the archived base settings. **Load exp009_integration_r5.set explicitly** into Tester Inputs; the base INI does not reference it. Verify the actual inputs (0.01 fixed in code, magic 59442, deviation 50, integration2 log name), XAUUSD H1, hedging, optimization disabled. Choose a new log name for any later run; retain prior evidence. Log output is inside the tester agent's MQL5/Files, with a Journal mirror.

Do not attach the trading EA to an account chart. Runtime guards reject non-tester/optimization/out-of-scope initialization. No protective SL/TP, no production readiness or profitability claim. The published snapshot records observed integration success, not a comprehensive code certification.
