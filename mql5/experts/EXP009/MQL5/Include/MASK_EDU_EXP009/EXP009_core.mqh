//+------------------------------------------------------------------+
//| EXP009_core.mqh                                                  |
//| EXP-009 Test B1-R1: shared execution state machine + interlinked |
//| confirmation core. Educational, tester-only design. NO OrderSend/|
//| CTrade here.                                                      |
//| Evidence contract (late evidence): CUMULATIVE full-range history |
//| snapshots with regression detection — evidence already seen for  |
//| the pending request must persist in every later snapshot, and    |
//| deals are aggregated across calls with content-conflict checks.  |
//| Evidence is NEVER assumed from a send result (claims are claims).|
//+------------------------------------------------------------------+
#ifndef EXP009_CORE_MQH
#define EXP009_CORE_MQH

//--- package identity (bound to results for traceability)
#define EXP9_PKG "EXP009-B1-R5-CLOSEFIX"
#define EXP9_REQ_VOLUME 0.01
#define EXP9_DEF_MAGIC 0xE9B1

//--- directions (own convention)
#define E9_BUY       1
#define E9_SELL     -1

//--- order states used in evidence (own constants; mirror MQL5)
#define E9_ORD_STARTED   0
#define E9_ORD_PLACED    1
#define E9_ORD_CANCELED  2
#define E9_ORD_PARTIAL   3
#define E9_ORD_FILLED    4
#define E9_ORD_REJECTED  5

//--- deal entry
#define E9_ENTRY_IN  0
#define E9_ENTRY_OUT 1

//--- machine states
enum E9State
  {
   E9_FLAT=0,
   E9_LONG,              // confirmed owned long position
   E9_SHORT,             // confirmed owned short position
   E9_PEND_OPEN,         // open order sent; awaiting conclusive evidence
   E9_PEND_CLOSE,        // close order sent; awaiting conclusive evidence
   E9_HALT_VIOLATION     // gross ownership/volume/direction violation (sticky)
  };

//--- volume comparison verdict (representation-error policy only)
enum E9VolCmp
  {
   E9_V_OK=0,
   E9_V_MISMATCH,
   E9_V_INVALID,
   E9_V_REFUSED          // numeric evaluation refused (tol >= step/1e6)
  };

//--- evidence structures
struct E9Position
  {
   ulong  ticket;
   long   identifier;
   long   magic;
   string symbol;
   int    dir;           // E9_BUY / E9_SELL
   double volume;
  };

struct E9OrderInfo
  {
   ulong  ticket;
   long   magic;
   string symbol;
   int    dir;           // E9_BUY / E9_SELL (attribution; 0 = unknown)
   int    status;        // E9_ORD_*
   double volume;
  };

struct E9DealInfo
  {
   ulong  dealTicket;
   ulong  orderTicket;
   long   positionId;
   int    dir;
   double volume;
   int    entry;         // E9_ENTRY_IN / E9_ENTRY_OUT
   long   magic;
   string symbol;
  };

struct E9Snapshot
  {
   E9Position pos[];      // current positions (ours and others')
   E9OrderInfo actOrd[];  // active (unfinished) orders
   E9OrderInfo histOrd[]; // final-state orders
   E9DealInfo  deals[];   // deals
   //--- query integrity (failure is NOT evidence of non-execution)
   bool posQueryFailed;
   bool actQueryFailed;
   bool histQueryFailed;
   bool dealsQueryFailed;
   //--- symbol volume limits
   double volMin;
   double volMax;
   double volStep;
  };

//--- claim from the last send (a claim, not a fact)
struct E9Claim
  {
   bool   has;
   bool   done;          // scripted/claimed retcode DONE
   ulong  orderTicket;
   ulong  dealTicket;
   double volume;
   int    dir;
  };

//--- signal input (already evaluated; signal math lives outside)
struct E9Signal
  {
   datetime barTime;     // current last CLOSED bar time
   bool     canEval;     // window valid
   int      dir;         // E9_BUY / E9_SELL, 0 = no verdict
  };

struct E9Input
  {
   E9Signal  sig;
   E9Snapshot snap;
   E9Claim   claim;
  };

//--- requested action (harness/mock executes it): 0 none, 1 open, 2 close
struct E9Action
  {
   int    type;
   int    dir;
   double volume;
   ulong  posTicket;
  };

//+------------------------------------------------------------------+
//| Volume matching policy (correction 4): representation errors     |
//| only. tolerance = 32*DBL_EPSILON*max(|a|,|b|,|step|); validated  |
//| inputs; refused when tol >= step/1e6. Never mutates values.      |
//+------------------------------------------------------------------+
double E9VolTolerance(const double v1,const double v2,const double step,double &tolOut)
  {
   double base=MathMax(MathAbs(v1),MathAbs(v2));
   base=MathMax(base,MathAbs(step));
   tolOut=32.0*DBL_EPSILON*base;
   return(tolOut);
  }

bool E9VolInputsValid(const double v1,const double v2,const double step)
  {
   if(v1<=0.0 || v2<=0.0 || step<=0.0)       return(false);
   if(!MathIsValidNumber(v1)||!MathIsValidNumber(v2)||!MathIsValidNumber(step)) return(false); if(v1==EMPTY_VALUE || v2==EMPTY_VALUE || step==EMPTY_VALUE) return(false);
   return(true);
  }

