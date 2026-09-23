//+------------------------------------------------------------------+
//| MASK_SMA20_CROSS_EDU_shared.mqh                                  |
//| EXP-008 educational core: signal math, state, processing, render.|
//| UI-free: no trading, no alerts, no chart objects.                |
//| All array indexing is SERIES (index 0 = forming bar, growing     |
//| index = older bars).                                             |
//+------------------------------------------------------------------+
#ifndef MASK_SMA20_CROSS_EDU_SHARED_MQH
#define MASK_SMA20_CROSS_EDU_SHARED_MQH

//--- fixed spec constants
#define EDU_SMA_PERIOD       20
#define EDU_NEEDED_CLOSES    21
#define EDU_MAX_DRAW_BARS    1000
#define EDU_ARROW_POINTS     3

//--- signal states
enum EduSignal
  {
   EDU_S_NONE=0,            // valid result: no signal -> key recorded
   EDU_S_UP,                // up-cross on a closed bar
   EDU_S_DOWN,              // down-cross on a closed bar
   EDU_S_CANNOT_EVALUATE    // incomplete data: no key, retry later
  };

//--- price domain rule for this version (targeted at gold): reject
//    EMPTY_VALUE (==DBL_MAX), NaN/INF, and non-positive prices.
bool EduIsPriceValid(const double v)
  {
   if(v<=0.0)                return(false);
   if(v>=DBL_MAX)            return(false);
   if(!MathIsValidNumber(v)) return(false);
   return(true);
  }

//--- SMA domain rule: must be a finite positive value (not EMPTY_VALUE,
//    not NaN/INF, not <=0).
bool EduIsSmaValid(const double v)
  {
   if(v<=0.0)                return(false);
   if(v>=DBL_MAX)            return(false);
   if(!MathIsValidNumber(v)) return(false);
   return(true);
  }

//--- pure decision per spec: strict comparisons, no epsilon, no rounding.
//    Guards SMA inputs: if any SMA is not a valid number the verdict is
//    CANNOT_EVALUATE (the caller must not issue a signal from it).
EduSignal EduEvaluateSignal(const double c1,const double sma1,
                            const double c2,const double sma2)
  {
   if(!EduIsSmaValid(sma1) || !EduIsSmaValid(sma2)) return(EDU_S_CANNOT_EVALUATE);
   if(c2<=sma2 && c1>sma1) return(EDU_S_UP);
   if(c2>=sma2 && c1<sma1) return(EDU_S_DOWN);
   return(EDU_S_NONE);
  }

//--- SMA20 over closes[newestIdx .. newestIdx+19], series orientation,
//    canonical summation order: oldest -> newest
double EduSmaSeries(const double &close[],const int newestIdx)
  {
   if(newestIdx+EDU_SMA_PERIOD-1>=ArraySize(close)) return(EMPTY_VALUE);
   double sum=0.0;
   for(int k=newestIdx+EDU_SMA_PERIOD-1;k>=newestIdx;k--)
      sum+=close[k];
   return(sum/(double)EDU_SMA_PERIOD);
  }

//--- evaluation window for one closed bar at series index i
struct EduWindow
  {
   datetime bar_time;
   double   c1;
   double   sma1;
   double   c2;
   double   sma2;
  };

//--- binary search in a series-oriented time[] (strictly decreasing)
int EduSeriesIndex(const datetime &time[],const int rates_total,const datetime t)
  {
   int lo=0,hi=rates_total-1;
   while(lo<=hi)
     {
      int m=(lo+hi)>>1;
      if(time[m]==t)      return(m);
      if(time[m]>t)       lo=m+1;      // t is newer -> higher series index
      else                hi=m-1;
     }
   return(-1);
  }

//--- load + validate the window; requires i>=1 and i+20<rates_total.
//    Validates prices, times AND the two computed SMA values.
bool EduLoadWindow(const double &close[],const datetime &time[],
                   const int rates_total,const int i,EduWindow &w)
  {
   if(i<1)                                    return(false);
   if(i+EDU_SMA_PERIOD>=rates_total)          return(false); // i+20 < rates_total
   for(int j=i;j<=i+EDU_SMA_PERIOD;j++)
      if(!EduIsPriceValid(close[j]))          return(false);
   for(int j=i;j<=i+EDU_SMA_PERIOD-1;j++)
      if(time[j]<=time[j+1])                  return(false); // duplicate/reversed
   w.bar_time=time[i];
   w.c1      =close[i];
   w.c2      =close[i+1];
   w.sma1    =EduSmaSeries(close,i);
   w.sma2    =EduSmaSeries(close,i+1);
   if(!EduIsSmaValid(w.sma1) || !EduIsSmaValid(w.sma2)) return(false);
   return(true);
  }

