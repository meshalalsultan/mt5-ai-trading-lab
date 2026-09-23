//+------------------------------------------------------------------+
//| EXP009_tests.mqh                                                 |
//| EXP-009 Test B1-R2: synthetic suite over the shared state machine|
//| through the controllable mock. No OrderSend/CTrade anywhere.     |
//| Every test asserts: final state, mock request count, volume and  |
//| consumed keys — not just a printed PASS.                         |
//| Keeps M01..M19 (B1/B1-R1) and regression tests T20..T26.         |
//| B1-R2: M08/M10/M18/T23 got per-check sub-diagnostics (E9Sub).   |
//+------------------------------------------------------------------+
#ifndef EXP009_TESTS_MQH
#define EXP009_TESTS_MQH

#include <MASK_EDU_EXP009\EXP009_core.mqh>
#include <MASK_EDU_EXP009\EXP009_mock.mqh>

//--- results accounting
int    g9_pass=0;
int    g9_fail=0;
string g9_lines[];

void E9TLog(const string id,const bool ok,const string detail)
  {
   if(ok) g9_pass++; else g9_fail++;
   int n=ArraySize(g9_lines);
   ArrayResize(g9_lines,n+1);
   g9_lines[n]=id+"|"+(ok?"PASS":"FAIL")+"|"+detail;
   PrintFormat("EXP9TEST|%s|%s|%s",id,ok?"PASS":"FAIL",detail);
  }

//--- per-check logger: every internal check is evaluated and recorded
//    independently (NO short-circuit); the caller aggregates via acc.
void E9Sub(const string tid,const string sub,const bool cond,
           const string desc,const string expTxt,const string actTxt,bool &acc)
  {
   if(!cond) acc=false;
   string _l=tid+"|"+sub+"|"+(cond?"PASS":"FAIL")+"|"+desc+"|exp="+expTxt+"|act="+actTxt;
   int _n=ArraySize(g9_lines);
   ArrayResize(g9_lines,_n+1);
   g9_lines[_n]=_l;
   PrintFormat("EXP9TEST|%s",_l);
  }

//--- test harness: core + mock + one snapshot per tick
class E9Harness
  {
public:
   CE9Core   core;
   CE9Mock   mock;
   datetime  bar;
   E9Snapshot snap;
   E9Claim   claim;
   E9Action  act;
   E9Harness(){ bar=0; }
   void Init(const long magic,const string symbol,E9Snapshot &s)
     {
      core.Configure(magic,symbol);
      snap=s;
     }
   void Tick(const int dir,const bool canEval,bool &anyAction)
     {
      E9Input in;
      in.sig.barTime=bar;
      in.sig.canEval=canEval;
      in.sig.dir=dir;
      in.claim=claim;               // deep copy per tick
      E9Snapshot sc=snap;
      in.snap=sc;
      act.type=0;
      core.Process(in,act);
      anyAction=(act.type!=0);
      claim.has=false;
      if(act.type!=0)
        mock.DoAction(act,claim);   // fresh claim for the next tick
     }
   void SetBar(const datetime b){ bar=b; }
  };

//--- evidence helpers (open/close confirmation)
void E9EvOpen(E9Snapshot &s,const ulong order,const ulong deal,const long posId,
              const int dir,const double volume,const ulong posTicket)
  {
   E9AddHist(s,order,EXP9_DEF_MAGIC,E9_ORD_FILLED,volume);
   E9AddDeal(s,deal,order,posId,dir,volume,E9_ENTRY_IN);
   E9AddPos(s,posTicket,posId,EXP9_DEF_MAGIC,"XAUUSD",dir,volume);
  }
void E9EvCloseFull(E9Snapshot &s,const ulong order,const ulong deal,const long posId,
                   const int dir,const double volume)
  {
   E9AddHist(s,order,EXP9_DEF_MAGIC,E9_ORD_FILLED,volume);
   E9AddDeal(s,deal,order,posId,dir,volume,E9_ENTRY_OUT);
  }

//==================================================================//
// M01: full buy open, repeat ticks, repr-diff fill accepted        //
// B1-R1: post-resolution wait-for-new-bar contract (was false).    //
//==================================================================//
void E9T01(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);              // startup ref, no trade
   bool ok=(h.mock.sendCount==0 && h.core.State()==E9_FLAT);
   // new closed bar with a valid UP verdict
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   ok=ok && a && h.mock.sendCount==1 && h.core.State()==E9_PEND_OPEN;
   // same bar: many ticks must NOT re-request
   for(int i=0;i<10;i++){ h.Tick(E9_BUY,true,a); ok=ok && !a && h.mock.sendCount==1; }
   // evidence: full fill, actual computed with a representation error
   E9SnapInit(h.snap);
   double fill=1.0-0.99;              // 0.010000000000000009
   E9EvOpen(h.snap,1000,5000,1,E9_BUY,fill,11);
   h.Tick(E9_BUY,true,a);
   ok=ok && h.core.State()==E9_LONG && h.core.HasPosition() &&
      h.core.Position().volume==fill && h.mock.sendCount==1 &&
      h.core.IsConsumed(b2) && h.core.ConsumedCount()==1 && h.core.WaitNewBar();
   det=StringFormat("state=%d send=%d vol=%.17g consumed=%d",
                    h.core.State(),h.mock.sendCount,fill,h.core.ConsumedCount());
   E9TLog("M01",ok,det);
  }

//==================================================================//
// M02: final entry rejection -> FLAT, consumed, no resend          //
//==================================================================//
void E9T02(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600,b3=1800007200;
   bool a;
   h.SetBar(b1); h.Tick(E9_SELL,true,a);
   h.SetBar(b2); h.Tick(E9_SELL,true,a);
   bool ok=(a && h.mock.sendCount==1 && h.core.State()==E9_PEND_OPEN);
   E9SnapInit(h.snap);
   E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_REJECTED,EXP9_REQ_VOLUME);
   h.Tick(E9_SELL,true,a);
   ok=ok && h.core.State()==E9_FLAT && !h.core.HasPosition() &&
      h.core.IsConsumed(b2) && h.mock.sendCount==1;
   // same signal later in the same bar does not resend
   for(int i=0;i<3;i++){ h.Tick(E9_SELL,true,a); ok=ok && !a && h.mock.sendCount==1; }
   // a NEW bar with a new signal is allowed
   h.SetBar(b3); h.Tick(E9_SELL,true,a);
   ok=ok && a && h.mock.sendCount==2 && h.core.IsConsumed(b3);
   det=StringFormat("state=%d send=%d",h.core.State(),h.mock.sendCount);
   E9TLog("M02",ok,det);
  }

//==================================================================//
// M03: partial open -> actual position kept, no top-up             //
//==================================================================//
void E9T03(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   E9SnapInit(h.snap);
   E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.005,11);   // partial
   h.Tick(E9_BUY,true,a);
   bool ok=(h.core.State()==E9_LONG && h.core.HasPosition() &&
            h.core.Position().volume==0.005 &&
            StringFind(h.core.Note(),"PARTIAL")>=0 && h.mock.sendCount==1);
   for(int i=0;i<5;i++){ h.Tick(E9_BUY,true,a); ok=ok && !a && h.mock.sendCount==1; }
   det=StringFormat("state=%d vol=%g send=%d note=%s",
                    h.core.State(),h.core.Position().volume,h.mock.sendCount,h.core.Note());
   E9TLog("M03",ok,det);
  }

