//+------------------------------------------------------------------+
//| EXP009_FILL_TEST_RUNNER.mq5  (version R4)                        |
//| EXP-009 B2-R4: NON-TRADING unit runner for the SAME decision and |
//| classification code used by the adapter:                         |
//|   - fill policy: EXP009_fill.mqh     (ResolveFilling / wrapper)  |
//|   - deal classifier: EXP009_deal.mqh (DealClassify on E9DealRead)|
//| NO trading functions, NO OrderSend, NO CTrade, no order path.    |
//| OnInit runs the matrix, writes the results to the COMMON folder  |
//| (FILE_COMMON) and then returns INIT_FAILED on purpose; the       |
//| RESULTS FILE + expert journal prove execution.                   |
//+------------------------------------------------------------------+
#property copyright "EXP-009"
#property version   "1.04"
#property strict

#include <MASK_EDU_EXP009\EXP009_fill.mqh>
#include <MASK_EDU_EXP009\EXP009_deal.mqh>

#define FILL_RESULT_FILE "exp009_fill_test_results_r5.txt"

int g_h=INVALID_HANDLE;
int g_pass=0;
int g_fail=0;
int g_info=0;

void FLog(const string line)
  {
   if(g_h==INVALID_HANDLE) return;
   int w=(int)FileWrite(g_h,line);
   FileFlush(g_h);
  }

void FInfo(const string line)
  {
   g_info++;
   FLog("INFO|"+line);
  }

//--- counted LOGIC test
void FTest(const string sub,const bool cond,const string desc,
           const string expTxt,const string actTxt)
  {
   g_pass += (cond?1:0);
   g_fail += (cond?0:1);
   FLog("TEST|"+sub+"|"+(cond?"PASS":"FAIL")+"|"+desc+"|exp="+expTxt+"|act="+actTxt);
  }

string FillTxt(const ENUM_ORDER_TYPE_FILLING f)
  {
   return(FillName(f));
  }

//--- fill decision case (pure, per the OFFICIAL table)
void Case(const string sub,const long mode,
          const bool f,const bool i,
          const bool expOk,const string expFill,const string expReason)
  {
   ENUM_ORDER_TYPE_FILLING out=(ENUM_ORDER_TYPE_FILLING)9;
   string why="?";
   bool ok=ResolveFilling(mode,f,i,out,why);
   bool cond=(ok==expOk);
   if(ok==expOk && ok)   cond=(FillTxt(out)==expFill);
   if(ok==expOk && !ok)  cond=(why==expReason);
   if(!expOk && ok)      cond=false;          // failure must never "succeed"
   FTest(sub,cond,"fill-decision",
        StringFormat("mode=%d f=%d i=%d -> ok=%d fill=%s reason=%s",
                     (int)mode,(int)f,(int)i,(int)expOk,expFill,expReason),
        StringFormat("ok=%d fill=%s reason=%s",(int)ok,FillTxt(out),why));
  }

//--- build one deal-read outcome; INJECTING hasT/hasE flags lets the
//    tests push a READ FAILURE into the SAME DealClassify pipeline
//    that BuildSnapshot uses (identical call site).
void MkRead(E9DealRead &r,const bool hasT,const long t,
            const bool hasE,const long e)
  {
   r.hasType=hasT;  r.dealType=t;
   r.hasEntry=hasE; r.dealEntry=e;
  }

//--- deal classification case (shared pipeline)
void DCase(const string sub,const E9DealRead &r,
           const int expCls,const string expWhy,const string desc)
  {
   string why="?";
   int cls=DealClassify(r,why);
   bool cond=(cls==expCls);
   if(cls==expCls && expCls==E9_DC_UNKNOWN) cond=(why==expWhy);
   FTest(sub,cond,desc,
        "class="+DealClassTxt(expCls)+"|why="+expWhy,
        "class="+DealClassTxt(cls)+"|why="+why);
  }