//--- number of bars to evaluate/draw for this snapshot:
//    max(0, min(rates_total-21, 1000))
int EduTargetCount(const int rates_total)
  {
   if(rates_total<EDU_NEEDED_CLOSES+1)        return(0);
   int eligible=rates_total-EDU_NEEDED_CLOSES;
   return(MathMin(eligible,EDU_MAX_DRAW_BARS));
  }

//+------------------------------------------------------------------+
//| CEduState: valid-result keys (incl. NONE) + pending keys by time |
//+------------------------------------------------------------------+
struct EduRecord
  {
   datetime  bar_time;
   EduSignal st;
  };

class CEduState
  {
private:
   EduRecord m_rec[];
   datetime  m_pend[];

   int RecIndex(const datetime t) const
     {
      int n=ArraySize(m_rec);
      for(int i=0;i<n;i++)
         if(m_rec[i].bar_time==t) return(i);
      return(-1);
     }
   int PendIndex(const datetime t) const
     {
      int n=ArraySize(m_pend);
      for(int i=0;i<n;i++)
         if(m_pend[i]==t) return(i);
      return(-1);
     }
public:
   CEduState()                    { ArrayResize(m_rec,0); ArrayResize(m_pend,0); }
   void Clear()                   { ArrayResize(m_rec,0); ArrayResize(m_pend,0); }
   int  Records() const           { return(ArraySize(m_rec)); }
   int  Pending() const           { return(ArraySize(m_pend)); }
   EduRecord RecordAt(const int i) const { return(m_rec[i]); }
   datetime PendingAt(const int i) const { return(m_pend[i]); }

   bool HasRecord(const datetime t) const   { return(RecIndex(t)>=0); }
   EduSignal FindState(const datetime t) const
     {
      int k=RecIndex(t);
      return(k<0 ? EDU_S_CANNOT_EVALUATE : m_rec[k].st);
     }
   void AddRecord(const datetime t,const EduSignal st)
     {
      if(HasRecord(t)) return;                    // dedup (incl. NONE)
      int n=ArraySize(m_rec);
      ArrayResize(m_rec,n+1);
      m_rec[n].bar_time=t;
      m_rec[n].st=st;
     }
   void RemoveRecord(const datetime t)
     {
      int k=RecIndex(t); if(k<0) return;
      int n=ArraySize(m_rec);
      for(int j=k;j<n-1;j++) m_rec[j]=m_rec[j+1];
      ArrayResize(m_rec,n-1);
     }
   bool IsPending(const datetime t) const  { return(PendIndex(t)>=0); }
   void AddPending(const datetime t)
     {
      if(IsPending(t)||HasRecord(t)) return;
      int n=ArraySize(m_pend);
      ArrayResize(m_pend,n+1);
      m_pend[n]=t;
     }
   void RemovePending(const datetime t)
     {
      int k=PendIndex(t); if(k<0) return;
      int n=ArraySize(m_pend);
      for(int j=k;j<n-1;j++) m_pend[j]=m_pend[j+1];
      ArrayResize(m_pend,n-1);
     }
   //--- drop keys whose bar sits outside time[1..targetCount].
   //    Leaving the supported range is NOT a success verdict.
   void TrimTo(const datetime &time[],const int rates_total,const int targetCount)
     {
      for(int k=ArraySize(m_rec)-1;k>=0;k--)
        {
         datetime t=m_rec[k].bar_time;
         int idx=EduSeriesIndex(time,rates_total,t);
         if(idx<1 || idx>targetCount) RemoveRecord(t);
        }
      for(int k=ArraySize(m_pend)-1;k>=0;k--)
        {
         datetime t=m_pend[k];
         int idx=EduSeriesIndex(time,rates_total,t);
         if(idx<1 || idx>targetCount) RemovePending(t);
        }
     }
  };

