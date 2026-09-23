//+------------------------------------------------------------------+
//| MASK_SMA20_CROSS_EDU_tests.mqh                                   |
//| EXP-008 Test B-R1: synthetic suite. Calls ONLY the shared core.  |
//| No duplicated logic: vectors, states, rebuilds, ranges, renders. |
//+------------------------------------------------------------------+
#ifndef MASK_SMA20_CROSS_EDU_TESTS_MQH
#define MASK_SMA20_CROSS_EDU_TESTS_MQH

#include <MASK_EDU\MASK_SMA20_CROSS_EDU_shared.mqh>

//--- global accounting
int      g_eduPass=0;
int      g_eduFail=0;
int      g_eduSkip=0;
string   g_resultLines[];

void EduTLog(const string id,const bool ok,const string detail)
  {
   if(ok) g_eduPass++; else g_eduFail++;
   int n=ArraySize(g_resultLines);
   ArrayResize(g_resultLines,n+1);
   g_resultLines[n]=id+"|"+(ok?"PASS":"FAIL")+"|"+detail;
   PrintFormat("EXP8TEST|%s|%s|%s",id,ok?"PASS":"FAIL",detail);
  }

//--- build a series feed: n bars (1 forming + n-1 closed), all closes
//    100 (high=101, low=99), times base+k*3600.
//    Direction contract: all arrays are EXPLICITLY reset to normal
//    orientation BEFORE filling, then set to SERIES AFTER filling.
//    This makes repeated calls (including size changes) deterministic.
void EduBuildSeries(const int n,const double c1,const double c2,
                    const int c10Mode,const datetime base,
                    double &close[],datetime &time[],double &high[],double &low[])
  {
   ArrayResize(close,n); ArrayResize(time,n); ArrayResize(high,n); ArrayResize(low,n);
   ArraySetAsSeries(close,false); ArraySetAsSeries(time,false);
   ArraySetAsSeries(high,false);  ArraySetAsSeries(low,false);
   for(int k=0;k<n;k++)
     {
      close[k]=100.0;
      high[k]=101.0;
      low[k]=99.0;
      time[k]=base+(datetime)k*3600;
     }
   ArraySetAsSeries(close,true);
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   close[0]=50.0;              // forming bar close (must never influence decisions)
   if(n>=22)
     {
      close[1]=c1;             // C1 = last closed bar
      close[2]=c2;             // C2 = previous closed bar
      if(c10Mode==1) close[10]=EMPTY_VALUE;   // C10 missing sentinel
      if(c10Mode==2) close[10]=0.0;           // C10 invalid price (<=0)
     }
  }

//--- emulates the platform buffer shift when ONE new bar arrives:
//    dst[k+1]=src[k], dst[0]=0. Returns new size n+1.
void EduShiftUp(const double &src[],double &dst[],const int n)
  {
   ArrayResize(dst,n+1);
   ArraySetAsSeries(dst,true);
   for(int k=n-1;k>=0;k--) dst[k+1]=src[k];
   dst[0]=0.0;
  }

//--- vector case (A..G): C3..C21=100 by construction
void EduVectorCase(const string id,const double c2val,const double c1val,
                   const EduSignal expected)
  {
   double cl[]; datetime tm[]; double hi[],lo[];
   EduBuildSeries(22,c1val,c2val,0,(datetime)1800000000,cl,tm,hi,lo);
   EduWindow w;
   bool loaded=EduLoadWindow(cl,tm,22,1,w);
   EduSignal sig=(loaded ? EduEvaluateSignal(w.c1,w.sma1,w.c2,w.sma2)
                         : EDU_S_CANNOT_EVALUATE);
   CEduState st;
   int proc=EduProcess(cl,tm,22,st);
   EduSignal stSig=(st.Records()==1 ? st.FindState(tm[1]) : EDU_S_CANNOT_EVALUATE);
   bool ok=(loaded && sig==expected && stSig==expected &&
            st.Records()==1 && st.Pending()==0 && proc==1);
   string d=StringFormat("C1=%.10g C2=%.10g SMA1=%.10g SMA2=%.10g sig=%d stSig=%d rec=%d pend=%d",
                         w.c1,w.c2,w.sma1,w.sma2,sig,stSig,st.Records(),st.Pending());
   EduTLog(id,ok,d);
  }