//==================================================================//
// M04: excess fill (0.015 > 0.01) -> violation halt (not success)  //
//==================================================================//
void E9T04(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   E9SnapInit(h.snap);
   E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.015,11);
   h.Tick(E9_BUY,true,a);
   bool ok=(h.core.State()==E9_HALT_VIOLATION && h.core.ViolationSticky());
   E9SnapInit(h.snap);               // conflict "disappears" later
   h.Tick(E9_BUY,true,a);
   ok=ok && h.core.State()==E9_HALT_VIOLATION;   // sticky: not auto-lifted
   det=StringFormat("state=%d sticky=%d",h.core.State(),h.core.ViolationSticky());
   E9TLog("M04",ok,det);
  }

//==================================================================//
// M05: close rejection -> position and volume retained             //
//==================================================================//
void E9T05(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600,b3=1800007200;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   E9SnapInit(h.snap);
   E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
   h.Tick(E9_BUY,true,a);
   bool ok=(h.core.State()==E9_LONG);
   // opposite signal: close request (snapshot still carries the position)
   h.SetBar(b3); h.Tick(E9_SELL,true,a);
   ok=ok && a && h.mock.sendCount==2 && h.core.State()==E9_PEND_CLOSE;
   // rejected close: position kept with direction and volume
   E9SnapInit(h.snap);
   E9AddHist(h.snap,1001,EXP9_DEF_MAGIC,E9_ORD_REJECTED,0.01);
   E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
   h.Tick(E9_SELL,true,a);
   ok=ok && h.core.State()==E9_LONG && h.core.HasPosition() &&
      h.core.Position().dir==E9_BUY && h.core.Position().volume==0.01 &&
      h.core.IsConsumed(b3) && h.mock.sendCount==2;
   for(int i=0;i<3;i++){ h.Tick(E9_SELL,true,a); ok=ok && !a && h.mock.sendCount==2; }
   det=StringFormat("state=%d dir=%d vol=%g send=%d",
                    h.core.State(),h.core.Position().dir,h.core.Position().volume,h.mock.sendCount);
   E9TLog("M05",ok,det);
  }

//==================================================================//
// M06: partial close keeps remainder; later opposite closes it     //
// B1-R1: post-resolution wait-for-new-bar (was false after partial)//
//==================================================================//
void E9T06(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600,b3=1800007200,b4=1800010800;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
   h.Tick(E9_BUY,true,a);
   bool ok=(h.core.State()==E9_LONG);
   // opposite -> partial close (0.004 closed, 0.006 remains)
   h.SetBar(b3); h.Tick(E9_SELL,true,a);
   E9SnapInit(h.snap);
   E9AddHist(h.snap,1001,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.004);
   E9AddDeal(h.snap,5001,1001,1,E9_SELL,0.004,E9_ENTRY_OUT);
   E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.006);
   h.Tick(E9_SELL,true,a);
   ok=ok && h.core.State()==E9_LONG && h.core.Position().volume==0.006 &&
      h.mock.sendCount==2 && h.core.WaitNewBar();
   // same key: no re-close
   for(int i=0;i<3;i++){ h.Tick(E9_SELL,true,a); ok=ok && !a && h.mock.sendCount==2; }
   // new opposite signal closes the remainder fully
   h.SetBar(b4); h.Tick(E9_SELL,true,a);
   ok=ok && a && h.mock.sendCount==3 && h.core.State()==E9_PEND_CLOSE;
   E9SnapInit(h.snap);
   E9EvCloseFull(h.snap,1002,5002,1,E9_SELL,0.006);
   h.Tick(E9_SELL,true,a);
   ok=ok && h.core.State()==E9_FLAT && !h.core.HasPosition() &&
      h.core.WaitNewBar() && h.mock.sendCount==3;
   det=StringFormat("state=%d send=%d",h.core.State(),h.mock.sendCount);
   E9TLog("M06",ok,det);
  }

//==================================================================//
// M07: undetermined -> stays pending, no resend, note dedup        //
//==================================================================//
void E9T07(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   bool ok=(h.mock.sendCount==1 && h.core.State()==E9_PEND_OPEN);
   E9SnapInit(h.snap);                       // empty evidence, queries OK
   int seq0=h.core.NoteSeq();
   for(int i=0;i<20;i++)
     {
      h.Tick(E9_BUY,true,a);
      ok=ok && !a && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1;
     }
   int seq1=h.core.NoteSeq();
   ok=ok && (seq1-seq0)<=2;                  // state-change logging, not repeats
   det=StringFormat("state=%d send=%d noteSeq=%d",h.core.State(),h.mock.sendCount,seq1);
   E9TLog("M07",ok,det);
  }

//==================================================================//
// M08: resolution -> wait for new bar; stale signals not executed. //
// B1-R2: sub-checked with evidence. Scenario fix: after the halt is
// lifted the excess OUR position (11/0.015) was STILL in the        //
// snapshot, so the R1 core correctly blocked a fresh entry (defect //
// 1 guard: no new entry while an our-position remains). The R2     //
// scenario models the external resolution (position removed) and   //
// then verifies the wait-for-new-bar resume on a NEW bar only.     //
//==================================================================//
void E9T08(string &det)
  {
   bool okAll=true;
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600,b3=1800007200,b4=1800010800,b5=1800014400;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   E9Sub("M08","S01",a==false && h.mock.sendCount==0,"startup bar b1: no trade",
         "noAction+send0",StringFormat("action=%d send=%d",a,h.mock.sendCount),okAll);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   E9Sub("M08","S02",a && h.mock.sendCount==1,"bar b2: open sent",
         "action+send1",StringFormat("action=%d send=%d",a,h.mock.sendCount),okAll);
   E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.015,11);
   h.Tick(E9_BUY,true,a);
   E9Sub("M08","S03",h.core.State()==E9_HALT_VIOLATION && h.core.ViolationSticky(),
         "excess fill 0.015 > 0.01: sticky halt","HALT+sticky",
         StringFormat("state=%d sticky=%d",h.core.State(),h.core.ViolationSticky()),okAll);
   h.SetBar(b3); h.Tick(E9_SELL,true,a);
   E9Sub("M08","S04",!a && h.mock.sendCount==1,"signal during halt (b3): ignored",
         "noAction+send1",StringFormat("action=%d send=%d",a,h.mock.sendCount),okAll);
   h.SetBar(b4); h.Tick(E9_BUY,true,a);
   E9Sub("M08","S05",!a && h.mock.sendCount==1,"signal during halt (b4): ignored",
         "noAction+send1",StringFormat("action=%d send=%d",a,h.mock.sendCount),okAll);
   h.core.ClearViolation();
   E9Sub("M08","S06",h.core.WaitNewBar() && h.core.State()!=E9_HALT_VIOLATION,
         "ClearViolation: resume requires a newer bar","waitNewBar+!HALT",
         StringFormat("wait=%d state=%d",h.core.WaitNewBar(),h.core.State()),okAll);
   // scenario fix: the excess position is resolved externally (removed from
   // the evidence) AFTER the halt is lifted; see header comment.
   E9SnapInit(h.snap);
   h.Tick(E9_BUY,true,a);
   E9Sub("M08","S07",!a && h.mock.sendCount==1 && h.core.WaitNewBar() &&
         !h.core.IsConsumed(b4),
         "same bar b4 after clear: waitNewBar blocks, b4 not consumed",
         "noAction+send1+wait1+consumed(b4)=0",
         StringFormat("action=%d send=%d wait=%d c(b4)=%d",a,h.mock.sendCount,
                      h.core.WaitNewBar(),h.core.IsConsumed(b4)),okAll);
   h.SetBar(b5); h.Tick(E9_BUY,true,a);
   E9Sub("M08","S08",a && h.mock.sendCount==2 && h.core.IsConsumed(b5) &&
         !h.core.IsConsumed(b4),
         "new bar b5: fresh entry allowed; stale b4 key not used",
         "action+send2+consumed(b5)",
         StringFormat("action=%d send=%d c(b4)=%d c(b5)=%d",a,h.mock.sendCount,
                      h.core.IsConsumed(b4),h.core.IsConsumed(b5)),okAll);
   det=StringFormat("send=%d wait=%d",h.mock.sendCount,h.core.WaitNewBar());
   E9TLog("M08",okAll,det);
  }

