//+------------------------------------------------------------------+
//| MASK_SMA20_CROSS_EDU_EA_v01.mq5                                  |
//| EXP-009 Test B2-R3: Strategy Tester adapter for the EXP009 core. |
//| Reuses CE9Core (EXP009, package EXP009-B1-R2, UNCHANGED) for the |
//| state machine + interlinked confirmation, and the EXP-008 shared |
//| logic (EduLoadWindow / EduEvaluateSignal) for the SMA20 verdict  |
//| on the last two closed bars. No SL/TP, no filters, no auto-      |
//| adjust of volume; hedging-only, tester-only, optimization runs   |
//| rejected inside the EA.                                          |
//|                                                                  |
//| API surface in THIS build 6182 (probe-verified; raw logs kept):  |
//|  positions : PositionsTotal() + PositionGetTicket(int index)     |
//|              + PositionSelectByTicket(ulong ticket)              |
//|  active    : OrdersTotal() + OrderGetTicket(int index)           |
//|              + OrderSelect(ulong ticket)                         |
//|  history   : HistorySelect(from,to); HistoryOrdersTotal();       |
//|              HistoryOrderGetTicket(int); HistoryOrderSelect;     |
//|              HistoryDealsTotal(); HistoryDealGetTicket(int);     |
//|              HistoryDealSelect                                  |
//|  market data: CopyRates -> MqlRates[] (single snapshot used for  |
//|              BOTH closes and times: same index = same bar)       |
//|  fill flags : SYMBOL_FILLING_FOK/IOC (see EXP009_fill.mqh for the|
//|              official per-mode table; BOC never selected; RETURN |
//|              chosen by EXCHANGE mode, needs no flag)             |
//|  exec modes : ENUM_SYMBOL_TRADE_EXECUTION, SYMBOL_TRADE_EXECUTION|
//|              _REQUEST/INSTANT/MARKET/EXCHANGE (official names)   |
//|  zero init  : MqlTradeRequest req={}; MqlTradeResult res={0};    |
//|  deal types : DEAL_TYPE_BUY/SELL(trading), DEAL_TYPE_BALANCE/    |
//|              DEAL_TYPE_COMMISSION (non-trading); IN/OUT trading; |
//|              INOUT/OUT_BY/other entry -> unsupported (BLOCK)     |
//|  NOT in this build (raw errors in exp009_probe2..7.log):         |
//|   PositionSelectByIndex, OrderSelectByTicket, ORDER_TYPE_MARKET, |
//|   SYMBOL_FILLING_RETURN, DEAL_TYPE_*_REDEEM,                     |
//|   MqlTradeRequest.order_ticket/price_step/expiration_time/       |
//|   filling(deprecated), MqlTradeResult.request_status.            |
//+------------------------------------------------------------------+
#property copyright "EXP-009"
#property version   "1.04"
#property strict

#include <MASK_EDU\MASK_SMA20_CROSS_EDU_shared.mqh>
#include <MASK_EDU_EXP009\EXP009_core.mqh>
#include <MASK_EDU_EXP009\EXP009_fill.mqh>
#include <MASK_EDU_EXP009\EXP009_deal.mqh>

//--- adapter identity (evidence log + traceability)
#define B2_VER "EXP009-B2-R5"
#define B2_EXPECT_SYMBOL "XAUUSD"

//--- inputs (explicit, documented; not silently added logic)
input long   InpDeviation = 50;      // allowed deviation in points: non-negative
                                     // integer; polite value, NOT a guarantee
input long   InpMagic     = 0xE9B2;  // dedicated EXP-009 B2 magic (documented)
input string InpLogFile   = "MASK_EDU_EXP009\\exp009_b2_runlog.csv";

CE9Core   g_core;
E9Claim   g_claim;
bool      g_claimArmed=false;
int       g_file=INVALID_HANDLE;
string    g_runId;
ENUM_ORDER_TYPE_FILLING g_filling=(ENUM_ORDER_TYPE_FILLING)0;
string    g_fillingName="";
datetime  g_rangeFrom=0;
int       g_sends=0;
int       g_ntDeals=0;     // recognized non-trading deals excluded (evidence)
string    g_lastNote="";

