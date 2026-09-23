//+------------------------------------------------------------------+
//| MASK_SMA20_CROSS_EDU_TEST_RUNNER.mq5 (EA)                        |
//| EXP-008 Test B: headless execution harness for the SAME suite    |
//| used by the script (no duplicated logic). Run only in the        |
//| Strategy Tester: runs the suite in OnInit, writes the results    |
//| file (Common folder) and exits immediately. No trading, no       |
//| chart modifications.                                             |
//+------------------------------------------------------------------+
#property copyright "EXP-008"
#property version   "1.00"

#include <MASK_EDU\MASK_SMA20_CROSS_EDU_tests.mqh>

//+------------------------------------------------------------------+
int OnInit()
  {
   int fails=EduRunTestSuite("exp008_test_results.txt");
   PrintFormat("EXP8TEST|RUNNER|FAILS=%d",fails);
   return(INIT_FAILED);      // finish immediately; tests are synthetic
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
void OnTick()
  {
  }
//+------------------------------------------------------------------+