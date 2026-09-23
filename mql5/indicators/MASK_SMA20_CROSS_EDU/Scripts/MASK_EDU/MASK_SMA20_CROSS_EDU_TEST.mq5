//+------------------------------------------------------------------+
//| MASK_SMA20_CROSS_EDU_TEST.mq5 (Script)                           |
//| EXP-008 Test B: runs the full synthetic suite from the shared    |
//| core (MASK_SMA20_CROSS_EDU_tests.mqh -> shared.mqh). No chart    |
//| objects, no trading, no alerts.                                  |
//+------------------------------------------------------------------+
#property copyright "EXP-008"
#property version   "1.00"
#property script_show_inputs false

#include <MASK_EDU\MASK_SMA20_CROSS_EDU_tests.mqh>

//+------------------------------------------------------------------+
void OnStart()
  {
   int fails=EduRunTestSuite("exp008_test_results.txt");
   PrintFormat("EXP8TEST|SCRIPT|FAILS=%d",fails);
  }
//+------------------------------------------------------------------+