//==================================================================//
// mapping helpers -> our OWN E9_* conventions (core)                //
//==================================================================//
int MapOrderState(const int st)
  {
   switch(st)
     {
      case ORDER_STATE_STARTED:   return(E9_ORD_STARTED);
      case ORDER_STATE_PLACED:    return(E9_ORD_PLACED);
      case ORDER_STATE_FILLED:    return(E9_ORD_FILLED);
      case ORDER_STATE_CANCELED:  return(E9_ORD_CANCELED);
      case ORDER_STATE_REJECTED:  return(E9_ORD_REJECTED);
      case ORDER_STATE_EXPIRED:   return(E9_ORD_CANCELED);
      default:                    return(E9_ORD_PLACED); // unknown -> NOT final -> blocks
     }
  }
int DirOfOrderType(const int t)
  {
   if(t==ORDER_TYPE_BUY  || t==ORDER_TYPE_BUY_LIMIT ||
      t==ORDER_TYPE_BUY_STOP || t==ORDER_TYPE_BUY_STOP_LIMIT) return(E9_BUY);
   if(t==ORDER_TYPE_SELL || t==ORDER_TYPE_SELL_LIMIT ||
      t==ORDER_TYPE_SELL_STOP || t==ORDER_TYPE_SELL_STOP_LIMIT) return(E9_SELL);
   return(0);
  }
int MapDealEntry(const int e)
  {
   if(e==DEAL_ENTRY_IN)  return(E9_ENTRY_IN);
   if(e==DEAL_ENTRY_OUT) return(E9_ENTRY_OUT);
   return(-1);                 // INOUT (netting/non-trading) / OUT_BY / INOUT_BY
  }

//--- full-precision log helper (tickets and times keep ALL digits)
string T64(const ulong v)
  {
   return(StringFormat("%I64d",v));
  }

//==================================================================//
// evidence snapshot: FULL enumeration (positions + active orders)   //
// and RANGED history/deals over a clear, documented window.         //
// A read failure is UNKNOWN (flagged), never an empty list, never   //
// replaced with default symbol/magic, and never a silent filter.    //
// Deal classification uses the SHARED DealClassify() (EXP009_deal): //
// known non-trading records are documented and EXCLUDED without     //
// blocking; unknown types with trading impact BLOCK the snapshot.   //
//==================================================================//
bool SnapshotHasHistTicket(const E9Snapshot &s,const ulong ticket)
  {
   for(int i=0;i<ArraySize(s.histOrd);i++)
     if(s.histOrd[i].ticket==ticket) return(true);
   return(false);
  }
bool SnapshotHasDealTicket(const E9Snapshot &s,const ulong ticket)
  {
   for(int i=0;i<ArraySize(s.deals);i++)
     if(s.deals[i].dealTicket==ticket) return(true);
   return(false);
  }