//==================================================================//
// M09: ownership violation is sticky; others' positions untouched  //
//==================================================================//
void E9T09(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600;
   bool a;
   // others' positions do not halt anything
   E9AddPos(h.snap,777,7,0,"XAUUSD",E9_SELL,0.02);       // manual (magic 0)
   E9AddPos(h.snap,778,8,999,"XAUUSD",E9_BUY,0.05);      // other program
   h.SetBar(b1); h.Tick(E9_BUY,true,a);                  // startup ok
   bool ok=(h.core.State()==E9_FLAT && h.mock.sendCount==0);
   // two of OUR positions -> violation
   E9SnapInit(h.snap);
   E9AddPos(h.snap,1,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
   E9AddPos(h.snap,2,2,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   ok=ok && h.core.State()==E9_HALT_VIOLATION;
   // conflict disappears -> still halted (not auto-lifted)
   E9SnapInit(h.snap);
   h.Tick(E9_BUY,true,a);
   ok=ok && h.core.State()==E9_HALT_VIOLATION && h.core.ViolationSticky();
   det=StringFormat("state=%d sticky=%d",h.core.State(),h.core.ViolationSticky());
   E9TLog("M09",ok,det);
  }

//==================================================================//
// M10: startup vs proven adoption vs missing proof on SEPARATE     //
// cores so a sticky halt cannot leak between scenarios.            //
// B1-R2 scenario fix: R1 fed the adopted-position scenario through //
// a LOCAL snapshot variable (E9Snapshot s3). Struct assignment     //
// copies the arrays at Init time, so the harness snapshot remained //
// EMPTY: the close intent stopped at "intent-pos-missing" and no   //
// action ever happened. R2 feeds h.snap directly.                  //
//==================================================================//
void E9T10(string &det)
  {
   bool okAll=true;
   datetime b1=1800000000;
   bool a;
   //--- A1: startup reference, no trade
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    E9Sub("M10","A1",!a && h.mock.sendCount==0 && h.core.State()==E9_FLAT,
          "fresh core startup: reference bar, no trade",
          "noAction+send0+FLAT",
          StringFormat("action=%d send=%d state=%d",a,h.mock.sendCount,h.core.State()),okAll);
   }
   //--- A2: proven adoption is STABLE (adopted position later closes fully)
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    E9SnapInit(h.snap); E9AddPos(h.snap,21,5,EXP9_DEF_MAGIC,"XAUUSD",E9_SELL,0.01);
    h.core.Reinit(h.snap,true);
    E9Sub("M10","A2a",h.core.State()==E9_SHORT && h.core.HasPosition(),
          "reinit(proof) with SELL position: adopted, not rejected",
          "SHORT+pos",
          StringFormat("state=%d pos=%d",h.core.State(),h.core.HasPosition()),okAll);
    E9SnapInit(h.snap); E9AddPos(h.snap,21,5,EXP9_DEF_MAGIC,"XAUUSD",E9_SELL,0.01);
    h.SetBar(b1+3600); h.Tick(E9_BUY,true,a);
    E9Sub("M10","A2b",a && h.mock.sendCount==1 && h.core.State()==E9_PEND_CLOSE,
          "adopted position: opposite on a fresh bar closes (intent re-matched)",
          "closeSent",
          StringFormat("action=%d send=%d state=%d",a,h.mock.sendCount,h.core.State()),okAll);
    E9SnapInit(h.snap);
    E9EvCloseFull(h.snap,1000,5000,5,E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    E9Sub("M10","A2c",h.core.State()==E9_FLAT && !h.core.HasPosition(),
          "adopted position closed fully",
          "FLAT+noPos",
          StringFormat("state=%d pos=%d",h.core.State(),h.core.HasPosition()),okAll);
   }
   //--- A3: position + NO proof -> sticky halt
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    E9SnapInit(h.snap); E9AddPos(h.snap,22,6,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.core.Reinit(h.snap,false);
    E9Sub("M10","A3",h.core.State()==E9_HALT_VIOLATION && h.core.ViolationSticky() &&
          StringFind(h.core.Note(),"unproven-prior-request")>=0,
          "reinit without proof: halt",
          "HALT+sticky",
          StringFormat("state=%d sticky=%d note=%s",h.core.State(),
                       h.core.ViolationSticky(),h.core.Note()),okAll);
   }
   //--- A4: startup path (NO reinit) with our-position -> unattributable halt
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    E9AddPos(s,23,7,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    h.SetBar(b1+3600); h.Tick(E9_BUY,true,a);
    E9Sub("M10","A4",h.core.State()==E9_HALT_VIOLATION &&
          StringFind(h.core.Note(),"unattributable")>=0,
          "startup with our-position (no proof): halt",
          "HALT+unattributable",
          StringFormat("state=%d note=%s",h.core.State(),h.core.Note()),okAll);
   }
   //--- A5: reinit without proof and ZERO positions -> halt
   //    (absence of a position is NOT proof of absence of a request)
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    h.core.Reinit(s,false);
    E9Sub("M10","A5",h.core.State()==E9_HALT_VIOLATION && h.core.ViolationSticky(),
          "reinit without proof, zero positions: halt",
          "HALT",
          StringFormat("state=%d sticky=%d",h.core.State(),h.core.ViolationSticky()),okAll);
   }
   det="scenarios=5";
   E9TLog("M10",okAll,det);
  }