//--- conformance case J: C2=99, C1=1899/19, rest 100.
//    Reference = mathematical result (no signal). Any other outcome
//    is recorded as FAIL with actual values, no special-casing.
void EduCaseJ()
  {
   double cl[]; datetime tm[]; double hi[],lo[];
   double c1j=1899.0/19.0;                 // explicit decimal division
   EduBuildSeries(22,c1j,99.0,0,(datetime)1800000000,cl,tm,hi,lo);
   EduWindow w;
   bool loaded=EduLoadWindow(cl,tm,22,1,w);
   EduSignal sig=(loaded ? EduEvaluateSignal(w.c1,w.sma1,w.c2,w.sma2)
                         : EDU_S_CANNOT_EVALUATE);
   CEduState st;
   EduProcess(cl,tm,22,st);
   EduSignal stSig=(st.Records()==1 ? st.FindState(tm[1]) : EDU_S_CANNOT_EVALUATE);
   bool ok=(loaded && sig==EDU_S_NONE && stSig==EDU_S_NONE && st.Records()==1);
   string d=StringFormat("C1=%.17g SMA1=%.17g diff=%.17g sig=%d stSig=%d rec=%d pend=%d",
                         w.c1,w.sma1,w.c1-w.sma1,sig,stSig,st.Records(),st.Pending());
   EduTLog("J",ok,d);
  }

