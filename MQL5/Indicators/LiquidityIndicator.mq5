//+------------------------------------------------------------------+
//|                                          LiquidityIndicator.mq5   |
//|  Extensible current-liquidity indicator.                          |
//|                                                                    |
//|  Draws exactly one flush horizontal line at the current liquidity  |
//|  level. Detection logic lives entirely in ILiquidityDetector       |
//|  subclasses (see Include\Liquidity\); drawing lives entirely in    |
//|  CLiquidityLineManager. This file only wires the two together and  |
//|  guarantees detection runs once per CLOSED bar (no repainting).    |
//|                                                                    |
//|  TO ADD A NEW LIQUIDITY CONCEPT LATER:                             |
//|    1. Create MyDetector.mqh implementing ILiquidityDetector.       |
//|    2. #include it below and replace the g_detector construction   |
//|       (or add an input to pick between multiple detectors).       |
//|    Nothing else in this file, or in LiquidityLineManager, changes. |
//+------------------------------------------------------------------+
#property copyright "Mustehsan"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Liquidity/LiquidityTypes.mqh>
#include <Liquidity/ILiquidityDetector.mqh>
#include <Liquidity/SwingLiquidityDetector.mqh>
#include <Liquidity/LiquidityLineManager.mqh>

//--- Inputs kept deliberately minimal: they configure WHICH bars count as
//    a swing, not ad-hoc fudge factors to compensate for wrong logic.
input int               InpLeftBars   = 5;                    // Bars required on each side to confirm a swing
input int               InpRightBars  = 5;
input ENUM_LIQUIDITY_SIDE InpSide     = LIQUIDITY_SIDE_HIGH;   // Which side's liquidity to track
input bool              InpInvalidateOnSweep = true;           // Clear the level once price trades through it
input int               InpMaxBackfillBars   = 5000;           // How far back to look for a level on attach
input color             InpLineColor  = clrDodgerBlue;
input int               InpLineWidth  = 1;
input ENUM_LINE_STYLE   InpLineStyle  = STYLE_SOLID;

ILiquidityDetector      *g_detector   = NULL;
CLiquidityLineManager   *g_lineManager = NULL;
int                     g_lastProcessedBars = -1;  // Bars() at last fully-processed closed bar

int OnInit()
  {
   g_detector = new CSwingLiquidityDetector(InpLeftBars, InpRightBars, InpSide);

   if(!g_detector.Init(_Symbol, _Period))
     {
      Print("LiquidityIndicator: detector Init() failed");
      return(INIT_FAILED);
     }

   g_lineManager = new CLiquidityLineManager("LiqInd", _Symbol, _Period, InpSide, ChartID());
   g_lineManager.Init(ChartID());

   // Backfill so an already-confirmed level is visible immediately on
   // attach, instead of waiting for the next new bar close.
   int totalBars = Bars(_Symbol, _Period);
   g_detector.Backfill(totalBars, InpMaxBackfillBars);
   g_lastProcessedBars = totalBars;

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_detector != NULL)
     {
      delete g_detector;
      g_detector = NULL;
     }
   if(g_lineManager != NULL)
     {
      g_lineManager.Hide();
      delete g_lineManager;
      g_lineManager = NULL;
     }
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   // --- Non-repainting guarantee -------------------------------------
   // Walk every bar that closed since we last checked (not just the most
   // recent one), so a reconnect or bulk history load that advances Bars()
   // by more than 1 never silently skips a swing.
   int currentBars = Bars(_Symbol, _Period);

   if(currentBars > g_lastProcessedBars && g_lastProcessedBars >= 0)
     {
      int newBars = currentBars - g_lastProcessedBars;
      // Oldest-first: highest shift = oldest of the newly closed bars.
      for(int shift = newBars; shift >= 1; shift--)
         g_detector.OnBarClosed(shift);
     }
   g_lastProcessedBars = currentBars;

   if(InpInvalidateOnSweep)
      g_detector.CheckInvalidation(SymbolInfoDouble(_Symbol, SYMBOL_BID));

   // Cheap on every tick: keep the drawn line in sync with the current
   // (already-confirmed) level. Update() itself no-ops if nothing changed.
   g_lineManager.Update(g_detector.GetCurrentLevel(), InpLineColor, InpLineWidth, InpLineStyle);

   return(rates_total);
  }