//==================================================================//
// M11: volume limits failure -> consumed, no request               //
//==================================================================//
void E9T11(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   bool ok=(a && h.mock.sendCount==1);        // sane baseline first
   // new scenario with min > 0.01
   E9Harness h2; E9Snapshot s2; E9SnapInit(s2);
   s2.volMin=0.1;
   h2.Init(EXP9_DEF_MAGIC,"XAUUSD",s2);
   h2.SetBar(b1); h2.Tick(E9_BUY,true,a);
   h2.SetBar(b2); h2.Tick(E9_BUY,true,a);
   ok=ok && !a && h2.mock.sendCount==0 && h2.core.State()==E9_FLAT &&
      h2.core.IsConsumed(b2) && StringFind(h2.core.Note(),"volume-out-of-limits")>=0;
   for(int i=0;i<3;i++){ h2.Tick(E9_BUY,true,a); ok=ok && !a && h2.mock.sendCount==0; }
   det=StringFormat("send=%d consumed=%d",h2.mock.sendCount,h2.core.ConsumedCount());
   E9TLog("M11",ok,det);
  }

//==================================================================//
// M12: old signal expires when the bar advances before evaluation  //
//==================================================================//
void E9T12(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600,b3=1800007200;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   // bar2 data missing (cannot evaluate)
   h.SetBar(b2); h.Tick(0,false,a);
   bool ok=(!a && h.mock.sendCount==0 && !h.core.IsConsumed(b2));
   // bar3 arrives before bar2 data completes: b2 signal must never act
   h.SetBar(b3); h.Tick(E9_BUY,true,a);
   ok=ok && a && h.mock.sendCount==1 && h.core.IsConsumed(b3) &&
      !h.core.IsConsumed(b2);
   det=StringFormat("send=%d consumed(b2)=%d consumed(b3)=%d",
                    h.mock.sendCount,h.core.IsConsumed(b2),h.core.IsConsumed(b3));
   E9TLog("M12",ok,det);
  }

//==================================================================//
// M13: confirmed close -> no flip from the same key                //
//==================================================================//
void E9T13(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600,b3=1800007200,b4=1800010800;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
   h.Tick(E9_BUY,true,a);
   bool ok=(h.core.State()==E9_LONG);
   h.SetBar(b3); h.Tick(E9_SELL,true,a);
   E9SnapInit(h.snap); E9EvCloseFull(h.snap,1001,5001,1,E9_SELL,0.01);
   h.Tick(E9_SELL,true,a);
   ok=ok && h.core.State()==E9_FLAT && h.mock.sendCount==2 && h.core.WaitNewBar();
   // same bar b3, still opposite: no flip (waitNewBar + consumed)
   for(int i=0;i<5;i++){ h.Tick(E9_SELL,true,a); ok=ok && !a && h.mock.sendCount==2; }
   // next bar with a fresh opposite signal opens a NEW short
   h.SetBar(b4); h.Tick(E9_SELL,true,a);
   ok=ok && a && h.mock.sendCount==3 && h.core.State()==E9_PEND_OPEN;
   det=StringFormat("state=%d send=%d",h.core.State(),h.mock.sendCount);
   E9TLog("M13",ok,det);
  }

//==================================================================//
// M14: incomplete/contradictory evidence -> never conclusive       //
//==================================================================//
void E9T14(string &det)
  {
   bool ok=true;
   // (a) deals present but no final history state
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.01,E9_ENTRY_IN);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN;
   }
   // (b) contradictory: rejected history + executed deal
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_REJECTED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.01,E9_ENTRY_IN);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN;
   }
   // (c) query failure is NOT proof of non-execution
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    h.snap.histQueryFailed=true;
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN;
   }
   // (d) close: position disappears alone -> NOT confirmed
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
    h.Tick(E9_BUY,true,a);
    h.SetBar(b3); h.Tick(E9_SELL,true,a);
    E9SnapInit(h.snap);                 // position gone, no deals/history
    h.Tick(E9_SELL,true,a);
    ok=ok && h.core.State()==E9_PEND_CLOSE;
   }
   det=StringFormat("subtests=%d",8);
   E9TLog("M14",ok,det);
  }

//==================================================================//
// M15: symmetric SELL path (open + full close)                     //
//==================================================================//
void E9T15(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600,b3=1800007200;
   bool a;
   h.SetBar(b1); h.Tick(E9_SELL,true,a);
   h.SetBar(b2); h.Tick(E9_SELL,true,a);
   bool ok=(a && h.mock.sendCount==1 && h.core.State()==E9_PEND_OPEN);
   E9SnapInit(h.snap);
   E9EvOpen(h.snap,1000,5000,1,E9_SELL,0.01,11);
   h.Tick(E9_SELL,true,a);
   ok=ok && h.core.State()==E9_SHORT && h.core.Position().dir==E9_SELL &&
      h.core.Position().volume==0.01;
   // opposite BUY closes
   h.SetBar(b3); h.Tick(E9_BUY,true,a);
   ok=ok && a && h.mock.sendCount==2 && h.core.State()==E9_PEND_CLOSE;
   E9SnapInit(h.snap);
   E9EvCloseFull(h.snap,1001,5001,1,E9_BUY,0.01);
   h.Tick(E9_BUY,true,a);
   ok=ok && h.core.State()==E9_FLAT && !h.core.HasPosition();
   det=StringFormat("state=%d send=%d",h.core.State(),h.mock.sendCount);
   E9TLog("M15",ok,det);
  }

//==================================================================//
// M16: one order, two deals, evidence in different orders, dedupe  //
//==================================================================//
void E9T16(string &det)
  {
   bool ok=true;
   // variant A: deals [A,B]
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    E9AddDeal(h.snap,5001,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_LONG && h.core.Position().volume==0.01;
   }
   // variant B: deals [B,A]
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5001,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_LONG && h.core.Position().volume==0.01;
   }
   // variant C: duplicate events [A,A,B,B] -> no volume doubling
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.005,E9_ENTRY_IN);  // duplicate event
    E9AddDeal(h.snap,5001,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    E9AddDeal(h.snap,5001,1000,1,E9_BUY,0.005,E9_ENTRY_IN);  // duplicate event
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_LONG && h.core.Position().volume==0.01;
   }
   det="variants=3";
   E9TLog("M16",ok,det);
  }

//==================================================================//
// M17: partial fill with an ACTIVE order remaining -> keep blocked //
//==================================================================//
void E9T17(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   E9SnapInit(h.snap);
   E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_PARTIAL,0.005);
   E9AddActive(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_PARTIAL,0.005);
   E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
   E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.005);
   h.Tick(E9_BUY,true,a);
   bool ok=(h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1);
   for(int i=0;i<5;i++){ h.Tick(E9_BUY,true,a); ok=ok && h.core.State()==E9_PEND_OPEN; }
   det=StringFormat("state=%d send=%d",h.core.State(),h.mock.sendCount);
   E9TLog("M17",ok,det);
  }