//+------------------------------------------------------------------+
//| Full suite                                                       |
//+------------------------------------------------------------------+
int EduRunTestSuite(const string outFile)
  {
   g_eduPass=0; g_eduFail=0; g_eduSkip=0;
   ArrayResize(g_resultLines,0);

   //--- 1) vectors A..G (original inputs, unchanged)
   EduVectorCase("A",99.0,101.0,EDU_S_UP);
   EduVectorCase("B",101.0,99.0,EDU_S_DOWN);
   EduVectorCase("C",100.0,101.0,EDU_S_UP);
   EduVectorCase("D",100.0,99.0,EDU_S_DOWN);
   EduVectorCase("E",100.0,100.0,EDU_S_NONE);
   EduVectorCase("F",101.0,102.0,EDU_S_NONE);
   EduVectorCase("G",99.0,98.0,EDU_S_NONE);
   EduCaseJ();

   //--- 2) boundaries: target counts with forming bar counted
   bool tgt=EduTargetCount(21)==0 && EduTargetCount(22)==1 &&
            EduTargetCount(1021)==1000 && EduTargetCount(2000)==1000;
   EduTLog("TGT",tgt,StringFormat("21->%d 22->%d 1021->%d 2000->%d",
                                  EduTargetCount(21),EduTargetCount(22),
                                  EduTargetCount(1021),EduTargetCount(2000)));

   //--- 3) builder determinism: repeated calls on the same arrays,
   //       including a size change, must reproduce times and values
   {
    double cl[]; datetime tm[]; double hi[],lo[];
    datetime B=(datetime)1800000000;
    EduBuildSeries(22,101.0,99.0,0,B,cl,tm,hi,lo);
    datetime t1=tm[1]; double c1v=cl[1]; double c2v=cl[2]; datetime top=tm[0];
    bool ok1=(tm[1]==B+20*3600 && tm[2]==B+19*3600 && tm[21]==B &&
              tm[0]==B+21*3600 && cl[1]==101.0 && cl[2]==99.0 && cl[0]==50.0);
    bool ord1=true;
    for(int j=0;j<21;j++) if(tm[j]<=tm[j+1]) ord1=false;
    // resize to 30, then rebuild identical to the first call
    EduBuildSeries(30,100.0,100.0,0,B,cl,tm,hi,lo);
    EduBuildSeries(22,101.0,99.0,0,B,cl,tm,hi,lo);
    bool ok2=(tm[1]==t1 && tm[0]==top && cl[1]==c1v && cl[2]==c2v);
    bool ord2=true;
    for(int j=0;j<21;j++) if(tm[j]<=tm[j+1]) ord2=false;
    EduTLog("BUILD-REPEAT",ok1&&ord1&&ok2&&ord2,
            StringFormat("t1=%I64d c1=%g ord1=%d ord2=%d",t1,c1v,ord1,ord2));
   }

   //--- H: only 20 closed bars (N=21) -> cannot evaluate, no key.
   {
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(21,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    EduWindow w;
    bool loaded=EduLoadWindow(cl,tm,21,1,w);
    CEduState st;
    int proc=EduProcess(cl,tm,21,st);
    bool okH=(!loaded && st.Records()==0 && st.Pending()==0 && proc==0);
    // grow history to 22 with same state -> bar becomes evaluable
    EduBuildSeries(22,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    EduProcess(cl,tm,22,st);
    okH=okH && (st.Records()==1 && st.FindState(tm[1])==EDU_S_NONE);
    EduTLog("H",okH,StringFormat("loaded=%d rec=%d pend=%d",
                                 loaded,st.Records(),st.Pending()));
   }

   //--- I: like A with C10=EMPTY_VALUE -> refusable; restore -> UP on retry
   {
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(22,101.0,99.0,1,(datetime)1800000000,cl,tm,hi,lo);
    CEduState st;
    EduProcess(cl,tm,22,st);
    bool okI=(st.Records()==0 && st.Pending()==1);
    cl[10]=100.0;                            // data completes on the same closed bar
    EduProcess(cl,tm,22,st);                 // retry without waiting for a new bar
    okI=okI && (st.Records()==1 && st.Pending()==0 && st.FindState(tm[1])==EDU_S_UP);
    EduTLog("I",okI,StringFormat("after-restore rec=%d pend=%d",
                                 st.Records(),st.Pending()));
   }

   //--- forming bar: index 0 never read; close changes do not decide
   {
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(22,101.0,99.0,0,(datetime)1800000000,cl,tm,hi,lo);
    CEduState st;
    EduProcess(cl,tm,22,st);
    EduWindow w;
    cl[0]=999999.0;
    bool loaded=EduLoadWindow(cl,tm,22,1,w);
    EduProcess(cl,tm,22,st);
    bool okF=(loaded && w.c1==101.0 && st.Records()==1 &&
              st.FindState(tm[1])==EDU_S_UP);
    EduTLog("FORM0",okF,StringFormat("c1=%g rec=%d",w.c1,st.Records()));
   }

   //--- dedup incl. NONE: same feed processed twice
   {
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(22,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    CEduState st;
    EduProcess(cl,tm,22,st);
    EduProcess(cl,tm,22,st);
    bool okD=(st.Records()==1 && st.Pending()==0 && st.FindState(tm[1])==EDU_S_NONE);
    EduTLog("DEDUP-NONE",okD,StringFormat("rec=%d pend=%d",st.Records(),st.Pending()));
   }

   //--- two independent pending bars: fix ONE first, verify the other
   //    stays pending, then fix the second.
   {
    int n1=24;
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(n1,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    cl[22]=EMPTY_VALUE;  // inside bar i=2 window (2..22), outside bar i=1
    cl[23]=0.0;          // inside bar i=3 window (3..23)
    CEduState st;
    EduProcess(cl,tm,n1,st);
    datetime tA=(datetime)(1800000000+(n1-1-2)*3600);  // pending key 1 (i=2)
    datetime tB=(datetime)(1800000000+(n1-1-3)*3600);  // pending key 2 (i=3)
    bool okP1=(st.Records()==1 && st.Pending()==2 &&
               st.IsPending(tA) && st.IsPending(tB));
    // fix only the FIRST pending; the second must stay pending
    cl[22]=100.0;
    EduProcess(cl,tm,n1,st);
    bool okP1b=(st.HasRecord(tA) && st.FindState(tA)==EDU_S_NONE &&
                st.IsPending(tB) && !st.HasRecord(tB) &&
                st.Pending()==1 && st.Records()==2);
    // fix the second
    cl[23]=100.0;
    EduProcess(cl,tm,n1,st);
    bool okP2=(st.HasRecord(tB) && st.FindState(tB)==EDU_S_NONE &&
               st.Pending()==0 && st.Records()==3);
    EduTLog("PEND2",okP1&&okP1b&&okP2,
            StringFormat("rec=%d pend=%d",st.Records(),st.Pending()));
   }

   //--- pending keys resolved by TIME after indices shift (+3 new bars)
   {
    int n1=24;
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(n1,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    cl[22]=EMPTY_VALUE; cl[23]=0.0;
    CEduState st;
    EduProcess(cl,tm,n1,st);
    datetime tA=(datetime)(1800000000+(n1-1-2)*3600);
    datetime tB=(datetime)(1800000000+(n1-1-3)*3600);
    int n2=27;
    double cl2[]; datetime tm2[]; double hi2[],lo2[];
    EduBuildSeries(n2,100.0,100.0,0,(datetime)1800000000,cl2,tm2,hi2,lo2);
    // old pending keys shifted to i=5,6; data completed there
    cl2[5]=100.0;
    cl2[6]=100.0;
    int proc=EduProcess(cl2,tm2,n2,st);
    bool okS=(st.Pending()==0 && st.HasRecord(tA) && st.HasRecord(tB) &&
              st.FindState(tA)==EDU_S_NONE && st.FindState(tB)==EDU_S_NONE &&
              st.Records()==6 && proc>=3);
    EduTLog("PEND-SHIFT",okS,StringFormat("rec=%d pend=%d proc=%d",
                                          st.Records(),st.Pending(),proc));
   }

   //--- rebuild + history correction: stale result AND stale arrow vanish
   {
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(22,101.0,99.0,0,(datetime)1800000000,cl,tm,hi,lo);
    CEduState st;
    EduProcess(cl,tm,22,st);
    bool before=(st.FindState(tm[1])==EDU_S_UP);
    double up[],down[];
    ArrayResize(up,22); ArrayResize(down,22);
    ArraySetAsSeries(up,true); ArraySetAsSeries(down,true);
    ArrayInitialize(up,EMPTY_VALUE); ArrayInitialize(down,EMPTY_VALUE);
    int prev=0,last=0; datetime pTop=0;
    EduRender(up,down,tm,hi,lo,22,st,0.01,prev,last,pTop);
    bool arrowBefore=(up[1]==99.0-0.03);
    // history corrected: no signal now
    cl[1]=99.5;
    st.Clear();                          // full rebuild (as in OnInit reset)
    EduProcess(cl,tm,22,st);
    bool after=(st.FindState(tm[1])==EDU_S_NONE && st.Records()==1);
    // re-render: the old arrow must be physically gone from the buffers
    ArrayInitialize(up,EMPTY_VALUE); ArrayInitialize(down,EMPTY_VALUE);
    prev=0; last=0; pTop=0;
    EduRender(up,down,tm,hi,lo,22,st,0.01,prev,last,pTop);
    bool arrowAfter=(up[1]==EMPTY_VALUE && down[1]==EMPTY_VALUE);
    EduTLog("REBUILD",before&&arrowBefore&&after&&arrowAfter,
            StringFormat("arrowBefore=%g arrowAfter=%g rec=%d",
                         before?up[1]:-1,after?up[1]:-1,st.Records()));
   }

   //--- render: index0 empty, arrow placed; draw retry after correction
   {
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(22,101.0,99.0,0,(datetime)1800000000,cl,tm,hi,lo);
    CEduState st;
    EduProcess(cl,tm,22,st);
    double up[],down[];
    int prev=0,last=0; datetime pTop=0;
    // (a) normal: arrow drawn, index 0 empty, repeated renders keep it so
    ArrayResize(up,22); ArrayResize(down,22);
    ArraySetAsSeries(up,true); ArraySetAsSeries(down,true);
    ArrayInitialize(up,EMPTY_VALUE); ArrayInitialize(down,EMPTY_VALUE);
    EduRender(up,down,tm,hi,lo,22,st,0.01,prev,last,pTop);
    EduRender(up,down,tm,hi,lo,22,st,0.01,prev,last,pTop);
    bool okR=(up[0]==EMPTY_VALUE && down[0]==EMPTY_VALUE &&
              up[1]==99.0-0.03 && down[1]==EMPTY_VALUE);
    // (b) draw blocked by invalid low: cells empty, record kept
    lo[1]=0.0;
    ArrayInitialize(up,EMPTY_VALUE); ArrayInitialize(down,EMPTY_VALUE);
    prev=0; last=0; pTop=0;
    EduRender(up,down,tm,hi,lo,22,st,0.01,prev,last,pTop);
    bool okB=(st.FindState(tm[1])==EDU_S_UP && up[1]==EMPTY_VALUE &&
              down[1]==EMPTY_VALUE);
    // (c) draw blocked by invalid point (EMPTY_VALUE == DBL_MAX)
    lo[1]=99.0;
    ArrayInitialize(up,EMPTY_VALUE); ArrayInitialize(down,EMPTY_VALUE);
    prev=0; last=0; pTop=0;
    EduRender(up,down,tm,hi,lo,22,st,EMPTY_VALUE,prev,last,pTop);
    bool okP=(up[1]==EMPTY_VALUE && down[1]==EMPTY_VALUE);
    // (d) corrected data -> the record is retried and drawn
    ArrayInitialize(up,EMPTY_VALUE); ArrayInitialize(down,EMPTY_VALUE);
    prev=0; last=0; pTop=0;
    EduRender(up,down,tm,hi,lo,22,st,0.01,prev,last,pTop);
    bool okD2=(up[1]==99.0-0.03);
    EduTLog("RENDER",okR&&okB&&okP&&okD2,
            StringFormat("up0=%g up1=%g",up[0],up[1]));
   }

   //--- leaving the 1000 range (growth by count): record dropped + arrow cleared
   {
    int n1=1021;
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(n1,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    cl[1000]=101.0; cl[1001]=99.0;   // UP pattern at the oldest in-range bar
    CEduState st;
    EduProcess(cl,tm,n1,st);
    datetime tUp=(datetime)(1800000000+(n1-1-1000)*3600);
    bool okU=(st.HasRecord(tUp) && st.FindState(tUp)==EDU_S_UP);
    double up[],down[];
    ArrayResize(up,n1); ArrayResize(down,n1);
    ArraySetAsSeries(up,true); ArraySetAsSeries(down,true);
    ArrayInitialize(up,EMPTY_VALUE); ArrayInitialize(down,EMPTY_VALUE);
    int prev=0,last=0; datetime pTop=0;
    EduRender(up,down,tm,hi,lo,n1,st,0.01,prev,last,pTop);
    okU=okU && up[1000]==99.0-0.03 && prev==n1;
    // a new bar arrives (rates_total grows by 1): emulated platform shift
    int n2=1022;
    double cl2[]; datetime tm2[]; double hi2[],lo2[];
    EduBuildSeries(n2,101.0,99.0,0,(datetime)1800000000,cl2,tm2,hi2,lo2);
    cl2[1001]=101.0; cl2[1002]=99.0; // pattern now at out-of-range i=1001
    EduProcess(cl2,tm2,n2,st);
    bool okL=!st.HasRecord(tUp);                      // record dropped, not success
    double upSh[],downSh[];
    EduShiftUp(up,upSh,n1);
    EduShiftUp(down,downSh,n1);
    int prev2=prev,last2=last; datetime pTop2=pTop;
    EduRender(upSh,downSh,tm2,hi2,lo2,n2,st,0.01,prev2,last2,pTop2);
    okL=okL && upSh[1001]==EMPTY_VALUE && downSh[1001]==EMPTY_VALUE;
    EduTLog("RANGE-EXIT",okU&&okL,
            StringFormat("arrow1000=%g after1001=%g",up[1000],upSh[1001]));
   }

   //--- leaving range with CONSTANT rates_total: a new bar arrives but
   //    the bar count does not change; the stale arrow must still move.
   {
    int n=1021; datetime B=(datetime)1800000000;
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(n,100.0,100.0,0,B,cl,tm,hi,lo);
    cl[1000]=101.0; cl[1001]=99.0;
    CEduState st;
    EduProcess(cl,tm,n,st);
    datetime tUp=(datetime)(B+(n-1-1000)*3600);
    double up[],down[];
    ArrayResize(up,n); ArrayResize(down,n);
    ArraySetAsSeries(up,true); ArraySetAsSeries(down,true);
    ArrayInitialize(up,EMPTY_VALUE); ArrayInitialize(down,EMPTY_VALUE);
    int prev=0,last=0; datetime pTop=0;
    EduRender(up,down,tm,hi,lo,n,st,0.01,prev,last,pTop);
    bool okA=(up[1000]==99.0-0.03 && prev==n && pTop==tm[0]);
    // new bar with SAME rates_total: same length, base shifted by one bar,
    // the oldest bar drops off. Old bars move +1; the old UP bar is now
    // at index 1001 -> out of range.
    double cl2[]; datetime tm2[]; double hi2[],lo2[];
    EduBuildSeries(n,100.0,100.0,0,B+3600,cl2,tm2,hi2,lo2);
    EduProcess(cl2,tm2,n,st);
    bool okB=!st.HasRecord(tUp) && st.Pending()==0;
    double upSh[],downSh[];
    EduShiftUp(up,upSh,n);
    EduShiftUp(down,downSh,n);
    int prev2=prev,last2=last; datetime pTop2=pTop;
    EduRender(upSh,downSh,tm2,hi2,lo2,n,st,0.01,prev2,last2,pTop2);
    okB=okB && upSh[1001]==EMPTY_VALUE && downSh[1001]==EMPTY_VALUE;
    EduTLog("RANGE-EXIT-CONST",okA&&okB,
            StringFormat("arrow1000=%g after1001=%g",up[1000],upSh[1001]));
   }

   //--- pending key leaving range: dropped without success verdict
   {
    int n1=1021;
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(n1,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    cl[1000]=EMPTY_VALUE;              // oldest in-range bar invalid -> pending
    CEduState st;
    EduProcess(cl,tm,n1,st);
    datetime tP=(datetime)(1800000000+(n1-1-1000)*3600);
    bool okOp=(st.IsPending(tP) && !st.HasRecord(tP) && st.Pending()>=1);
    int n2=1022;
    double cl2[]; datetime tm2[]; double hi2[],lo2[];
    EduBuildSeries(n2,100.0,100.0,0,(datetime)1800000000,cl2,tm2,hi2,lo2);
    EduProcess(cl2,tm2,n2,st);         // key moved to i=1001 -> out of range
    bool okOd=(!st.IsPending(tP) && !st.HasRecord(tP));
    EduTLog("PEND-EXIT",okOp&&okOd,StringFormat("pend=%d",st.Pending()));
   }

   //--- more than one bar between calls
   {
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(22,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    CEduState st;
    EduProcess(cl,tm,22,st);                       // 1 record
    int n2=25;
    double cl2[]; datetime tm2[]; double hi2[],lo2[];
    EduBuildSeries(n2,100.0,100.0,0,(datetime)1800000000,cl2,tm2,hi2,lo2);
    int proc=EduProcess(cl2,tm2,n2,st);            // 3 new bars in one call
    bool okM=(st.Records()==4 && st.Pending()==0 && proc==3);
    EduTLog("MULTIBAR",okM,StringFormat("rec=%d proc=%d",st.Records(),proc));
   }

   //--- duplicate / reversed times, zero, EMPTY_VALUE, INF, NaN values
   //    and invalid SMA inputs -> all refused
   {
    double inf=2.0*DBL_MAX;      // +INF at runtime
    double nanv=inf-inf;         // NaN at runtime
    double cl[]; datetime tm[]; double hi[],lo[];
    EduBuildSeries(22,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    EduWindow w;
    tm[1]=tm[2];                       // duplicate times
    bool okT1=!EduLoadWindow(cl,tm,22,1,w);
    EduBuildSeries(22,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    tm[2]=tm[1]+7200;                  // reversed order (time[1]<time[2])
    bool okT2=!EduLoadWindow(cl,tm,22,1,w);
    EduBuildSeries(22,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    cl[21]=0.0;                        // invalid price <=0
    bool okT3=!EduLoadWindow(cl,tm,22,1,w);
    EduBuildSeries(22,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    cl[5]=EMPTY_VALUE;                 // missing value
    bool okT4=!EduLoadWindow(cl,tm,22,1,w);
    EduBuildSeries(22,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    cl[15]=inf;                        // +INF price
    bool okT5=!EduLoadWindow(cl,tm,22,1,w);
    EduBuildSeries(22,100.0,100.0,0,(datetime)1800000000,cl,tm,hi,lo);
    cl[16]=nanv;                       // NaN price
    bool okT6=!EduLoadWindow(cl,tm,22,1,w);
    // pure decision must refuse invalid SMA inputs
    EduSignal sA=EduEvaluateSignal(100.0,inf,99.0,100.0);
    EduSignal sB=EduEvaluateSignal(100.0,nanv,99.0,100.0);
    EduSignal sC=EduEvaluateSignal(100.0,100.0,99.0,EMPTY_VALUE);
    EduSignal sD=EduEvaluateSignal(100.0,100.0,99.0,0.0);
    bool okS=(sA==EDU_S_CANNOT_EVALUATE && sB==EDU_S_CANNOT_EVALUATE &&
              sC==EDU_S_CANNOT_EVALUATE && sD==EDU_S_CANNOT_EVALUATE);
    EduTLog("INVLD",okT1&&okT2&&okT3&&okT4&&okT5&&okT6&&okS,
            StringFormat("dup=%d rev=%d zero=%d empty=%d inf=%d nan=%d sma=%d",
                         okT1,okT2,okT3,okT4,okT5,okT6,okS));
   }

   //--- write results file (FILE_COMMON -> <Common>\Files\<name>) + journal
   string resDetail="Common\\Files\\"+outFile;
   int h=FileOpen(outFile,FILE_TXT|FILE_WRITE|FILE_COMMON|FILE_ANSI);
   bool saved=(h!=INVALID_HANDLE);
   string errTxt=(saved ? "" : StringFormat("|FileOpen error=%d",GetLastError()));
   string resLine="RESULTFILE|"+(saved?"PASS":"FAIL")+"|"+resDetail+errTxt;
   int nL=ArraySize(g_resultLines);
   ArrayResize(g_resultLines,nL+1);
   g_resultLines[nL]=resLine;
   if(saved) g_eduPass++; else g_eduFail++;
   PrintFormat("EXP8TEST|RESULTFILE|%s|%s|%s",saved?"PASS":"FAIL",resDetail,
               saved?"saved":StringFormat("FileOpen error=%d",GetLastError()));
   if(saved)
     {
      for(int i=0;i<ArraySize(g_resultLines);i++) FileWrite(h,g_resultLines[i]);
      FileWrite(h,StringFormat("TOTAL|PASS=%d|FAIL=%d|SKIP=%d",
                               g_eduPass,g_eduFail,g_eduSkip));
      FileClose(h);
     }
   PrintFormat("EXP8TEST|TOTAL|PASS=%d|FAIL=%d|RESULTFILE=%s",
               g_eduPass,g_eduFail,saved?"SAVED":"FAIL");
   return(g_eduFail);
  }

#endif