E9VolCmp E9VolumeMatch(const double expected,const double actual,const double step,double &tolOut)
  {
   if(!E9VolInputsValid(expected,actual,step)) { tolOut=0.0; return(E9_V_INVALID); }
   E9VolTolerance(expected,actual,step,tolOut);
   if(tolOut>=step/1000000.0)                 return(E9_V_REFUSED);
   if(MathAbs(expected-actual)<=tolOut)       return(E9_V_OK);
   return(E9_V_MISMATCH);
  }

E9VolCmp E9VolumeOnGrid(const double v,const double step,double &tolOut)
  {
   if(!E9VolInputsValid(v,step,step)) { tolOut=0.0; return(E9_V_INVALID); }
   E9VolTolerance(v,step,step,tolOut);
   if(tolOut>=step/1000000.0)                 return(E9_V_REFUSED);
   double q=v/step;
   double res=MathAbs(q-MathRound(q));
   if(res*step<=tolOut)                       return(E9_V_OK);
   return(E9_V_MISMATCH);
  }

//--- snapshot helpers
void E9SnapInit(E9Snapshot &s)
  {
   ArrayResize(s.pos,0); ArrayResize(s.actOrd,0);
   ArrayResize(s.histOrd,0); ArrayResize(s.deals,0);
   s.posQueryFailed=false; s.actQueryFailed=false;
   s.histQueryFailed=false; s.dealsQueryFailed=false;
   s.volMin=0.01; s.volMax=100.0; s.volStep=0.01;
  }

void E9AddPos(E9Snapshot &s,const ulong ticket,const long identifier,const long magic,
              const string symbol,const int dir,const double volume)
  {
   int n=ArraySize(s.pos); ArrayResize(s.pos,n+1);
   s.pos[n].ticket=ticket;   s.pos[n].identifier=identifier;
   s.pos[n].magic=magic;     s.pos[n].symbol=symbol;
   s.pos[n].dir=dir;         s.pos[n].volume=volume;
  }

void E9AddActive(E9Snapshot &s,const ulong ticket,const long magic,
                 const int status,const double volume)
  {
   int n=ArraySize(s.actOrd); ArrayResize(s.actOrd,n+1);
   s.actOrd[n].ticket=ticket; s.actOrd[n].magic=magic;
   s.actOrd[n].symbol="XAUUSD"; s.actOrd[n].dir=0;
   s.actOrd[n].status=status; s.actOrd[n].volume=volume;
  }

void E9AddActiveEx(E9Snapshot &s,const ulong ticket,const long magic,
                   const string symbol,const int dir,const int status,const double volume)
  {
   int n=ArraySize(s.actOrd); ArrayResize(s.actOrd,n+1);
   s.actOrd[n].ticket=ticket; s.actOrd[n].magic=magic;
   s.actOrd[n].symbol=symbol; s.actOrd[n].dir=dir;
   s.actOrd[n].status=status; s.actOrd[n].volume=volume;
  }

void E9AddHist(E9Snapshot &s,const ulong ticket,const long magic,
               const int status,const double volume)
  {
   int n=ArraySize(s.histOrd); ArrayResize(s.histOrd,n+1);
   s.histOrd[n].ticket=ticket; s.histOrd[n].magic=magic;
   s.histOrd[n].symbol="XAUUSD"; s.histOrd[n].dir=0;
   s.histOrd[n].status=status; s.histOrd[n].volume=volume;
  }

void E9AddHistEx(E9Snapshot &s,const ulong ticket,const long magic,
                 const string symbol,const int dir,const int status,const double volume)
  {
   int n=ArraySize(s.histOrd); ArrayResize(s.histOrd,n+1);
   s.histOrd[n].ticket=ticket; s.histOrd[n].magic=magic;
   s.histOrd[n].symbol=symbol; s.histOrd[n].dir=dir;
   s.histOrd[n].status=status; s.histOrd[n].volume=volume;
  }

void E9AddDeal(E9Snapshot &s,const ulong deal,const ulong order,const long posId,
               const int dir,const double volume,const int entry)
  {
   int n=ArraySize(s.deals); ArrayResize(s.deals,n+1);
   s.deals[n].dealTicket=deal; s.deals[n].orderTicket=order;
   s.deals[n].positionId=posId; s.deals[n].dir=dir;
   s.deals[n].volume=volume;    s.deals[n].entry=entry;
   s.deals[n].magic=EXP9_DEF_MAGIC; s.deals[n].symbol="XAUUSD";
  }

void E9AddDealEx(E9Snapshot &s,const ulong deal,const ulong order,const long posId,
                 const int dir,const double volume,const int entry,
                 const long magic,const string symbol)
  {
   int n=ArraySize(s.deals); ArrayResize(s.deals,n+1);
   s.deals[n].dealTicket=deal; s.deals[n].orderTicket=order;
   s.deals[n].positionId=posId; s.deals[n].dir=dir;
   s.deals[n].volume=volume;    s.deals[n].entry=entry;
   s.deals[n].magic=magic;      s.deals[n].symbol=symbol;
  }