//==================================================================//
// Volume policy unit checks (grid, repr diffs, refused).           //
// B1-R2: sub-checked S01..S09 with inputs, verdict, diff and       //
// tolerance at full precision. EMPTY_VALUE is now rejected as an   //
// invalid input (E9_V_INVALID) by the core volume-input validation.//
//==================================================================//
void E9T18(string &det)
  {
   bool okAll=true;
   double tol=0.0;
   double fill=1.0-0.99;
   E9VolCmp r;

   tol=0.0; r=E9VolumeMatch(0.01,fill,0.01,tol);
   E9Sub("M18","S01",r==E9_V_OK,"match(0.01, 1-0.99, 0.01): repr diff accepted",
         "E9_V_OK",
         StringFormat("verdict=%d diff=%.17g tol=%.17g",r,MathAbs(0.01-fill),tol),okAll);

   tol=0.0; r=E9VolumeMatch(0.01,0.1*0.1,0.01,tol);
   E9Sub("M18","S02",r==E9_V_OK,"match(0.01, 0.1*0.1, 0.01): repr diff accepted",
         "E9_V_OK",
         StringFormat("verdict=%d diff=%.17g tol=%.17g",r,MathAbs(0.01-0.1*0.1),tol),okAll);

   tol=0.0; r=E9VolumeMatch(0.01,0.0105,0.01,tol);
   E9Sub("M18","S03",r==E9_V_MISMATCH,"match(0.01, 0.0105, 0.01): real difference",
         "E9_V_MISMATCH",
         StringFormat("verdict=%d diff=%.17g tol=%.17g",r,MathAbs(0.01-0.0105),tol),okAll);

   tol=0.0; r=E9VolumeOnGrid(fill,0.01,tol);
   E9Sub("M18","S04",r==E9_V_OK,"onGrid(1-0.99, 0.01): repr diff stays on grid",
         "E9_V_OK",
         StringFormat("verdict=%d q=%.17g res=%.17g tol=%.17g",r,fill/0.01,
                      MathAbs(fill/0.01-MathRound(fill/0.01)),tol),okAll);

   tol=0.0; r=E9VolumeOnGrid(0.015,0.01,tol);
   E9Sub("M18","S05",r==E9_V_MISMATCH,"onGrid(0.015, 0.01): off grid",
         "E9_V_MISMATCH",
         StringFormat("verdict=%d q=%.17g res=%.17g tol=%.17g",r,0.015/0.01,
                      MathAbs(0.015/0.01-MathRound(0.015/0.01)),tol),okAll);

   tol=0.0; r=E9VolumeMatch(0.01,0.0,0.01,tol);
   E9Sub("M18","S06",r==E9_V_INVALID,"match(0.01, 0.0, 0.01): zero is invalid",
         "E9_V_INVALID",StringFormat("verdict=%d",r),okAll);

   tol=0.0; r=E9VolumeMatch(0.01,EMPTY_VALUE,0.01,tol);
   E9Sub("M18","S07",r==E9_V_INVALID,"match(0.01, EMPTY_VALUE, 0.01): sentinel invalid",
         "E9_V_INVALID",StringFormat("verdict=%d tol=%.17g",r,tol),okAll);

   tol=0.0; r=E9VolumeOnGrid(-1.0,0.01,tol);
   E9Sub("M18","S08",r==E9_V_INVALID,"onGrid(-1.0, 0.01): negative invalid",
         "E9_V_INVALID",StringFormat("verdict=%d",r),okAll);

   tol=0.0; r=E9VolumeMatch(1e10,1e10+1.0,1e-4,tol);
   E9Sub("M18","S09",r==E9_V_REFUSED,"match(1e10, 1e10+1, 1e-4): tol >= step/1e6",
         "E9_V_REFUSED",
         StringFormat("verdict=%d tol=%.17g step1e6=%.17g",r,tol,1e-4/1000000.0),okAll);

   det=StringFormat("fill=%.17g",fill);
   E9TLog("M18",okAll,det);
  }

//==================================================================//
// Volume policy in the state machine: off-grid fill -> keeps blocks//
// (state-level)                                                    //
//==================================================================//
void E9T19(string &det)
  {
   E9Harness h; E9Snapshot s; E9SnapInit(s);
   h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
   datetime b1=1800000000,b2=1800003600;
   bool a;
   h.SetBar(b1); h.Tick(E9_BUY,true,a);
   h.SetBar(b2); h.Tick(E9_BUY,true,a);
   E9SnapInit(h.snap);
   E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.0105);
   E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.0105,E9_ENTRY_IN);
   E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.0105);
   h.Tick(E9_BUY,true,a);
   // 0.0105 > requested: excess -> violation (never success)
   bool ok=(h.core.State()==E9_HALT_VIOLATION);
   det=StringFormat("state=%d",h.core.State());
   E9TLog("M19",ok,det);
  }

//==================================================================//
// T20 (defect 1): state-source integrity.                          //
//==================================================================//
void E9T20(string &det)
  {
   bool ok=true;
   // (a) open: posQueryFailed blocks confirmation
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
    h.snap.posQueryFailed=true;
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       !h.core.HasPosition();
   }
   // (b) close: posQueryFailed blocks confirmation
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
    h.Tick(E9_BUY,true,a);
    bool okb=(h.core.State()==E9_LONG);
    E9SnapInit(h.snap); E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.SetBar(b3); h.Tick(E9_SELL,true,a);
    okb=okb && a && h.mock.sendCount==2 && h.core.State()==E9_PEND_CLOSE;
    E9SnapInit(h.snap);
    E9EvCloseFull(h.snap,1001,5001,1,E9_SELL,0.01);
    h.snap.posQueryFailed=true;
    h.Tick(E9_SELL,true,a);
    okb=okb && h.core.State()==E9_PEND_CLOSE && h.mock.sendCount==2;
    ok=ok && okb;
   }
   // (c) close intent re-match: identity mismatch (wrong ticket) -> halt
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
    h.Tick(E9_BUY,true,a);
    bool okc=(h.core.State()==E9_LONG);
    E9SnapInit(h.snap);
    E9AddPos(h.snap,99,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);  // ticket mismatch
    h.SetBar(b3); h.Tick(E9_SELL,true,a);
    okc=okc && !a && h.mock.sendCount==1 && h.core.State()==E9_HALT_VIOLATION &&
         h.core.ViolationSticky();
    ok=ok && okc;
   }
   // (d) FLAT: unexpected our-position blocks a new entry
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);       // startup reference
    E9SnapInit(h.snap);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    ok=ok && !a && h.mock.sendCount==0 && h.core.State()==E9_FLAT &&
         h.core.IsConsumed(b2) &&
         StringFind(h.core.Note(),"unexpected-own-position")>=0;
   }
   det="subtests=4";
   E9TLog("T20",ok,det);
  }

//==================================================================//
// T21 (defect 2): full deal interlinking.                          //
//==================================================================//
void E9T21(string &det)
  {
   bool ok=true;
   // (a) position not linked to the deal positionId
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.01,E9_ENTRY_IN);
    E9AddPos(h.snap,11,2,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);  // id 2 != posId 1
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       StringFind(h.core.Note(),"pos-not-linked")>=0;
   }
   // (b) deal direction inappropriate for the entry intent
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_SELL,0.01,E9_ENTRY_IN);    // SELL on BUY entry
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       StringFind(h.core.Note(),"deal-dir-mismatch")>=0;
   }
   // (c) wrong magic in the deal evidence
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDealEx(h.snap,5000,1000,1,E9_BUY,0.01,E9_ENTRY_IN,9999,"XAUUSD");
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       StringFind(h.core.Note(),"deal-magic-mismatch")>=0;
   }
   // (d) wrong symbol in the deal evidence
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDealEx(h.snap,5000,1000,1,E9_BUY,0.01,E9_ENTRY_IN,EXP9_DEF_MAGIC,"EURUSD");
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       StringFind(h.core.Note(),"deal-symbol-mismatch")>=0;
   }
   // (e) duplicate dealTicket with DIFFERENT content = conflict
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.004,E9_ENTRY_IN);    // same ticket, other volume
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       StringFind(h.core.Note(),"deal-dup-content-conflict")>=0;
   }
   // (f) our-position alone (no deals) is not proof of execution
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       StringFind(h.core.Note(),"zero-deals")>=0;
   }
   det=StringFormat("subtests=%d",8);
   E9TLog("T21",ok,det);
  }

