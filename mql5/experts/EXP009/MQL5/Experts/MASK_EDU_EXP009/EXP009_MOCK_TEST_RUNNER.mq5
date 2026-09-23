//+------------------------------------------------------------------+
//| EXP009_MOCK_TEST_RUNNER.mq5 (EA, tester-only harness)            |
//| EXP-009 Test B1: headless execution of the SAME suite used by   |
//| the script. No OrderSend/CTrade anywhere. Runs in OnInit and     |
//| exits immediately. No trades, no chart modifications.            |
//+------------------------------------------------------------------+
#property copyright "EXP-009"
#property version   "1.00"

#include <MASK_EDU_EXP009\EXP009_tests.mqh>

int OnInit()
  {
   int fails=E9RunSuite("exp009_b1_r5_results.txt");
   PrintFormat("EXP9TEST|RUNNER|FAILS=%d",fails);
   return(INIT_FAILED);   // synthetic suite only; stop immediately
  }

void OnDeinit(const int reason)
  {
  }

void OnTick()
  {
  }
//+------------------------------------------------------------------+