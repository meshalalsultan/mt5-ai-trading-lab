//+------------------------------------------------------------------+
//| EXP009_fill.mqh                                                  |
//| EXP-009 B2-R3: symbol fill-policy RESOLUTION (shared include).   |
//| NO trading logic and NO OrderSend path in this file: it is used  |
//| by the adapter (MASK_SMA20_CROSS_EDU_EA_v01.mq5) and by the      |
//| non-trading unit runner (EXP009_FILL_TEST_RUNNER.mq5).           |
//|                                                                  |
//| MQL5 OFFICIAL compatibility (ENUM_ORDER_TYPE_FILLING):          |
//|   REQUEST : FOK only                                             |
//|   INSTANT : FOK only                                             |
//|   MARKET  : FOK, IOC, BOC                                        |
//|   EXCHANGE: FOK, IOC, BOC, RETURN                                |
//| Adapter policy (market-order-only EA):                           |
//|   REQUEST, INSTANT              -> FOK (regardless of flags)     |
//|   MARKET : FOK if advertised, else IOC if advertised, else FAIL  |
//|   EXCHANGE: FOK if advertised, else IOC if advertised, else RETURN
//|   (RETURN needs NO independent flag: it is the exchange default) |
//|   BOC is NEVER selected for a market order; the BOC flag does    |
//|   NOT cancel other allowed options. Unknown exec mode and        |
//|   property read failures are explicit failures (no guess, no     |
//|   silent fallback to FOK).                                       |
//+------------------------------------------------------------------+
#ifndef EXP009_FILL_MQH
#define EXP009_FILL_MQH

//--- request fill names (ENUM_ORDER_TYPE_FILLING)
string FillName(const ENUM_ORDER_TYPE_FILLING f)
  {
   if(f==ORDER_FILLING_FOK)    return("FOK");
   if(f==ORDER_FILLING_IOC)    return("IOC");
   if(f==ORDER_FILLING_RETURN) return("RETURN");
   if(f==ORDER_FILLING_BOC)    return("BOC");
   return("NONE");
  }

//--- PURE decision per the official table above.
//    exeMode: ENUM_SYMBOL_TRADE_EXECUTION value; hasFOK/hasIOC: whether
//    the symbol advertises the FOK/IOC filling modes (SYMBOL_FILLING_MODE
//    bits). Success -> true + fillOut; failure -> false + reason.
bool ResolveFilling(const long exeMode,
                    const bool hasFOK,const bool hasIOC,
                    ENUM_ORDER_TYPE_FILLING &fillOut,string &reason)
  {
   fillOut=(ENUM_ORDER_TYPE_FILLING)0;
   reason="";
   //--- REQUEST and INSTANT always fill via FOK (official table)
   if(exeMode==SYMBOL_TRADE_EXECUTION_REQUEST ||
      exeMode==SYMBOL_TRADE_EXECUTION_INSTANT)
     { fillOut=ORDER_FILLING_FOK; return(true); }
   //--- MARKET: FOK/IOC per the advertised flags; BOC never picked;
   //    the BOC bit is simply ignored and does not cancel FOK/IOC.
   if(exeMode==SYMBOL_TRADE_EXECUTION_MARKET)
     {
      if(hasFOK){ fillOut=ORDER_FILLING_FOK; return(true); }
      if(hasIOC){ fillOut=ORDER_FILLING_IOC; return(true); }
      reason="market-mode-needs-FOK-or-IOC-flag";
      return(false);
     }
   //--- EXCHANGE: FOK then IOC per the flags, else RETURN (no flag needed)
   if(exeMode==SYMBOL_TRADE_EXECUTION_EXCHANGE)
     {
      if(hasFOK){ fillOut=ORDER_FILLING_FOK; return(true); }
      if(hasIOC){ fillOut=ORDER_FILLING_IOC; return(true); }
      fillOut=ORDER_FILLING_RETURN;
      return(true);
     }
   reason="unknown-exec-mode";
   return(false);
  }

//--- wrapper core: reads the two properties of the GIVEN symbol with
//    the BOOL-returning SymbolInfoInteger form; any read failure is a
//    hard failure with an independent reason. Taking the symbol as an
//    argument lets the unit runner exercise the SAME function on an
//    invalid symbol to prove the read-failure path.
bool FillingFromProps(const string symbol,
                      ENUM_ORDER_TYPE_FILLING &fillOut,string &reason)
  {
   fillOut=(ENUM_ORDER_TYPE_FILLING)0;
   reason="";
   long mode=0, exe=0;
   if(!SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE,mode))
     { reason="filling-mode-unreadable"; return(false); }
   if(!SymbolInfoInteger(symbol,SYMBOL_TRADE_EXEMODE,exe))
     { reason="exemode-unreadable"; return(false); }
   bool hFOK=((mode & (long)SYMBOL_FILLING_FOK)!=0);
   bool hIOC=((mode & (long)SYMBOL_FILLING_IOC)!=0);
   return(ResolveFilling(exe,hFOK,hIOC,fillOut,reason));
  }

//--- adapter-facing wrapper (current symbol)
bool FillingForSymbol(ENUM_ORDER_TYPE_FILLING &fillOut,string &reason)
  {
   return(FillingFromProps(_Symbol,fillOut,reason));
  }

#endif