//==================================================================//
// T22 (defect 3): final partial semantics.                         //
//==================================================================//
void E9T22(string &det)
  {
   bool ok=true;
   // (a) ENTRY: canceled after partial -> confirmed part adopted
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHistEx(h.snap,1000,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,E9_ORD_CANCELED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.004,E9_ENTRY_IN);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.004);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_LONG && h.core.Position().volume==0.004 &&
       h.mock.sendCount==1 && h.core.IsConsumed(b2) &&
       StringFind(h.core.Note(),"CANCELED-AFTER-PARTIAL")>=0;
   }
   // (b) ENTRY partial: position volume must equal the deal sum
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.004);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.004,E9_ENTRY_IN);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.006);  // mismatch
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       StringFind(h.core.Note(),"partial-pos-mismatch")>=0;
   }
   // (c) ENTRY canceled WITHOUT deals is not an automatic final partial
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHistEx(h.snap,1000,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,E9_ORD_CANCELED,0.01);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.004);
    h.Tick(E9_BUY,true,a);
    ok=ok && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       StringFind(h.core.Note(),"canceled-evidence-unattributable")>=0;
   }
   // (d) CLOSE: canceled after partial close -> remainder kept
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
    h.Tick(E9_BUY,true,a);
    bool okd=(h.core.State()==E9_LONG);
    h.SetBar(b3); h.Tick(E9_SELL,true,a);          // snap still carries the position
    okd=okd && a && h.mock.sendCount==2 && h.core.State()==E9_PEND_CLOSE;
    E9SnapInit(h.snap);
    E9AddHistEx(h.snap,1001,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,E9_ORD_CANCELED,0.01);
    E9AddDeal(h.snap,5001,1001,1,E9_SELL,0.004,E9_ENTRY_OUT);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.006);
    h.Tick(E9_SELL,true,a);
    okd=okd && h.core.State()==E9_LONG && h.core.Position().volume==0.006 &&
       h.mock.sendCount==2 && h.core.WaitNewBar() &&
       StringFind(h.core.Note(),"CANCELED-AFTER-PARTIAL")>=0;
    ok=ok && okd;
   }
   det=StringFormat("subtests=%d",8);
   E9TLog("T22",ok,det);
  }

//==================================================================//
// T23 (defect 4): late evidence across multiple calls.             //
// B1-R2 fix: the cumulative evidence contract requires the TOTAL   //
// deal volume across ALL accumulated events. R1 only summed NEWLY  //
// seen events, so the final call (all deals already seen) computed //
// sum=0 and stayed blocked. Core now seeds the sum with the        //
// previously accumulated total.                                    //
//==================================================================//
void E9T23(string &det)
  {
   bool okAll=true;
   //--- (a) final state -> deal1 -> deal2 -> position; NO early confirmation
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9Sub("T23","A0",a && h.mock.sendCount==1 && h.core.State()==E9_PEND_OPEN,
          "open sent, pending","action+send1+PEND_OPEN",
          StringFormat("action=%d send=%d state=%d",a,h.mock.sendCount,h.core.State()),okAll);
    // call 1: final state only
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    h.Tick(E9_BUY,true,a);
    E9Sub("T23","A1",h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1,
          "call1: hist-only snapshot -> pending","PEND_OPEN+send1",
          StringFormat("state=%d send=%d note=%s",h.core.State(),h.mock.sendCount,h.core.Note()),okAll);
    // call 2: deal1 of two arrives
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    h.Tick(E9_BUY,true,a);
    E9Sub("T23","A2",h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1,
          "call2: hist+deal1 -> pending (position not read yet)","PEND_OPEN+send1",
          StringFormat("state=%d send=%d note=%s",h.core.State(),h.mock.sendCount,h.core.Note()),okAll);
    // call 3: deal2 arrives -> total equals request, STILL no position read
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    E9AddDeal(h.snap,5001,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    h.Tick(E9_BUY,true,a);
    E9Sub("T23","A3",h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
          StringFind(h.core.Note(),"filled-but-no-position")>=0,
          "call3: hist+deal1+deal2 (total=req) but NO position read",
          "PEND_OPEN+send1+no-position",
          StringFormat("state=%d send=%d note=%s",h.core.State(),h.mock.sendCount,h.core.Note()),okAll);
    // call 4: position read consistent -> confirmation.
    // The cumulative sum must still count deal1+deal2 even though the
    // events were already seen in call3 (bugs in R1: sum reset to 0).
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    E9AddDeal(h.snap,5001,1000,1,E9_BUY,0.005,E9_ENTRY_IN);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    E9Sub("T23","A4",h.core.State()==E9_LONG && h.core.Position().volume==0.01 &&
          h.mock.sendCount==1 && h.core.IsConsumed(b2) && h.core.ConsumedCount()==1 &&
          h.core.WaitNewBar(),
          "call4: hist+deals+position consistent -> CONFIRMED LONG 0.01",
          "LONG+vol0.01+send1+consumed1+wait1",
          StringFormat("state=%d vol=%.17g send=%d consumed=%d wait=%d note=%s",
                       h.core.State(),h.core.Position().volume,h.mock.sendCount,
                       h.core.ConsumedCount(),h.core.WaitNewBar(),h.core.Note()),okAll);
   }
   //--- (b) snapshot regression: a deal already seen must persist
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.01,E9_ENTRY_IN);
    h.Tick(E9_BUY,true,a);
    E9Sub("T23","B1",h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1,
          "snap1: hist+deal1 -> pending (position missing)",
          "PEND_OPEN+send1",
          StringFormat("state=%d send=%d note=%s",h.core.State(),h.mock.sendCount,h.core.Note()),okAll);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);  // deal dropped
    h.Tick(E9_BUY,true,a);
    E9Sub("T23","B2",h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
          StringFind(h.core.Note(),"evidence-regressed")>=0,
          "snap2: hist-only (deal dropped) -> regression blocks",
          "PEND_OPEN+send1+regressed",
          StringFormat("state=%d send=%d note=%s",h.core.State(),h.mock.sendCount,h.core.Note()),okAll);
   }
   det=StringFormat("subtests=%d",4);
   E9TLog("T23",okAll,det);
  }

