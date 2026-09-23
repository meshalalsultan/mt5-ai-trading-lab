//+------------------------------------------------------------------+
//| MASK_SMA20_CROSS_EDU_v01.mq5                                     |
//| EXP-008 Test B: educational arrows indicator.                    |
//| No trading, no alerts, no chart objects. Buffers only.           |
//+------------------------------------------------------------------+
#property copyright   "EXP-008"
#property version     "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
//--- plot 0: up arrows
#property indicator_label1  "MASK UP"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
//--- plot 1: down arrows
#property indicator_label2  "MASK DOWN"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <MASK_EDU\MASK_SMA20_CROSS_EDU_shared.mqh>

double     g_up[],g_down[];
CEduState  g_state;
int        g_prevRatesTotal=0;
int        g_lastManaged=0;
datetime   g_prevTopTime=0;
double     g_point=0.0;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,g_up,INDICATOR_DATA);
   ArraySetAsSeries(g_up,true);          // uniform series indexing AFTER binding
   SetIndexBuffer(1,g_down,INDICATOR_DATA);
   ArraySetAsSeries(g_down,true);

   PlotIndexSetInteger(0,PLOT_ARROW,233);   // up arrow glyph
   PlotIndexSetInteger(1,PLOT_ARROW,234);   // down arrow glyph
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);

   string shortname="MASK_SMA20_CROSS_EDU_v01";
   IndicatorSetString(INDICATOR_SHORTNAME,shortname);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],
                const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(rates_total<1) return(0);
   // explicit uniform series indexing for the arrays we read
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);

   if(prev_calculated==0)
     {
      // full rebuild: wipe previous state AND drawing, rebuild both
      // from the current history only.
      g_state.Clear();
      for(int i=0;i<rates_total;i++)
        { g_up[i]=EMPTY_VALUE; g_down[i]=EMPTY_VALUE; }
      g_lastManaged=0;
      g_prevRatesTotal=0;
      g_prevTopTime=0;
      EduProcess(close,time,rates_total,g_state);
     }
   else
      EduProcess(close,time,rates_total,g_state);

   EduRender(g_up,g_down,time,high,low,rates_total,g_state,g_point,
             g_prevRatesTotal,g_lastManaged,g_prevTopTime);
   return(rates_total);
  }
//+------------------------------------------------------------------+