void BuildSnapshot(E9Snapshot &s)
  {
   E9SnapInit(s);
   s.volMin =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   s.volMax =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   s.volStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   //--- 1) positions: FULL enumeration (ticket getter + select-by-ticket)
   int np=PositionsTotal();
   for(int i=0;i<np;i++)
     {
      ulong t=PositionGetTicket(i);
      if(t==0){ s.posQueryFailed=true; continue; }   // read failure != empty
      if(!PositionSelectByTicket(t)){ s.posQueryFailed=true; continue; }
      string sy=PositionGetString(POSITION_SYMBOL);
      double vol=PositionGetDouble(POSITION_VOLUME);
      if(StringLen(sy)==0 || vol<=0.0 || !MathIsValidNumber(vol))
        { s.posQueryFailed=true; continue; }          // owner/link/volume unreadable
      E9AddPos(s,t,
               (long)PositionGetInteger(POSITION_IDENTIFIER),
               (long)PositionGetInteger(POSITION_MAGIC),
               sy,
               (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?E9_BUY:E9_SELL),
               vol);
     }
   //--- 2) active orders: FULL enumeration (ticket getter + select-by-ticket)
   int no=OrdersTotal();
   for(int i=0;i<no;i++)
     {
      ulong t=OrderGetTicket(i);
      if(t==0){ s.actQueryFailed=true; continue; }
      if(!OrderSelect(t)){ s.actQueryFailed=true; continue; }
      string sy=OrderGetString(ORDER_SYMBOL);
      double vol=OrderGetDouble(ORDER_VOLUME_INITIAL);
      if(StringLen(sy)==0 || vol<=0.0 || !MathIsValidNumber(vol))
        { s.actQueryFailed=true; continue; }          // ownership/volume unreadable
      E9AddActiveEx(s,t,
                    (long)OrderGetInteger(ORDER_MAGIC),
                    sy,
                    DirOfOrderType((int)OrderGetInteger(ORDER_TYPE)),
                    MapOrderState((int)OrderGetInteger(ORDER_STATE)),
                    vol);
     }
   //--- 3) history orders + deals over a CLEAR range covering the run:
   //        [run start - 1h .. now]. Every pending request of this run
   //        is dispatched from OnTick, i.e. AFTER g_rangeFrom is set,
   //        so the range always covers the pending requests.
   if(g_rangeFrom>0)
     {
      datetime to=TimeCurrent();
      if(to>g_rangeFrom && HistorySelect(g_rangeFrom,to))
        {
         // 3a) collect HISTORY ORDER tickets FIRST (getters only; no
         //     selection call mutates the list while we enumerate),
         //     THEN select/read per ticket. A zero ticket is a READ
         //     FAILURE that must block, not a record to ignore.
         int ho=HistoryOrdersTotal();
         ulong hot[]; ArrayResize(hot,0);
         for(int i=0;i<ho;i++)
           {
            ulong tk=HistoryOrderGetTicket(i);
            if(tk==0){ s.histQueryFailed=true; continue; }
            int n=ArraySize(hot); ArrayResize(hot,n+1); hot[n]=tk;
           }
         for(int k=0;k<ArraySize(hot);k++)
           {
            ulong t=hot[k];
            if(t==0){ s.histQueryFailed=true; continue; }
            if(!HistoryOrderSelect(t)){ s.histQueryFailed=true; continue; }
            if(SnapshotHasHistTicket(s,t)) continue;      // dedupe by ticket
            string sy=HistoryOrderGetString(t,ORDER_SYMBOL);
            double vol=HistoryOrderGetDouble(t,ORDER_VOLUME_INITIAL);
            if(StringLen(sy)==0 || vol<=0.0 || !MathIsValidNumber(vol))
              { s.histQueryFailed=true; continue; }       // ownership/volume unreadable
            E9AddHistEx(s,t,
                        (long)HistoryOrderGetInteger(t,ORDER_MAGIC),
                        sy,
                        DirOfOrderType((int)HistoryOrderGetInteger(t,ORDER_TYPE)),
                        MapOrderState((int)HistoryOrderGetInteger(t,ORDER_STATE)),
                        vol);
           }
         // 3b) DEAL tickets in the same range, then per-deal classify +
         //     link to the parent order and position id. The SHARED
         //     classifier distinguishes trading deals from KNOWN non-
         //     trading records (excluded, no block) and from UNKNOWN
         //     types (block). magic/symbol of the parent order MUST be
         //     readable: a failed lookup is UNKNOWN and blocks.
         int hd=HistoryDealsTotal();
         ulong hdt[]; ArrayResize(hdt,0);
         for(int i=0;i<hd;i++)
           {
            ulong tk=HistoryDealGetTicket(i);
            if(tk==0){ s.dealsQueryFailed=true; continue; }
            int n=ArraySize(hdt); ArrayResize(hdt,n+1); hdt[n]=tk;
           }
         for(int k=0;k<ArraySize(hdt);k++)
           {
            ulong dt=hdt[k];
            if(dt==0){ s.dealsQueryFailed=true; continue; }
            if(!HistoryDealSelect(dt)){ s.dealsQueryFailed=true; continue; }
            if(SnapshotHasDealTicket(s,dt)) continue;     // dedupe by ticket
            E9DealRead dr;
            dr.hasType=false; dr.hasEntry=false;
            dr.dealType=0; dr.dealEntry=0;
            
            dr.hasType =HistoryDealGetInteger(dt,DEAL_TYPE,dr.dealType);
            
            dr.hasEntry=HistoryDealGetInteger(dt,DEAL_ENTRY,dr.dealEntry);
            string dwhy="";
            
            int dc=DealClassify(dr,dwhy);            // SHARED classifier
            if(dc==E9_DC_NONTRADING)
              { g_ntDeals++; continue; }                  // known non-trading: EXCLUDE, no block
            if(dc!=E9_DC_TRADE_BUY && dc!=E9_DC_TRADE_SELL)
              { s.dealsQueryFailed=true; Print("B2|DEAL|BLOCK|"+DealClassTxt(dc)+"|"+dwhy); continue; }
            int dir=(dc==E9_DC_TRADE_BUY?E9_BUY:E9_SELL);
            double dvol=HistoryDealGetDouble(dt,DEAL_VOLUME);
            if(dvol<=0.0 || !MathIsValidNumber(dvol))
              { s.dealsQueryFailed=true; continue; }      // volume unreadable
            long pid=(long)HistoryDealGetInteger(dt,DEAL_POSITION_ID);
            if(pid<=0){ s.dealsQueryFailed=true; continue; } // link id unreadable: UNKNOWN
            ulong od=(ulong)HistoryDealGetInteger(dt,DEAL_ORDER);
            if(od<=0){ s.dealsQueryFailed=true; continue; } // order link id unreadable: UNKNOWN
            long mg=0; string sy="";
            if(HistoryOrderSelect(od))
              {
               mg=(long)HistoryOrderGetInteger(od,ORDER_MAGIC);
               sy=HistoryOrderGetString(od,ORDER_SYMBOL);
              }
            else
              {
               s.dealsQueryFailed=true;                   // parent unreadable: UNKNOWN
               continue;
              }
            if(StringLen(sy)==0)
              { s.dealsQueryFailed=true; continue; }      // symbol unreadable: UNKNOWN
            E9AddDealEx(s,dt,od,pid,dir,dvol,
                        MapDealEntry((int)dr.dealEntry),mg,sy);
           }
        }
      else
        {
         s.histQueryFailed=true;      // HistorySelect failed / empty-range guard:
         s.dealsQueryFailed=true;     // a failed selection is NOT a confirmed empty list
        }
     }
  }