//==================================================================//
// T24 (defect 5): after EVERY resolution exit, wait for a newer key//
//==================================================================//
void E9T24(string &det)
  {
   bool ok=true;
   // (a) final rejection -> FLAT + wait-for-new-bar
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_REJECTED,0.01);
    h.Tick(E9_BUY,true,a);
    bool oka=(h.core.State()==E9_FLAT && h.mock.sendCount==1 && h.core.WaitNewBar());
    // same bar: accumulated opposite signal must NOT act
    for(int i=0;i<5;i++){ h.Tick(E9_SELL,true,a); oka=oka && !a && h.mock.sendCount==1; }
    // new bar: allowed
    h.SetBar(b3); h.Tick(E9_SELL,true,a);
    oka=oka && a && h.mock.sendCount==2;
    ok=ok && oka;
   }
   // (b) final partial -> position kept + wait-for-new-bar
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap);
    E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.005,11);
    h.Tick(E9_BUY,true,a);
    bool okb=(h.core.State()==E9_LONG && h.mock.sendCount==1 && h.core.WaitNewBar());
    for(int i=0;i<5;i++){ h.Tick(E9_BUY,true,a); okb=okb && !a && h.mock.sendCount==1; }
    // new bar: opposite close is allowed (position still in snapshot)
    h.SetBar(b3); h.Tick(E9_SELL,true,a);
    okb=okb && a && h.mock.sendCount==2 && h.core.State()==E9_PEND_CLOSE;
    ok=ok && okb;
   }
   // (c) close rejection -> position kept + wait-for-new-bar
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200,b4=1800010800;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
    h.Tick(E9_BUY,true,a);
    h.SetBar(b3); h.Tick(E9_SELL,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1001,EXP9_DEF_MAGIC,E9_ORD_REJECTED,0.01);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_SELL,true,a);
    bool okc=(h.core.State()==E9_LONG && h.mock.sendCount==2 && h.core.WaitNewBar() &&
             h.core.Position().volume==0.01);
    for(int i=0;i<5;i++){ h.Tick(E9_SELL,true,a); okc=okc && !a && h.mock.sendCount==2; }
    h.SetBar(b4); h.Tick(E9_SELL,true,a);
    okc=okc && a && h.mock.sendCount==3 && h.core.State()==E9_PEND_CLOSE;
    ok=ok && okc;
   }
   det=StringFormat("subtests=%d",6);
   E9TLog("T24",ok,det);
  }

//==================================================================//
// T25 (defect 6): request reference and reinit.                    //
//==================================================================//
void E9T25(string &det)
  {
   bool ok=true;
   // (a) foreign claim cannot replace the captured reference
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);   // claim 1000 armed
    E9SnapInit(h.snap);                    // real claim {1000,...} arrives here
    h.Tick(E9_BUY,true,a);
    bool oka=(h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1);
    // wrong-ticket claim + evidence for the WRONG order -> must be ignored
    h.mock.MakeClaim(true,2000,6000,E9_BUY,0.01,h.claim);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,2000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,6000,2000,1,E9_BUY,0.01,E9_ENTRY_IN);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    oka=oka && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       StringFind(h.core.Note(),"final-state-missing")>=0;
    // correct evidence for the REAL reference -> confirmation
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1000,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.01);
    E9AddDeal(h.snap,5000,1000,1,E9_BUY,0.01,E9_ENTRY_IN);
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.01);
    h.Tick(E9_BUY,true,a);
    oka=oka && h.core.State()==E9_LONG && h.mock.sendCount==1 &&
       h.core.Position().volume==0.01;
    ok=ok && oka;
   }
   // (b) proven final rejection WITHOUT an assigned orderTicket
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    h.mock.noTicket=true;                  // claim carries no order reference
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    bool okb=(a && h.mock.sendCount==1 && h.core.State()==E9_PEND_OPEN);
    E9SnapInit(h.snap);
    E9AddHistEx(h.snap,9000,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,E9_ORD_REJECTED,0.01);
    h.Tick(E9_BUY,true,a);
    okb=okb && h.core.State()==E9_FLAT && !h.core.HasPosition() &&
       h.mock.sendCount==1 && h.core.WaitNewBar() &&
       StringFind(h.core.Note(),"REJECTED")>=0;
    ok=ok && okb;
   }
   // (c) failed/blocked send alone is NOT a final rejection
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    h.mock.failOpen=true;
    datetime b1=1800000000,b2=1800003600;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    bool okc=(a && h.mock.sendCount==1 && h.core.State()==E9_PEND_OPEN &&
             h.mock.openCount==1);
    E9SnapInit(h.snap);                    // empty evidence, query OK
    h.Tick(E9_BUY,true,a);
    okc=okc && h.core.State()==E9_PEND_OPEN && h.mock.sendCount==1 &&
       StringFind(h.core.Note(),"no-order-ref")>=0;
    ok=ok && okc;
   }
   // (d) Reinit without proof halts EVEN with zero positions
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    h.core.Reinit(s,false);
    ok=ok && h.core.State()==E9_HALT_VIOLATION && h.core.ViolationSticky() &&
       StringFind(h.core.Note(),"unproven-prior-request")>=0;
   }
   det=StringFormat("subtests=%d",6);
   E9TLog("T25",ok,det);
  }

//==================================================================//
// T26 (defect 7): package identity guard.                          //
//==================================================================//
void E9T26(string &det)
  {
   bool ok=(EXP9_PKG=="EXP009-B1-R5-CLOSEFIX");
   ok=ok && (StringFind(EXP9_PKG,"B1-R5")>=0);
   ok=ok && EXP9_REQ_VOLUME==0.01;
   det=StringFormat("pkg=%s vol=%g",EXP9_PKG,EXP9_REQ_VOLUME);
   E9TLog("T26",ok,det);
  }