int OnInit()
  {
   g_h=FileOpen(FILL_RESULT_FILE,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(g_h==INVALID_HANDLE)
     { Print("FILLTEST|FAIL|open-results(common):"+FILL_RESULT_FILE); return(INIT_FAILED); }
   FLog("RUN|EXP009-FILL-TEST-R5|ver=R5|runid="+StringFormat("%I64d",(ulong)TimeCurrent()));
   //==================================================================
   // ENVIRONMENTAL INFO (not counted as PASS/FAIL)
   //==================================================================
   FInfo("constants|fillFOK="+(string)(int)SYMBOL_FILLING_FOK+
         "|fillIOC="+(string)(int)SYMBOL_FILLING_IOC+
         "|exeREQ="+(string)(int)SYMBOL_TRADE_EXECUTION_REQUEST+
         "|exeINST="+(string)(int)SYMBOL_TRADE_EXECUTION_INSTANT+
         "|exeMRK="+(string)(int)SYMBOL_TRADE_EXECUTION_MARKET+
         "|exeXCH="+(string)(int)SYMBOL_TRADE_EXECUTION_EXCHANGE);
   FInfo("deal-constants|entryIn="+(string)(int)DEAL_ENTRY_IN+
         "|entryOut="+(string)(int)DEAL_ENTRY_OUT+
         "|entryInOut="+(string)(int)DEAL_ENTRY_INOUT+
         "|entryOutBy="+(string)(int)DEAL_ENTRY_OUT_BY);
   //--- real-symbol wrapper witness (tester context; not a logic assert)
   ENUM_ORDER_TYPE_FILLING wf=(ENUM_ORDER_TYPE_FILLING)9;
   string wr="?";
   bool wok=FillingForSymbol(wf,wr);
   FInfo("env|real-symbol wrapper ok="+(string)(int)wok+
         " fill="+FillTxt(wf)+" reason="+wr+
         " symbol="+_Symbol+" period="+(string)(int)_Period);
   //--- actual common-data path printed for the user
   FInfo("path|"+TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+FILL_RESULT_FILE);
   //==================================================================
   // LOGIC TESTS - fill decision (official table; unchanged from R3)
   //==================================================================
   Case("T01",SYMBOL_TRADE_EXECUTION_REQUEST,false,false,true,"FOK","");
   Case("T02",SYMBOL_TRADE_EXECUTION_REQUEST,false,true,true,"FOK","");
   Case("T03",SYMBOL_TRADE_EXECUTION_REQUEST,true,false,true,"FOK","");
   Case("T04",SYMBOL_TRADE_EXECUTION_INSTANT,false,false,true,"FOK","");
   Case("T05",SYMBOL_TRADE_EXECUTION_INSTANT,true,true,true,"FOK","");
   Case("T06",SYMBOL_TRADE_EXECUTION_MARKET,true,false,true,"FOK","");
   Case("T07",SYMBOL_TRADE_EXECUTION_MARKET,false,true,true,"IOC","");
   Case("T08",SYMBOL_TRADE_EXECUTION_MARKET,true,true,true,"FOK","");
   Case("T09",SYMBOL_TRADE_EXECUTION_MARKET,false,false,false,"","market-mode-needs-FOK-or-IOC-flag");
   Case("T10",SYMBOL_TRADE_EXECUTION_EXCHANGE,true,false,true,"FOK","");
   Case("T11",SYMBOL_TRADE_EXECUTION_EXCHANGE,false,true,true,"IOC","");
   Case("T12",SYMBOL_TRADE_EXECUTION_EXCHANGE,true,true,true,"FOK","");
   Case("T13",SYMBOL_TRADE_EXECUTION_EXCHANGE,false,false,true,"RETURN","");
   Case("T14",99,true,false,false,"","unknown-exec-mode");
   //--- wrapper-level read-failure on the SAME function the adapter calls
   ENUM_ORDER_TYPE_FILLING rf=(ENUM_ORDER_TYPE_FILLING)9;
   string rr="?";
   bool rok=FillingFromProps("__NO_SUCH_SYMBOL__",rf,rr);
   FTest("T15",(!rok && (rr=="filling-mode-unreadable" || rr=="exemode-unreadable")),
        "wrapper-read-failure",
        "ok=0 reason=filling-mode-unreadable|exemode-unreadable",
        StringFormat("ok=%d reason=%s fill=%s",(int)rok,rr,FillTxt(rf)));
   //==================================================================
   // LOGIC TESTS - deal classifier (shared with BuildSnapshot, R4)
   //==================================================================
   E9DealRead d;
   //--- recognized NON-TRADING (official type constants) -> EXCLUDED, no block
   MkRead(d,true,DEAL_TYPE_BALANCE,true,DEAL_ENTRY_IN);
   DCase("T20",d,E9_DC_NONTRADING,"balance-excluded","balance-deal-excluded-no-block");
   MkRead(d,true,DEAL_TYPE_COMMISSION,true,DEAL_ENTRY_OUT);
   DCase("T21",d,E9_DC_NONTRADING,"commission-excluded","commission-deal-excluded-no-block");
   //--- BUY/SELL with INOUT / OUT_BY / unknown entry: UNSUPPORTED -> BLOCK
   MkRead(d,true,DEAL_TYPE_BUY,true,DEAL_ENTRY_INOUT);
   DCase("T22",d,E9_DC_UNKNOWN,"unsupported-entry-for-trading-deal","buy-inout-blocks");
   MkRead(d,true,DEAL_TYPE_SELL,true,DEAL_ENTRY_INOUT);
   DCase("T23",d,E9_DC_UNKNOWN,"unsupported-entry-for-trading-deal","sell-inout-blocks");
   MkRead(d,true,DEAL_TYPE_BUY,true,DEAL_ENTRY_OUT_BY);
   DCase("T24",d,E9_DC_UNKNOWN,"unsupported-entry-for-trading-deal","buy-outby-blocks");
   MkRead(d,true,DEAL_TYPE_SELL,true,DEAL_ENTRY_OUT_BY);
   DCase("T25",d,E9_DC_UNKNOWN,"unsupported-entry-for-trading-deal","sell-outby-blocks");
   MkRead(d,true,DEAL_TYPE_BUY,true,9);
   DCase("T26",d,E9_DC_UNKNOWN,"unsupported-entry-for-trading-deal","buy-unknown-entry-blocks");
   //--- trading classification: BUY/SELL with IN/OUT
   MkRead(d,true,DEAL_TYPE_BUY,true,DEAL_ENTRY_IN);
   DCase("T27",d,E9_DC_TRADE_BUY,"","buy-in-trading");
   MkRead(d,true,DEAL_TYPE_SELL,true,DEAL_ENTRY_OUT);
   DCase("T28",d,E9_DC_TRADE_SELL,"","sell-out-trading");
   //--- unknown enum VALUE (read OK): separate from a read failure
   MkRead(d,true,-1,true,DEAL_ENTRY_IN);
   DCase("T29",d,E9_DC_UNKNOWN,"unknown-deal-type","unknown-enum-type-blocks");
   //--- INJECTED READ FAILURES in the SAME classification pipeline
   //    (read flags false = the select/getter path reports no value)
   MkRead(d,false,0,true,DEAL_ENTRY_IN);
   DCase("T30",d,E9_DC_UNKNOWN,"deal-type-read-failed","injected-type-read-failure-blocks");
   MkRead(d,true,DEAL_TYPE_BUY,false,0);
   DCase("T31",d,E9_DC_UNKNOWN,"deal-entry-read-failed","injected-entry-read-failure-blocks");
   MkRead(d,false,0,false,0);
   DCase("T32",d,E9_DC_UNKNOWN,"deal-type-read-failed","injected-both-read-failure-blocks");
   //==================================================================
   // summary + write verification
   //==================================================================
   FLog("RESULT|"+(g_fail==0?"PASS":"FAIL")+"|logic-tests="+StringFormat("%d",g_pass+g_fail)+
        "|pass="+StringFormat("%d",g_pass)+"|fail="+StringFormat("%d",g_fail)+
        "|info="+StringFormat("%d",g_info));
   int wtotal=(int)FileWrite(g_h,"END|r5");
   FileFlush(g_h);
   FileClose(g_h);
   g_h=INVALID_HANDLE;
   bool exists=FileIsExist(FILL_RESULT_FILE,FILE_COMMON);
   PrintFormat("FILLTEST|DONE|pass=%d fail=%d info=%d via=%s exists=%d wrote=%d",
               g_pass,g_fail,g_info,FILL_RESULT_FILE,(int)exists,wtotal);
   return(INIT_FAILED);   // runner pattern: deliberate; results file is the proof
  }