//--- scan positions owned by (magic,symbol); count and first hit
void E9ScanPositions(const E9Snapshot &s,const long magic,const string symbol,
                     int &count,E9Position &out)
  {
   count=0;
   for(int i=0;i<ArraySize(s.pos);i++)
     if(s.pos[i].magic==magic && s.pos[i].symbol==symbol)
       { if(count==0) out=s.pos[i]; count++; }
  }

bool E9ActiveHasTicket(const E9Snapshot &s,const ulong ticket)
  {
   for(int i=0;i<ArraySize(s.actOrd);i++)
     if(s.actOrd[i].ticket==ticket) return(true);
   return(false);
  }

bool E9HistStatus(const E9Snapshot &s,const ulong ticket,int &status)
  {
   status=-1;
   for(int i=0;i<ArraySize(s.histOrd);i++)
     if(s.histOrd[i].ticket==ticket){ status=s.histOrd[i].status; return(true); }
   return(false);
  }

//+------------------------------------------------------------------+
//| CE9Core: state machine + interlinked evidence confirmation       |
//+------------------------------------------------------------------+
class CE9Core
  {
private:
   E9State    m_state;
   bool       m_started;
   datetime   m_lastBar;         // latest observed bar time
   bool       m_waitNewBar;      // after resolution/halt-clear: wait for a newer key
   datetime   m_waitKey;         // resolution/clear bar; expiry needs barTime > m_waitKey
   bool       m_violationSticky; // never auto-lifted
   long       m_magic;
   string     m_symbol;
   //--- confirmed owned position (valid when m_hasPos==1)
   E9Position m_pos;
   int        m_hasPos;
   //--- consumed signal keys
   datetime   m_consumed[];
   //--- request tracking
   int        m_sent;
   //--- pending intent
   bool       m_pendActive;
   bool       m_pendClose;
   int        m_pendDir;
   double     m_pendReqVol;
   ulong      m_pendPosTicket;   // position identity captured at intent time
   long       m_pendPosId;
   int        m_pendPosDir;
   double     m_pendPosVol;
   ulong      m_pendReqRef;      // protected request reference (claims may not replace it)
   //--- late-evidence accumulator (cumulative full-range contract)
   E9DealInfo m_seenDeals[];
   //--- diagnostics
   string     m_note;
   int        m_noteSeq;

   bool Consumed(const datetime t) const
     {
      for(int i=0;i<ArraySize(m_consumed);i++)
        if(m_consumed[i]==t) return(true);
      return(false);
     }
   void Consume(const datetime t)
     {
      if(Consumed(t)) return;
      int n=ArraySize(m_consumed); ArrayResize(m_consumed,n+1); m_consumed[n]=t;
     }
   void SetViolation(const string reason)
     {
      if(!m_violationSticky)
        {
         m_violationSticky=true;
         m_state=E9_HALT_VIOLATION;
         Note("VIOLATION|"+reason);
        }
     }
   void Note(const string msg)
     {
      if(m_note==msg) return;   // log state changes, not repeats
      m_note=msg;
      m_noteSeq++;
     }
   //--- end of a resolution: record the resolution bar, wait for a newer key,
   //    drop the accumulator and the request reference.
   void EndResolution(const string note,const datetime resBar)
     {
      Note(note);
      m_pendActive=false; m_pendClose=false;
      m_pendReqRef=0;
      m_pendPosTicket=0; m_pendPosId=0; m_pendPosDir=0; m_pendPosVol=0.0;
      m_waitNewBar=true; m_waitKey=resBar;
      ArrayResize(m_seenDeals,0);
     }
   void FinalizeOpenConfirmed(const E9Position &o,const datetime bar)
     {
      m_pos=o; m_hasPos=1;
      m_state=(m_pendDir==E9_BUY?E9_LONG:E9_SHORT);
      EndResolution("OPEN|CONFIRMED",bar);
     }
   void FinalizeOpenPartial(const E9Position &o,const datetime bar,const string note)
     {
      m_pos=o; m_hasPos=1;
      m_state=(m_pendDir==E9_BUY?E9_LONG:E9_SHORT);
      EndResolution(note,bar);
     }
   void FinalizeOpenRejected(const datetime bar)
     {
      m_state=E9_FLAT; m_hasPos=0;
      EndResolution("OPEN|REJECTED-FINAL-FLAT",bar);
     }
   void FinalizeCloseFlat(const datetime bar)
     {
      m_state=E9_FLAT; m_hasPos=0;
      EndResolution("CLOSE|CONFIRMED-FLAT",bar);
     }
   void FinalizeClosePartial(const E9Position &o,const datetime bar,const string note)
     {
      m_pos=o; m_hasPos=1;
      m_state=(o.dir==E9_BUY?E9_LONG:E9_SHORT);
      EndResolution(note,bar);
     }
   void FinalizeCloseRejected(const E9Position &o,const datetime bar)
     {
      m_pos=o; m_hasPos=1;
      m_state=(o.dir==E9_BUY?E9_LONG:E9_SHORT);
      EndResolution("CLOSE|REJECTED-FINAL-POSITION-KEPT",bar);
     }
   //--- identity re-match (ticket/id/direction; volume checked separately)
   bool PosIdentityMatches(const E9Position &o,const ulong savedTicket,const long savedId,
                           const int savedDir)
     {
      if(savedTicket!=0 && o.ticket!=savedTicket) return(false);
      if(savedId!=0 && o.identifier!=savedId) return(false);
      if(o.dir!=savedDir) return(false);
      return(true);
     }
   //--- full re-match including volume (used before a close INTENT)
   bool PosFullMatches(const E9Position &o,const ulong savedTicket,const long savedId,
                       const int savedDir,const double savedVol,const double step,
                       string &why)
     {
      if(!PosIdentityMatches(o,savedTicket,savedId,savedDir))
        { why="identity"; return(false); }
      double tol=0.0;
      if(E9VolumeMatch(savedVol,o.volume,step,tol)!=E9_V_OK) { why="volume"; return(false); }
      return(true);
     }
   //--- aggregate + validate the deals of the pending order.
   //    CUMULATIVE contract: previously seen deals must persist (regression
   //    detection); new deals are validated (positive/valid ids, direction,
   //    magic, symbol) and deduplicated; a duplicate dealTicket with a
   //    different content is a CONFLICT, not a silent ignore.
   bool AggregateDeals(const E9Snapshot &s,const int entryFilter,const int expectedDir,
                       double &sum,long &posId,string &conflict,const string tag)
     {
      sum=0.0; posId=0; conflict=""; for(int _k=0;_k<ArraySize(m_seenDeals);_k++) sum+=m_seenDeals[_k].volume;
      int baseN=ArraySize(m_seenDeals);
      //--- 1. regression: every previously seen event must still be present
      for(int k=0;k<baseN;k++)
        {
         bool found=false;
         for(int j=0;j<ArraySize(s.deals);j++)
           {
            if(s.deals[j].dealTicket!=m_seenDeals[k].dealTicket) continue;
            if(s.deals[j].orderTicket!=m_seenDeals[k].orderTicket) continue;
            if(s.deals[j].entry!=m_seenDeals[k].entry) continue;
            if(s.deals[j].volume!=m_seenDeals[k].volume) continue;
            if(s.deals[j].positionId!=m_seenDeals[k].positionId) continue;
            if(s.deals[j].dir!=m_seenDeals[k].dir) continue;
            if(s.deals[j].magic!=m_seenDeals[k].magic) continue;
            if(s.deals[j].symbol!=m_seenDeals[k].symbol) continue;
            found=true; break;
           }
         if(!found){ conflict=tag+"|evidence-regressed"; return(false); }
        }
      //--- 2. validate + merge snapshot deals for this order/entry
      for(int j=0;j<ArraySize(s.deals);j++)
        {
         if(s.deals[j].orderTicket!=m_pendReqRef) continue;
         if(s.deals[j].entry!=entryFilter) continue;
         //--- field validity
         if(s.deals[j].dealTicket<=0 || s.deals[j].orderTicket<=0 ||
            s.deals[j].positionId<=0 || s.deals[j].volume<=0.0 ||
            !MathIsValidNumber(s.deals[j].volume))
           { conflict=tag+"|deal-invalid"; return(false); }
         if(s.deals[j].dir!=expectedDir){ conflict=tag+"|deal-dir-mismatch"; return(false); }
         if(s.deals[j].magic!=m_magic){ conflict=tag+"|deal-magic-mismatch"; return(false); }
         if(s.deals[j].symbol!=m_symbol){ conflict=tag+"|deal-symbol-mismatch"; return(false); }
         //--- duplicate dealTicket: identical content is a repeated event (skip);
         //    different content is a conflict
         bool dup=false;
         for(int k=0;k<ArraySize(m_seenDeals);k++)
           {
            if(m_seenDeals[k].dealTicket!=s.deals[j].dealTicket) continue;
            dup=true;
            if(m_seenDeals[k].orderTicket!=s.deals[j].orderTicket ||
               m_seenDeals[k].entry!=s.deals[j].entry ||
               m_seenDeals[k].volume!=s.deals[j].volume ||
               m_seenDeals[k].positionId!=s.deals[j].positionId ||
               m_seenDeals[k].dir!=s.deals[j].dir ||
               m_seenDeals[k].magic!=s.deals[j].magic ||
               m_seenDeals[k].symbol!=s.deals[j].symbol)
              { conflict=tag+"|deal-dup-content-conflict"; return(false); }
            break;
           }
         if(dup) continue;
         int n=ArraySize(m_seenDeals); ArrayResize(m_seenDeals,n+1);
         m_seenDeals[n]=s.deals[j];
         //--- single resulting position
         if(posId==0) posId=s.deals[j].positionId;
         else if(posId!=s.deals[j].positionId)
           { conflict=tag+"|deal-multi-position"; return(false); }
         sum+=s.deals[j].volume;
        }
      return(true);
     }
   //--- proven final rejection/cancellation WITHOUT an assigned orderTicket.
   //    Requires exactly one final REJECTED/CANCELED history order for our
   //    (magic,symbol,direction,volume) that is not active and has no deals,
   //    and no other matching candidate. Absence of evidence is NOT proof.
   bool FindOurFinalNoExec(const E9Snapshot &s,const int dir,const double vol,
                           const double step,int &status)
     {
      status=-1; int found=0;
      for(int i=0;i<ArraySize(s.histOrd);i++)
        {
         E9OrderInfo h=s.histOrd[i];
         if(h.magic!=m_magic || h.symbol!=m_symbol) continue;
         if(!(h.status==E9_ORD_REJECTED || h.status==E9_ORD_CANCELED)) continue;
         if(h.dir!=dir) continue;
         double tol=0.0;
         if(E9VolumeMatch(vol,h.volume,step,tol)!=E9_V_OK) continue;
         if(E9ActiveHasTicket(s,h.ticket)) continue;
         bool hasDeal=false;
         for(int j=0;j<ArraySize(s.deals);j++)
           if(s.deals[j].orderTicket==h.ticket){ hasDeal=true; break; }
         if(hasDeal) continue;
         status=h.status; found++;
        }
      return(found==1);
     }
   //--- resolve an open request using interlinked evidence
   void ResolveOpen(const E9Input &in)
     {
      //--- query integrity: failures are NOT proof (gate entry AND close)
      if(in.snap.posQueryFailed || in.snap.actQueryFailed ||
         in.snap.histQueryFailed || in.snap.dealsQueryFailed)
        { Note("OPEN|evidence-incomplete-query"); return; }
      ulong ot=m_pendReqRef;
      if(ot==0)
        {
         int st=0;
         if(FindOurFinalNoExec(in.snap,m_pendDir,m_pendReqVol,in.snap.volStep,st))
           { FinalizeOpenRejected(in.sig.barTime); return; }
         Note("OPEN|no-order-ref");    // no proof yet: keep blocking
         return;
        }
      if(E9ActiveHasTicket(in.snap,ot)) { Note("OPEN|active-part-remains"); return; }
      int status=-1;
      if(!E9HistStatus(in.snap,ot,status)) { Note("OPEN|final-state-missing"); return; }
      double filled=0.0; long posId=0; string conflict="";
      if(!AggregateDeals(in.snap,E9_ENTRY_IN,m_pendDir,filled,posId,conflict,"OPEN"))
        { Note(conflict); return; }
      int c; E9Position o;
      E9ScanPositions(in.snap,m_magic,m_symbol,c,o);
      if(status==E9_ORD_REJECTED)
        {
         if(filled>0.0 || c>0) { Note("OPEN|contradiction-reject-but-executed"); return; }
         FinalizeOpenRejected(in.sig.barTime);
         return;
        }
      if(status==E9_ORD_CANCELED)
        {
         if(filled>0.0 && c==1)
           {
            // canceled AFTER partial execution: confirmed part, rest has ended
            if(o.dir!=m_pendDir) { Note("OPEN|canceled-partial-dir-mismatch"); return; }
            double tol=0.0;
            if(E9VolumeMatch(filled,o.volume,in.snap.volStep,tol)!=E9_V_OK)
              { Note("OPEN|canceled-partial-pos-mismatch"); return; }
            if(posId!=0 && o.identifier!=posId)
              { Note("OPEN|canceled-partial-pos-not-linked"); return; }
            FinalizeOpenPartial(o,in.sig.barTime,"OPEN|PARTIAL|CANCELED-AFTER-PARTIAL");
            return;
           }
         // missing deals are NOT automatic final partial; no position => no-exec
         if(filled>0.0 || c>0) { Note("OPEN|canceled-evidence-unattributable"); return; }
         FinalizeOpenRejected(in.sig.barTime);
         return;
        }
      if(status!=E9_ORD_FILLED){ Note("OPEN|order-not-final"); return; }
      //--- filled: interlink with the resulting position (mere presence is not proof)
      if(filled<=0.0){ Note("OPEN|filled-but-zero-deals"); return; }
      if(c==0) { Note("OPEN|filled-but-no-position"); return; }
      if(c>1)  { SetViolation("ownership:more-than-one"); return; }
      if(o.dir!=m_pendDir) { SetViolation("direction-mismatch"); return; }
      if(posId!=0 && o.identifier!=posId) { Note("OPEN|pos-not-linked"); return; }
      double tol=0.0;
      E9VolCmp cmp=E9VolumeMatch(m_pendReqVol,filled,in.snap.volStep,tol);
      if(cmp==E9_V_INVALID || cmp==E9_V_REFUSED) { Note("OPEN|volume-numeric-refused"); return; }
      if(cmp==E9_V_MISMATCH)
        {
         if(filled>m_pendReqVol){ SetViolation("volume-excess"); return; }
         if(filled>0.0)
           {
            // final partial: actual position volume must equal the deal sum
            E9VolCmp c2=E9VolumeMatch(filled,o.volume,in.snap.volStep,tol);
            if(c2!=E9_V_OK){ Note("OPEN|partial-pos-mismatch"); return; }
            FinalizeOpenPartial(o,in.sig.barTime,"OPEN|PARTIAL|target-volume-violation-logged");
            return;
           }
         Note("OPEN|filled-but-zero-deals");
         return;
        }
      // volume OK: position volume must be consistent with the fill
      E9VolCmp c2=E9VolumeMatch(filled,o.volume,in.snap.volStep,tol);
      if(c2!=E9_V_OK) { Note("OPEN|pos-volume-inconsistent"); return; }
      FinalizeOpenConfirmed(o,in.sig.barTime);
     }
   //--- resolve a close request
   void ResolveClose(const E9Input &in)
     {
      if(in.snap.posQueryFailed || in.snap.actQueryFailed ||
         in.snap.histQueryFailed || in.snap.dealsQueryFailed)
        { Note("CLOSE|evidence-incomplete-query"); return; }
      ulong ot=m_pendReqRef;
      if(ot==0)
        {
         int st=0;
         if(FindOurFinalNoExec(in.snap,(m_pendDir==E9_BUY?E9_SELL:E9_BUY),m_pendPosVol,in.snap.volStep,st))
           {
            int c; E9Position o;
            E9ScanPositions(in.snap,m_magic,m_symbol,c,o);
            if(c==1 && PosIdentityMatches(o,m_pendPosTicket,m_pendPosId,m_pendPosDir))
              { FinalizeCloseRejected(o,in.sig.barTime); return; }
           }
         Note("CLOSE|no-order-ref");
         return;
        }
      if(E9ActiveHasTicket(in.snap,ot)) { Note("CLOSE|active-part-remains"); return; }
      int status=-1;
      if(!E9HistStatus(in.snap,ot,status)) { Note("CLOSE|final-state-missing"); return; }
      double closed=0.0; long posId=0; string conflict="";
      if(!AggregateDeals(in.snap,E9_ENTRY_OUT,(m_pendDir==E9_BUY?E9_SELL:E9_BUY),closed,posId,conflict,"CLOSE"))
        { Note(conflict); return; }
      int c; E9Position o;
      E9ScanPositions(in.snap,m_magic,m_symbol,c,o);
      if(c>1) { SetViolation("ownership:more-than-one"); return; }
      if(status==E9_ORD_REJECTED)
        {
         if(closed>0.0) { Note("CLOSE|contradiction"); return; }
         if(c==1 && PosIdentityMatches(o,m_pendPosTicket,m_pendPosId,m_pendPosDir))
           {
            // position retained: direction and actual volume
            double tol=0.0;
            if(E9VolumeMatch(m_pendPosVol,o.volume,in.snap.volStep,tol)!=E9_V_OK)
              { Note("CLOSE|rejected-pos-volume-changed"); return; }
            FinalizeCloseRejected(o,in.sig.barTime);
            return;
           }
         Note("CLOSE|rejected-pos-state-unclear");
         return;
        }
      if(status==E9_ORD_CANCELED)
        {
         if(closed>0.0 && c==1 && PosIdentityMatches(o,m_pendPosTicket,m_pendPosId,m_pendPosDir))
           {
            // canceled AFTER partial close execution: remainder kept
            double tol=0.0;
            if(posId!=0 && o.identifier!=posId){ Note("CLOSE|canceled-pos-not-linked"); return; }
            if(E9VolumeMatch(m_pendReqVol,closed+o.volume,in.snap.volStep,tol)!=E9_V_OK)
              { Note("CLOSE|canceled-remainder-mismatch"); return; }
            FinalizeClosePartial(o,in.sig.barTime,"CLOSE|PARTIAL|CANCELED-AFTER-PARTIAL");
            return;
           }
         if(closed>0.0 || c!=1) { Note("CLOSE|canceled-evidence-unattributable"); return; } double _cl=0.0; if(E9VolumeMatch(m_pendPosVol,o.volume,in.snap.volStep,_cl)!=E9_V_OK) { Note("CLOSE|canceled-pos-volume-changed"); return; }
         FinalizeCloseRejected(o,in.sig.barTime);  // no-exec cancellation: like rejection
         return;
        }
      if(status!=E9_ORD_FILLED){ Note("CLOSE|order-not-final"); return; }
      //--- filled: out-deals are required evidence; position alone is not proof
      if(closed<=0.0) { Note("CLOSE|filled-no-out-deals"); return; }
      if(c==0)
        {
         // full close: closed volume equals requested; closing deals target our position
         if(m_pendPosId!=0 && posId!=0 && posId!=m_pendPosId)
           { Note("CLOSE|closed-pos-id-mismatch"); return; }
         double tol=0.0;
         if(E9VolumeMatch(m_pendReqVol,closed,in.snap.volStep,tol)!=E9_V_OK)
           { Note("CLOSE|closed-volume-inconsistent"); return; }
         FinalizeCloseFlat(in.sig.barTime);
         return;
        }
      //--- remaining volume -> partial close
      if(c==1)
        {
         if(!PosIdentityMatches(o,m_pendPosTicket,m_pendPosId,m_pendPosDir))
           { Note("CLOSE|remainder-pos-mismatch"); return; }
         if(posId!=0 && o.identifier!=posId){ Note("CLOSE|remainder-pos-not-linked"); return; }
         double tol=0.0;
         if(E9VolumeMatch(m_pendReqVol,closed+o.volume,in.snap.volStep,tol)!=E9_V_OK)
           { Note("CLOSE|partial-volume-inconsistent"); return; }
         FinalizeClosePartial(o,in.sig.barTime,"CLOSE|PARTIAL-REMAINDER-KEPT");
         return;
        }
      SetViolation("ownership:more-than-one");
     }

public:
   CE9Core()
     {
      m_state=E9_FLAT; m_started=false; m_lastBar=0;
      m_waitNewBar=false; m_waitKey=0; m_violationSticky=false;
      m_magic=EXP9_DEF_MAGIC; m_symbol="XAUUSD";
      m_hasPos=0; m_sent=0; m_pendActive=false; m_pendClose=false;
      m_pendDir=0; m_pendReqVol=0.0; m_pendPosTicket=0;
      m_pendPosId=0; m_pendPosDir=0; m_pendPosVol=0.0;
      m_pendReqRef=0;
      m_note=""; m_noteSeq=0;
      ArrayResize(m_consumed,0); ArrayResize(m_seenDeals,0);
     }
   void Configure(const long magic,const string symbol)
     { m_magic=magic; m_symbol=symbol; }
   //--- explicit violation clear; resume requires a bar NEWER than the last
   //    observed bar. The halt is never auto-lifted.
   void ClearViolation()
     {
      if(m_violationSticky)
        {
         m_violationSticky=false;
         m_state=E9_FLAT; m_hasPos=0; m_pendActive=false; m_pendClose=false;
         m_pendReqRef=0; m_pendPosTicket=0; m_pendPosId=0;
         ArrayResize(m_seenDeals,0);
         m_waitNewBar=true; m_waitKey=m_lastBar;
         Note("VIOLATION-CLEARED|wait-new-bar");
        }
     }
   E9State State() const { return(m_state); }
   bool    HasPosition() const { return(m_hasPos==1); }
   E9Position Position() const { return(m_pos); }
   int     Sent() const { return(m_sent); }
   int     ConsumedCount() const { return(ArraySize(m_consumed)); }
   bool    IsConsumed(const datetime t) const { return(Consumed(t)); }
   string  Note() const { return(m_note); }
   int     NoteSeq() const { return(m_noteSeq); }
   bool    WaitNewBar() const { return(m_waitNewBar); }
   bool    ViolationSticky() const { return(m_violationSticky); }

   //--- reinit: never claim restoration of an unknown prior request.
   //    Adoption REQUIRES caller proof that no request is unresolved.
   //    Absence of a position does NOT prove absence of a pending request.
   //    A proven adopted position is NOT immediately rejected (B1-R1 fix).
   void Reinit(const E9Snapshot &snap,const bool proofNoPending)
     {
      m_state=E9_FLAT; m_started=false; m_lastBar=0;
      m_waitNewBar=false; m_waitKey=0; m_hasPos=0; m_sent=0;
      m_pendActive=false; m_pendClose=false;
      m_pendDir=0; m_pendReqVol=0.0; m_pendPosTicket=0;
      m_pendPosId=0; m_pendPosDir=0; m_pendPosVol=0.0;
      m_pendReqRef=0;
      ArrayResize(m_consumed,0); ArrayResize(m_seenDeals,0);
      // (violationSticky is NOT reset: gross violations survive reinit)
      int c; E9Position o;
      E9ScanPositions(snap,m_magic,m_symbol,c,o);
      if(c>1){ SetViolation("ownership:more-than-one"); return; }
      if(!proofNoPending)
        {
         // no adoption and no resume without proof of no outstanding request
         SetViolation("reinit:unproven-prior-request");
         return;
        }
      if(c==1)
        {
         m_pos=o; m_hasPos=1;
         m_state=(o.dir==E9_BUY ? E9_LONG : E9_SHORT);
         m_started=true;               // adopted state: startup must not re-flag it
         m_waitNewBar=true; m_waitKey=0; // wait for the first real bar
         Note("REINIT|adopted-proven-position");
         return;
        }
      m_waitNewBar=true; m_waitKey=0;
      Note("REINIT|fresh-flat");
     }

   //--- one tick of the state machine; returns at most one action
   void Process(const E9Input &in,E9Action &act)
     {
      act.type=0; act.dir=0; act.volume=0.0; act.posTicket=0;

      //--- protected pending-order reference: a claim may NOT replace it.
      //    A claim with no orderTicket carries no reference.
      if(in.claim.has && (m_state==E9_PEND_OPEN || m_state==E9_PEND_CLOSE))
        {
         if(in.claim.orderTicket>0)
           {
            if(m_pendReqRef==0) m_pendReqRef=in.claim.orderTicket;
            else if(in.claim.orderTicket!=m_pendReqRef)
              Note("CLAIM|ignored-mismatched-ref");
           }
        }

      //--- bar clock: observed every tick (also during a halt), never regressed
      if(in.sig.barTime>0 && in.sig.barTime!=m_lastBar)
        {
         if(in.sig.barTime>m_lastBar) m_lastBar=in.sig.barTime;
        }

      //--- ownership scan (skipped when the position query itself failed:
      //    a failed read is not proof of zero positions)
      if(!m_violationSticky && !in.snap.posQueryFailed)
        {
         int c; E9Position o;
         E9ScanPositions(in.snap,m_magic,m_symbol,c,o);
         if(c>1){ SetViolation("ownership:more-than-one"); return; }
        }
      if(m_violationSticky) return;        // stays halted; never auto-lifted

      //--- startup: reference only, no trading from history
      if(!m_started)
        {
         if(in.sig.barTime<=0){ Note("START|waiting-data"); return; }
         int c; E9Position o;
         E9ScanPositions(in.snap,m_magic,m_symbol,c,o);
         if(c>0){ SetViolation("startup:unattributable-position"); return; }
         m_started=true;
         m_waitNewBar=true; m_waitKey=in.sig.barTime;
         Note("START|reference-bar-no-trade");
         return;
        }

      //--- post-resolution/halt wait expires on a strictly NEWER bar only
      if(m_waitNewBar && in.sig.barTime>m_waitKey) m_waitNewBar=false;

      //--- confirmation processing for pending requests
      if(m_state==E9_PEND_OPEN) { ResolveOpen(in); return; }
      if(m_state==E9_PEND_CLOSE){ ResolveClose(in); return; }

      //--- after halt/evidence resolution: ignore accumulated signals
      if(m_waitNewBar) return;

      //--- actionable signal: current last closed bar, valid, unconsumed
      bool actionable = in.sig.canEval && (in.sig.dir==E9_BUY||in.sig.dir==E9_SELL) &&
                        !Consumed(in.sig.barTime) && in.sig.barTime==m_lastBar;

      if(m_state==E9_LONG || m_state==E9_SHORT)
        {
         int posDir=(m_state==E9_LONG ? E9_BUY : E9_SELL);
         if(!actionable || in.sig.dir==posDir) return;   // same direction: nothing
         //--- opposite: close only, never flip from this key.
         //    B1-R1: never use stale state — re-match the CURRENT position
         //    against the saved one before any close intent.
         if(in.snap.posQueryFailed || in.snap.actQueryFailed)
           { Consume(in.sig.barTime); Note("CLOSE|intent-query-failed"); return; }
         int c; E9Position o;
         E9ScanPositions(in.snap,m_magic,m_symbol,c,o);
         if(c==0){ Note("CLOSE|intent-pos-missing"); return; }  // retry with later evidence
         if(c>1){ SetViolation("ownership:more-than-one"); return; }
         string why="";
         if(!PosFullMatches(o,m_pos.ticket,m_pos.identifier,m_pos.dir,m_pos.volume,
                           in.snap.volStep,why))
           { SetViolation("ownership:close-rematch-failed:"+why); return; }
         Consume(in.sig.barTime);
         m_pendActive=true; m_pendClose=true;
         m_pendDir=posDir; m_pendReqVol=o.volume;
         m_pendPosTicket=o.ticket; m_pendPosId=o.identifier;
         m_pendPosDir=o.dir; m_pendPosVol=o.volume;
         m_pendReqRef=0;            // assigned from the claim on the next tick
         ArrayResize(m_seenDeals,0);
         act.type=2; act.dir=posDir; act.volume=o.volume; act.posTicket=o.ticket;
         m_sent++;
         m_state=E9_PEND_CLOSE;
         Note("CLOSE|opposite-requested");
         return;
        }

      if(m_state==E9_FLAT)
        {
         if(!actionable) return;
         Consume(in.sig.barTime);      // consumption on attempt OR refused checks
         if(in.snap.posQueryFailed || in.snap.actQueryFailed)
           { Note("ENTRY|state-query-failed"); return; }
         //--- unexpected own position in FLAT blocks a new entry
         int c; E9Position o;
         E9ScanPositions(in.snap,m_magic,m_symbol,c,o);
         if(c==1) { Note("ENTRY|unexpected-own-position"); return; }
         if(c>1)  { SetViolation("ownership:more-than-one"); return; }
         if(in.snap.volMin<=0.0 || in.snap.volStep<=0.0)
           { Note("ENTRY|limits-unavailable"); return; }
         double tol=0.0;
         if(EXP9_REQ_VOLUME<in.snap.volMin || EXP9_REQ_VOLUME>in.snap.volMax)
           { Note("ENTRY|volume-out-of-limits"); return; }
         E9VolCmp g=E9VolumeOnGrid(EXP9_REQ_VOLUME,in.snap.volStep,tol);
         if(g!=E9_V_OK) { Note("ENTRY|volume-not-on-step"); return; }
         act.type=1; act.dir=in.sig.dir; act.volume=EXP9_REQ_VOLUME;
         m_sent++;
         m_pendActive=true; m_pendClose=false;
         m_pendDir=in.sig.dir; m_pendReqVol=EXP9_REQ_VOLUME; m_pendPosTicket=0;
         m_pendPosId=0; m_pendPosDir=0; m_pendPosVol=0.0;
         m_pendReqRef=0;
         ArrayResize(m_seenDeals,0);
         m_state=E9_PEND_OPEN;
         Note("OPEN|order-sent");
         return;
        }
      // HALT states: nothing
     }
  };

#endif