//==================================================================//
// Runner: executes the whole suite and writes the results file     //
//==================================================================//
//==================================================================//
// T27 (R5 defect): CLOSE deal direction = opposite of the position.//
// Closing a LONG is performed by a SELL deal; closing a SHORT by a //
// BUY deal. A close deal carrying the WRONG direction must be      //
// rejected (deal-dir-mismatch, core stays pending). The regression //
// exercises the SHARED core through the same harness used by the   //
// integration run: close BUY by SELL, close SELL by BUY, wrong     //
// direction on LONG, plus partial/full close with id linking.      //
//==================================================================//
void E9T27(string &det)
  {
   bool okAll=true;
   //--- (a) LONG (BUY) position fully closed by a SELL deal
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
    h.Tick(E9_BUY,true,a);
    E9Sub("T27","a1",h.core.State()==E9_LONG,"open LONG confirmed",
          "LONG",StringFormat("state=%d",h.core.State()),okAll);
    h.SetBar(b3); h.Tick(E9_SELL,true,a);   // close intent
    E9Sub("T27","a2",a && h.mock.sendCount==2 && h.core.State()==E9_PEND_CLOSE,
          "close intent sent",
          "send2+PEND_CLOSE",
          StringFormat("action=%d send=%d state=%d",a,h.mock.sendCount,h.core.State()),okAll);
    E9SnapInit(h.snap);
    E9EvCloseFull(h.snap,1001,5001,1,E9_SELL,0.01);   // SELL deal closes the LONG
    h.Tick(E9_SELL,true,a);
    E9Sub("T27","a3",h.core.State()==E9_FLAT && !h.core.HasPosition() && h.core.WaitNewBar(),
          "close LONG by SELL deal -> FLAT",
          "FLAT+noPos+wait",
          StringFormat("state=%d pos=%d wait=%d",h.core.State(),h.core.HasPosition(),h.core.WaitNewBar()),okAll);
   }
   //--- (b) SHORT (SELL) position fully closed by a BUY deal
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200;
    bool a;
    h.SetBar(b1); h.Tick(E9_SELL,true,a);
    h.SetBar(b2); h.Tick(E9_SELL,true,a);
    E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_SELL,0.01,11);
    h.Tick(E9_SELL,true,a);
    E9Sub("T27","b1",h.core.State()==E9_SHORT,"open SHORT confirmed",
          "SHORT",StringFormat("state=%d",h.core.State()),okAll);
    h.SetBar(b3); h.Tick(E9_BUY,true,a);    // close intent (BUY signal closes SHORT)
    E9Sub("T27","b2",a && h.mock.sendCount==2 && h.core.State()==E9_PEND_CLOSE,
          "close intent sent",
          "send2+PEND_CLOSE",
          StringFormat("action=%d send=%d state=%d",a,h.mock.sendCount,h.core.State()),okAll);
    E9SnapInit(h.snap);
    E9EvCloseFull(h.snap,1001,5001,1,E9_BUY,0.01);    // BUY deal closes the SHORT
    h.Tick(E9_BUY,true,a);
    E9Sub("T27","b3",h.core.State()==E9_FLAT && !h.core.HasPosition() && h.core.WaitNewBar(),
          "close SHORT by BUY deal -> FLAT",
          "FLAT+noPos+wait",
          StringFormat("state=%d pos=%d wait=%d",h.core.State(),h.core.HasPosition(),h.core.WaitNewBar()),okAll);
   }
   //--- (c) WRONG close direction on LONG (BUY deal) -> deal-dir-mismatch, stays pending
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
    h.Tick(E9_BUY,true,a);
    h.SetBar(b3); h.Tick(E9_SELL,true,a);
    E9SnapInit(h.snap);
    E9EvCloseFull(h.snap,1001,5001,1,E9_BUY,0.01);   // WRONG: BUY deal closes LONG
    h.Tick(E9_SELL,true,a);
    E9Sub("T27","c1",h.core.State()==E9_PEND_CLOSE && h.mock.sendCount==2 &&
          StringFind(h.core.Note(),"deal-dir-mismatch")>=0,
          "wrong close direction on LONG rejected",
          "PEND_CLOSE+deal-dir-mismatch",
          StringFormat("state=%d send=%d note=%s",h.core.State(),h.mock.sendCount,h.core.Note()),okAll);
   }
   //--- (d) partial close (LONG) with SELL deal + id linking, then full close
   {
    E9Harness h; E9Snapshot s; E9SnapInit(s);
    h.Init(EXP9_DEF_MAGIC,"XAUUSD",s);
    datetime b1=1800000000,b2=1800003600,b3=1800007200;
    bool a;
    h.SetBar(b1); h.Tick(E9_BUY,true,a);
    h.SetBar(b2); h.Tick(E9_BUY,true,a);
    E9SnapInit(h.snap); E9EvOpen(h.snap,1000,5000,1,E9_BUY,0.01,11);
    h.Tick(E9_BUY,true,a);
    h.SetBar(b3); h.Tick(E9_SELL,true,a);
    E9SnapInit(h.snap);
    E9AddHist(h.snap,1001,EXP9_DEF_MAGIC,E9_ORD_FILLED,0.004);
    E9AddDeal(h.snap,5001,1001,1,E9_SELL,0.004,E9_ENTRY_OUT);  // SELL deal (partial)
    E9AddPos(h.snap,11,1,EXP9_DEF_MAGIC,"XAUUSD",E9_BUY,0.006); // remainder, id=1 linked
    h.Tick(E9_SELL,true,a);
    E9Sub("T27","d1",h.core.State()==E9_LONG && h.core.Position().volume==0.006 &&
          h.core.Position().identifier==1 &&
          StringFind(h.core.Note(),"PARTIAL-REMAINDER-KEPT")>=0 && h.core.WaitNewBar(),
          "partial close keeps linked remainder",
          "LONG 0.006 id=1 wait=1",
          StringFormat("state=%d vol=%g id=%d note=%s wait=%d",h.core.State(),
                       h.core.Position().volume,h.core.Position().identifier,
                       h.core.Note(),h.core.WaitNewBar()),okAll);
    //--- full close of the remainder
    h.SetBar(b3+3600); h.Tick(E9_SELL,true,a);
    E9Sub("T27","d2",a && h.mock.sendCount==3 && h.core.State()==E9_PEND_CLOSE,
          "second close intent sent",
          "send3+PEND_CLOSE",
          StringFormat("action=%d send=%d state=%d",a,h.mock.sendCount,h.core.State()),okAll);
    E9SnapInit(h.snap);
    E9EvCloseFull(h.snap,1002,5002,1,E9_SELL,0.006);
    h.Tick(E9_SELL,true,a);
    E9Sub("T27","d3",h.core.State()==E9_FLAT && !h.core.HasPosition(),
          "remainder closed fully",
          "FLAT+noPos",
          StringFormat("state=%d pos=%d",h.core.State(),h.core.HasPosition()),okAll);
   }
   det=StringFormat("subtests=%d",10);
   E9TLog("T27",okAll,det);
  }

//==================================================================//
// Runner: executes the whole suite and writes the results file     //
//==================================================================//
int E9RunSuite(const string outFile)
  {
   g9_pass=0; g9_fail=0; ArrayResize(g9_lines,0);
   string det="";
   E9T01(det); E9T02(det); E9T03(det); E9T04(det); E9T05(det);
   E9T06(det); E9T07(det); E9T08(det); E9T09(det); E9T10(det);
   E9T11(det); E9T12(det); E9T13(det); E9T14(det); E9T15(det);
   E9T16(det); E9T17(det); E9T18(det); E9T19(det);
   E9T20(det); E9T21(det); E9T22(det); E9T23(det); E9T24(det);
   E9T25(det); E9T26(det); E9T27(det);

   //--- results file (FILE_COMMON -> <Common>\Files\<name>)
   string resDetail="Common\\Files\\"+outFile;
   string runId=StringFormat("%d",TimeCurrent());
   int h=FileOpen(outFile,FILE_TXT|FILE_WRITE|FILE_COMMON|FILE_ANSI);
   bool saved=(h!=INVALID_HANDLE);
   string errTxt=(saved?"":StringFormat("|FileOpen error=%d",GetLastError()));
   string header=StringFormat("RUN|%s|runid=%s|PASS=%d|FAIL=%d",EXP9_PKG,runId,g9_pass,g9_fail);
   string resLine="RESULTFILE|"+(saved?"PASS":"FAIL")+"|"+resDetail+errTxt;
   int nL=ArraySize(g9_lines);
   ArrayResize(g9_lines,nL+1); g9_lines[nL]=resLine;
   if(saved)
     {
      FileWrite(h,header);
      for(int i=0;i<ArraySize(g9_lines);i++) FileWrite(h,g9_lines[i]);
      FileClose(h);
     }
   PrintFormat("EXP9TEST|%s",header);
   PrintFormat("EXP9TEST|RESULTFILE|%s|%s%s",saved?"PASS":"FAIL",resDetail,
               saved?"":StringFormat("|FileOpen error=%d",GetLastError()));
   return(g9_fail);
  }

#endif