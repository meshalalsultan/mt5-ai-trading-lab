//+------------------------------------------------------------------+
//| EXP009_deal.mqh                                                  |
//| EXP-009 B2-R4: deal classification for execution evidence.       |
//| NO trading logic and NO OrderSend path in this file: it is shared|
//| by the adapter (BuildSnapshot deal loop) and the non-trading     |
//| unit runner (EXP009_FILL_TEST_RUNNER.mq5) so that the SAME code  |
//| is tested and used.                                              |
//|                                                                  |
//| Classification (build 6182 - probe-verified constants):          |
//|  - DEAL_TYPE_BALANCE / DEAL_TYPE_COMMISSION after a SUCCESSFUL   |
//|    read: KNOWN NON-TRADING records -> excluded from execution    |
//|    evidence WITHOUT blocking.                                    |
//|  - DEAL_TYPE_BUY / DEAL_TYPE_SELL with DEAL_ENTRY_IN or          |
//|    DEAL_ENTRY_OUT: trading evidence.                             |
//|  - BUY/SELL with INOUT / OUT_BY / any other entry: an UNSUPPORTED|
//|    route for the current adapter -> BLOCK with a clear reason    |
//|    (never excluded as financing).                                |
//|  - A FAILED read of the deal TYPE or the required ENTRY -> BLOCK;|
//|    a failed read is NEVER replaced with a default value.         |
//|  - Any other unknown TYPE value (read OK) -> BLOCK (unknown).    |
//|                                                                |
//| The E9DealRead structure is the shared seam: BuildSnapshot fills |
//| it (select + getters) and the runner INJECTS read outcomes into  |
//| it (including injected failures), so the classification path is  |
//| identical in both.                                               |
//+------------------------------------------------------------------+
#ifndef EXP009_DEAL_MQH
#define EXP009_DEAL_MQH

//--- classification results
#define E9_DC_TRADE_BUY   0
#define E9_DC_TRADE_SELL  1
#define E9_DC_NONTRADING  2   // recognized non-trading -> excluded, NO block
#define E9_DC_UNKNOWN     3   // read-failure / unsupported / unknown -> BLOCK

//--- one deal record read result: per-field read SUCCESS flags, so a
//    failed read (has=false) is distinguishable from a zero value and
//    is never replaced by a default.
struct E9DealRead
  {
   bool hasType;      // DEAL_TYPE was read successfully
   bool hasEntry;     // DEAL_ENTRY was read successfully
   long dealType;     // raw DEAL_TYPE value (valid when hasType)
   long dealEntry;    // raw DEAL_ENTRY value (valid when hasEntry)
  };

//--- pure classifier on the read result. Returns E9_DC_* and fills
//    why with a clear reason on every non-trade outcome.
int DealClassify(const E9DealRead &r,string &why)
  {
   why="";
   //--- read failures BLOCK; never a default value
   if(!r.hasType){ why="deal-type-read-failed";        return(E9_DC_UNKNOWN); }
   if(!r.hasEntry){ why="deal-entry-read-failed";      return(E9_DC_UNKNOWN); }
   //--- recognized NON-TRADING records (official type constants)
   if(r.dealType==DEAL_TYPE_BALANCE){ why="balance-excluded";   return(E9_DC_NONTRADING); }
   if(r.dealType==DEAL_TYPE_COMMISSION){ why="commission-excluded"; return(E9_DC_NONTRADING); }
   //--- the adapter can route ONLY IN/OUT trading deals; INOUT, OUT_BY
   //    (DEAL_ENTRY_OUT_BY) or any other entry is UNSUPPORTED -> BLOCK,
   //    never silently classified as financing.
   if(r.dealEntry!=DEAL_ENTRY_IN && r.dealEntry!=DEAL_ENTRY_OUT)
     { why="unsupported-entry-for-trading-deal";        return(E9_DC_UNKNOWN); }
   if(r.dealType==DEAL_TYPE_BUY){ why="";               return(E9_DC_TRADE_BUY); }
   if(r.dealType==DEAL_TYPE_SELL){ why="";              return(E9_DC_TRADE_SELL); }
   why="unknown-deal-type";
   return(E9_DC_UNKNOWN);
  }

string DealClassTxt(const int dc)
  {
   if(dc==E9_DC_TRADE_BUY)  return("TRADE_BUY");
   if(dc==E9_DC_TRADE_SELL) return("TRADE_SELL");
   if(dc==E9_DC_NONTRADING) return("NONTRADING_EXCLUDED");
   return("UNKNOWN_BLOCK");
  }

#endif