//==================================================================//
// signal: SMA20 cross on the LAST TWO CLOSED bars (EXP-008 logic).  //
// A SINGLE CopyRates snapshot supplies BOTH closes and times, so    //
// time[i] and close[i] always refer to the SAME bar (series index 0 |
// = forming bar, 1 = last CLOSED bar = C1).                         //
// s.barTime is ALWAYS the true C1 time when the rate array is       //
// readable, even when the SMA window is short (canEval stays false  //
// and no signal is produced). An unknown time is reported as        //
// unknown (0); an OLD time is never used as a substitute.           //
// Old-key expiry policy stays with the core (consumed keys + only   //
// the newest bar is actionable).                                    //
//==================================================================//
void BuildSignal(E9Signal &s)
  {
   s.barTime=0; s.canEval=false; s.dir=0;           // unknown until proven
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int need=EDU_SMA_PERIOD+2;                       // indices 0..21 (window: closes 1..21)
   int n=CopyRates(_Symbol,_Period,0,need,rates);
   if(n<2) return;                                  // need forming + >=1 closed bar for time
   if(rates[1].time<=0) return;                     // C1 time unreadable -> UNKNOWN
   //--- closes/times built from the SAME snapshot: same index = same bar
   double cl[]; datetime tm[];
   ArraySetAsSeries(cl,true);
   ArraySetAsSeries(tm,true);
   ArrayResize(cl,n);
   ArrayResize(tm,n);
   for(int i=0;i<n;i++)
     {
      cl[i]=rates[i].close;
      tm[i]=rates[i].time;
     }
   s.barTime=tm[1];                                 // newest CLOSED bar time (C1)
   EduWindow w;
   if(!EduLoadWindow(cl,tm,n,1,w)) return;          // short window -> canEval stays false
   EduSignal es=EduEvaluateSignal(w.c1,w.sma1,w.c2,w.sma2);
   s.canEval=(es!=EDU_S_CANNOT_EVALUATE);
   s.dir   =(es==EDU_S_UP ?E9_BUY : (es==EDU_S_DOWN ?E9_SELL : 0));
  }

//==================================================================//
// evidence log (CSV under Files\MASK_EDU_EXP009\)                  //
//==================================================================//
void B2Log(const string ev,const string pre,const string post)
  {
   if(g_file==INVALID_HANDLE) return;
   FileWrite(g_file,g_runId,B2_VER,_Symbol,T64((ulong)TimeCurrent()),ev,pre,post);
   Print("B2|"+ev+"|"+pre+"|"+post);   // journal mirror: tester-verifiable state trail
   FileFlush(g_file);
   FileFlush(g_file);
  }