//+------------------------------------------------------------------+
//| EduProcess: process one feed snapshot (series arrays incl. the   |
//| forming bar at index 0). Returns count of newly completed bars.  |
//+------------------------------------------------------------------+
int EduProcess(const double &close[],const datetime &time[],
               const int rates_total,CEduState &state)
  {
   const int target=EduTargetCount(rates_total);
   int processed=0;

   // 1) retry pending keys by TIME (their index may have shifted)
   for(int k=state.Pending()-1;k>=0;k--)
     {
      datetime t=state.PendingAt(k);
      int idx=EduSeriesIndex(time,rates_total,t);
      if(idx<1 || idx>target)
        {
         state.RemovePending(t);   // left supported range -> drop, not success
         continue;
        }
      EduWindow w;
      if(EduLoadWindow(close,time,rates_total,idx,w))
        {
         state.AddRecord(t,EduEvaluateSignal(w.c1,w.sma1,w.c2,w.sma2));
         state.RemovePending(t);
         processed++;
        }
      // else: still incomplete -> stays pending, no new-bar wait required
     }

   // 2) catch-up: every in-range closed bar not yet decided
   for(int i=1;i<=target;i++)
     {
      datetime t=time[i];
      if(state.HasRecord(t)||state.IsPending(t)) continue;
      EduWindow w;
      if(EduLoadWindow(close,time,rates_total,i,w))
        {
         state.AddRecord(t,EduEvaluateSignal(w.c1,w.sma1,w.c2,w.sma2));
         processed++;
        }
      else
         state.AddPending(t);
     }

   // 3) trim keys that left the supported range
   state.TrimTo(time,rates_total,target);
   return(processed);
  }

//+------------------------------------------------------------------+
//| EduRender: fill plot buffers (series). Always clears index 0 and |
//| the stale region beyond the current target.                     |
//| Bar arrival is detected by TIME (new index of the previous top   |
//| bar), not by rates_total-prevRatesTotal, so a new bar that       |
//| arrives with constant rates_total still moves old bars and their |
//| stale arrows are cleared.                                        |
//| Draw failure (bad high/low/point) leaves the cells EMPTY_VALUE:  |
//| no completion claim, and the next render retries from the state. |
//+------------------------------------------------------------------+
bool EduDrawArrow(double &up[],double &down[],const int i,
                  const EduSignal st,const double &high[],const double &low[],
                  const double point)
  {
   if(point<=0.0 || point>=DBL_MAX || !MathIsValidNumber(point)) return(false);
   double price=0.0;
   if(st==EDU_S_UP)
     {
      if(!EduIsPriceValid(low[i]))                       return(false);
      price=low[i]-EDU_ARROW_POINTS*point;
     }
   else if(st==EDU_S_DOWN)
     {
      if(!EduIsPriceValid(high[i]))                      return(false);
      price=high[i]+EDU_ARROW_POINTS*point;
     }
   else
      return(false);
   if(!EduIsPriceValid(price))                            return(false);
   if(st==EDU_S_UP)
     {
      up[i]=price;
      down[i]=EMPTY_VALUE;
     }
   else
     {
      down[i]=price;
      up[i]=EMPTY_VALUE;
     }
   return(true);
  }

void EduRender(double &up[],double &down[],
               const datetime &time[],const double &high[],const double &low[],
               const int rates_total,const CEduState &state,
               const double point,int &prevRatesTotal,int &lastManaged,
               datetime &prevTopTime)
  {
   if(rates_total<1) { prevRatesTotal=rates_total; return; }
   const int target=EduTargetCount(rates_total);

   //--- displacement of existing bars since the previous view, by TIME
   int shift=0;
   if(prevRatesTotal>0)
     {
      int ti=EduSeriesIndex(time,rates_total,prevTopTime);
      if(ti<0) shift=MathMax(rates_total-prevRatesTotal,0); // top bar gone: count fallback
      else     shift=ti;                                    // new position of the old top bar
     }
   int ownedMax=lastManaged+(shift>0 ? shift : 0); // previously owned cells at the current view

   // forming bar: always empty, explicitly
   up[0]=EMPTY_VALUE;
   down[0]=EMPTY_VALUE;

   // in-range closed bars: state is the single source of truth;
   // a failed draw keeps cells EMPTY and is retried on the next call
   for(int i=1;i<=target && i<rates_total;i++)
     {
      EduSignal st=state.FindState(time[i]);
      if(st==EDU_S_UP || st==EDU_S_DOWN)
        {
         if(!EduDrawArrow(up,down,i,st,high,low,point))
           { up[i]=EMPTY_VALUE; down[i]=EMPTY_VALUE; }
        }
      else
        { up[i]=EMPTY_VALUE; down[i]=EMPTY_VALUE; }
     }

   // stale region beyond current target: clear cells we previously owned
   int stale=MathMin(ownedMax,rates_total-1);
   for(int i=target+1;i<=stale;i++)
     { up[i]=EMPTY_VALUE; down[i]=EMPTY_VALUE; }

   lastManaged=MathMax(ownedMax,target);
   prevRatesTotal=rates_total;
   prevTopTime=time[0];
  }

#endif