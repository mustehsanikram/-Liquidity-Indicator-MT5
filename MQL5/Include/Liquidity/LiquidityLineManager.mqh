//+------------------------------------------------------------------+
//|                                     LiquidityLineManager.mqh      |
//|  Owns exactly one chart object: the current liquidity line.       |
//|                                                                    |
//|  This class knows NOTHING about detection logic — it only takes    |
//|  a LiquidityLevel and makes the chart match it:                    |
//|    - no level yet / invalid  -> line hidden                        |
//|    - same level as before    -> no redraw (avoids flicker)         |
//|    - new level (id changed)  -> old line removed, new one drawn    |
//|                                                                    |
//|  Because drawing is fully decoupled from detection, swapping in a  |
//|  different ILiquidityDetector never requires touching this file.   |
//+------------------------------------------------------------------+
#property strict

#include "LiquidityTypes.mqh"

class CLiquidityLineManager
  {
private:
   string   m_objName;
   long     m_lastDrawnId;
   long     m_chartId;

public:
   CLiquidityLineManager(const string namePrefix, const string symbol, const ENUM_TIMEFRAMES tf,
                         const ENUM_LIQUIDITY_SIDE side, const long chartIdForName)
     : m_lastDrawnId(-1),
       m_chartId(0)
     {
      string sideTag = (side == LIQUIDITY_SIDE_HIGH) ? "HI" : (side == LIQUIDITY_SIDE_LOW) ? "LO" : "ANY";
      m_objName = StringFormat("%s_%s_%s_%s_%I64d", namePrefix, symbol, EnumToString(tf), sideTag, chartIdForName);
     }

   void Init(const long chartId)
     {
      m_chartId = chartId;
     }

   //--- Reconcile the chart with the given level. Safe to call every tick;
   //    it only touches chart objects when something actually changed.
   void Update(const LiquidityLevel &level, const color clr, const int width, const ENUM_LINE_STYLE style)
     {
      if(!level.valid)
        {
         Hide();
         return;
        }

      if(level.id == m_lastDrawnId)
        {
         // Same level: just keep the price exact in case of tick-level
         // rounding differences — cheap call, avoids any visual gap drift.
         if(ObjectFind(m_chartId, m_objName) >= 0)
           {
            if(!ObjectMove(m_chartId, m_objName, 0, 0, level.price))
               PrintFormat("LiquidityLineManager: ObjectMove failed for %s, err=%d", m_objName, GetLastError());
           }
         return;
        }

      Draw(level, clr, width, style);
      m_lastDrawnId = level.id;
     }

   void Hide()
     {
      if(ObjectFind(m_chartId, m_objName) >= 0)
         ObjectDelete(m_chartId, m_objName);
      m_lastDrawnId = -1;
     }

private:
   void Draw(const LiquidityLevel &level, const color clr, const int width, const ENUM_LINE_STYLE style)
     {
      // A horizontal line object is inherently flush with the exact price —
      // no manual offset/gap math is needed as long as we feed it the exact
      // wick price the detector produced.
      if(ObjectFind(m_chartId, m_objName) >= 0)
         ObjectDelete(m_chartId, m_objName);

      if(!ObjectCreate(m_chartId, m_objName, OBJ_HLINE, 0, 0, level.price))
        {
         PrintFormat("LiquidityLineManager: ObjectCreate failed for %s, err=%d", m_objName, GetLastError());
         return;
        }
      ObjectSetInteger(m_chartId, m_objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chartId, m_objName, OBJPROP_WIDTH, width);
      ObjectSetInteger(m_chartId, m_objName, OBJPROP_STYLE, style);
      ObjectSetInteger(m_chartId, m_objName, OBJPROP_BACK, false);
      ObjectSetInteger(m_chartId, m_objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, m_objName, OBJPROP_HIDDEN, true);

      string sideLabel = (level.side == LIQUIDITY_SIDE_HIGH) ? "Sell-side liquidity" : "Buy-side liquidity";
      ObjectSetString(m_chartId, m_objName, OBJPROP_TOOLTIP,
                       sideLabel + " @ " + DoubleToString(level.price, _Digits));
     }
  };