//==================================================================//
// order send: claim only; close targets the EXACT ticket; no SL/TP; //
// no margin checks on close (entry/close checks are separated);     //
// MQL_TESTER barrier re-checked before every send. Inputs/prices    //
// are re-validated before EVERY send; a refusal leaves the core     //
// blocked (no resend), it never places a wrong order.               //
// MqlTradeRequest and MqlTradeResult are FULLY zero-initialized     //
// ({}/={0}) before the used members are set - no member is left     //
// with stack garbage (this also covers reserved[]).                 //
//==================================================================//
void DoSend(const E9Action &act)
  {
   if(MQLInfoInteger(MQL_TESTER)!=1)
     { Print("B2|SEND|BLOCKED|not-tester"); return; }
   //--- defensive input validation before ANY send (the core already
   //    validated at intent time; this is the last gate)
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double vstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(act.volume<=0.0 || act.volume<vmin || act.volume>vmax ||
      !MathIsValidNumber(act.volume) || vstep<=0.0)
     { B2Log("SEND|REFUSED|volume-invalid",StringFormat("vol=%g",act.volume),""); return; }
   double tol=0.0;
   if(E9VolumeOnGrid(act.volume,vstep,tol)!=E9_V_OK)
     { B2Log("SEND|REFUSED|volume-off-grid",StringFormat("vol=%g step=%g",act.volume,vstep),""); return; }
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   //--- fully zeroed request; then set only what we use (no SL/TP)
   MqlTradeRequest req={};
   req.action=TRADE_ACTION_DEAL;
   req.type  =(act.type==1)
                ?((act.dir==E9_BUY)?ORDER_TYPE_BUY:ORDER_TYPE_SELL)
                :((act.dir==E9_BUY)?ORDER_TYPE_SELL:ORDER_TYPE_BUY);
   req.symbol=_Symbol;
   req.volume=act.volume;
   req.price =(req.type==ORDER_TYPE_BUY)?ask:bid;
   req.deviation=(ulong)InpDeviation;   // in-range: validated non-negative in OnInit
   req.comment="EXP-009 B2";
   req.magic  =InpMagic;
   req.type_filling=g_filling;          // documented symbol-supported policy
   req.position=act.posTicket;          // 0 on open; the EXACT ticket on close
   req.type_time=ORDER_TIME_GTC;
   //--- the price must be readable and valid (never send on garbage)
   if(!EduIsPriceValid(req.price))
     { B2Log("SEND|REFUSED|price-unavailable",StringFormat("ask=%g bid=%g",ask,bid),""); return; }
   //--- fully zeroed result struct
   MqlTradeResult res={0};
   string pre=StringFormat("t=%s pos=%s vol=%g step=%g ask=%g bid=%g dev=%d fill=%s",
                           T64((ulong)TimeCurrent()),T64(act.posTicket),
                           act.volume,vstep,ask,bid,InpDeviation,g_fillingName);
   bool ok=OrderSend(req,res);
   g_sends++;
   //--- claim, NOT a fact: refs come from the result; retcode alone is
   //    never treated as execution proof (the core demands history/deal/
   //    position evidence before confirming)
   g_claim.has=true;
   g_claim.done=(res.retcode==TRADE_RETCODE_DONE);
   g_claim.orderTicket=(res.order>0?res.order:0);
   g_claim.dealTicket =res.deal;
   g_claim.volume=act.volume;
   g_claim.dir  =act.dir;
   g_claimArmed =true;
   string post=StringFormat("call=%d retcode=%d order=%s deal=%s vol=%g price=%g",
                            (int)ok,(int)res.retcode,T64(res.order),T64(res.deal),
                            res.volume,res.price);
   B2Log("SEND|"+(act.type==1?"OPEN":"CLOSE"),pre,post);
  }

//==================================================================//
int OnInit()
  {
   // barrier 0: a normal, single, NON-optimization run only
   if(MQLInfoInteger(MQL_OPTIMIZATION)!=0)
     { Print("B2|INIT|FAIL|optimization-forbidden"); return(INIT_FAILED); }
   // barrier 1a: tester only
   if(MQLInfoInteger(MQL_TESTER)!=1)
     { Print("B2|INIT|FAIL|not-tester"); return(INIT_FAILED); }
   // barrier 1b: exact scope
   if(_Symbol!=B2_EXPECT_SYMBOL || _Period!=PERIOD_H1)
     { PrintFormat("B2|INIT|FAIL|scope %s %d",_Symbol,_Period); return(INIT_FAILED); }
   // barrier 1c: hedging-only account
   int mm=(int)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mm!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     { PrintFormat("B2|INIT|FAIL|margin-mode=%d",mm); return(INIT_FAILED); }
   //--- explicit input validation (refusal with a clear reason)
   if(InpDeviation<0)
     { PrintFormat("B2|INIT|FAIL|deviation=%d",InpDeviation); return(INIT_FAILED); }
   if(InpMagic==0)
     { Print("B2|INIT|FAIL|magic-zero"); return(INIT_FAILED); }
   if(StringLen(InpLogFile)==0)
     { Print("B2|INIT|FAIL|logfile-empty"); return(INIT_FAILED); }
   //--- volume grid must be readable (core re-validates per tick)
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)<=0.0 ||
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)<=0.0)
     { Print("B2|INIT|FAIL|volume-props-unavailable"); return(INIT_FAILED); }
   //--- fill policy: resolve it; a FAILURE is rejected explicitly (it is
   //    never accepted with a silent default)
   string fReason="";
   if(!FillingForSymbol(g_filling,fReason))
     { Print("B2|INIT|FAIL|filling:"+fReason); return(INIT_FAILED); }
   g_fillingName=FillName(g_filling);
   g_core.Configure(InpMagic,B2_EXPECT_SYMBOL);
   g_runId=T64((ulong)TimeCurrent());
   //--- the evidence log MUST open: no log -> no auditable evidence ->
   //    visible INIT_FAILED
   g_file=FileOpen(InpLogFile,FILE_CSV|FILE_READ|FILE_WRITE|FILE_ANSI);
   if(g_file==INVALID_HANDLE)
     { Print("B2|INIT|FAIL|log-open-failed:"+InpLogFile); return(INIT_FAILED); }
   FileSeek(g_file,0,SEEK_END);
   //--- clear, documented history range: [run start - 1h .. now]
   datetime now=TimeCurrent();
   g_rangeFrom=(now>3600 ? now-3600 : 1);
   //--- evidence header: adapter version + run info + settings
   B2Log("RUN|START",
         StringFormat("ver=%s pkg=%s magic=%I64d dev=%d fill=%s vmin=%g vstep=%g mm=%d tester=%d opt=%d sym=%s per=%d rangeFrom=%s",
                      B2_VER,EXP9_PKG,InpMagic,InpDeviation,g_fillingName,
                      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
                      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),
                      mm,(int)MQLInfoInteger(MQL_TESTER),(int)MQLInfoInteger(MQL_OPTIMIZATION),
                      _Symbol,(int)_Period,T64(g_rangeFrom)),
         "");
   PrintFormat("B2|INIT|OK|ver=%s pkg=%s runid=%s magic=%I64d filling=%s",
               B2_VER,EXP9_PKG,g_runId,InpMagic,g_fillingName);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_file!=INVALID_HANDLE)
     {
      B2Log("RUN|END",StringFormat("sends=%d ntdeals=%d reason=%d",g_sends,g_ntDeals,reason),"");
      FileClose(g_file);
      g_file=INVALID_HANDLE;
     }
  }

void OnTick()
  {
   //--- explicit input initialization (never trust stack garbage)
   E9Input in;
   in.sig.barTime=0; in.sig.canEval=false; in.sig.dir=0;
   in.snap.volMin=0.0; in.snap.volMax=0.0; in.snap.volStep=0.0;
   in.claim.has=false; in.claim.done=false;
   in.claim.orderTicket=0; in.claim.dealTicket=0;
   in.claim.volume=0.0; in.claim.dir=0;
   E9Action act;
   act.type=0; act.dir=0; act.volume=0.0; act.posTicket=0;
   //--- data (signal + evidence), then the claim from the last send
   BuildSignal(in.sig);
   BuildSnapshot(in.snap);
   if(g_claimArmed){ in.claim=g_claim; g_claimArmed=false; }
   string pre=StringFormat("st=%d bar=%s dir=%d can=%d step=%g posQ=%d actQ=%d histQ=%d dealQ=%d",
                           g_core.State(),T64(in.sig.barTime),in.sig.dir,(int)in.sig.canEval,
                           in.snap.volStep,(int)in.snap.posQueryFailed,(int)in.snap.actQueryFailed,
                           (int)in.snap.histQueryFailed,(int)in.snap.dealsQueryFailed);
   g_core.Process(in,act);
   if(g_core.Note()!=g_lastNote)
     {
      B2Log("STATE|"+g_core.Note(),pre,StringFormat("st=%d sends=%d",g_core.State(),g_sends));
      g_lastNote=g_core.Note();
     }
   if(act.type!=0)
     {
      B2Log("INTENT|"+(act.type==1?"OPEN":"CLOSE"),
            pre,StringFormat("st=%d dir=%d vol=%g pos=%s",g_core.State(),act.dir,act.volume,T64(act.posTicket)));
      DoSend(act);
     }
  }
//+------------------------------------------------------------------+