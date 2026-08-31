//+------------------------------------------------------------------+
//|                                          ILiquidityDetector.mqh   |
//|  Abstract base class ("interface") for liquidity detectors.      |
//|                                                                    |
//|  To add a new liquidity concept later (equal highs/lows, session  |
//|  high-low, order-block based, etc.) you write ONE new class that  |
//|  extends this and implements OnBarClosed(). Nothing else in the   |
//|  indicator needs to change.                                       |
//+------------------------------------------------------------------+
#property strict

#include "LiquidityTypes.mqh"

class ILiquidityDetector
  {
protected:
   LiquidityLevel    m_current;     // the level this detector currently believes is "live"
   long              m_nextId;

public:
                     ILiquidityDetector() : m_nextId(0) { m_current.Reset(); }
   virtual          ~ILiquidityDetector() {}

   //--- One-time setup (symbol/timeframe/params). Return false to abort init.
   virtual bool      Init(const string symbol, const ENUM_TIMEFRAMES tf) = 0;

   //--- Called once per newly CLOSED bar, walking oldest-to-newest when more
   //    than one bar closed since the last check (reconnects/history loads).
   //    Implementations inspect price[] history and update m_current when a
   //    new or updated liquidity level is confirmed. Must not repaint levels
   //    that were already confirmed on prior closed bars.
   virtual void      OnBarClosed(const int closedBarShift) = 0;

   //--- Optionally clear m_current if price has already traded through it
   //    (swept). Default no-op; detectors that care about sweeps override.
   //    Called every tick with the latest bid/close, BEFORE GetCurrentLevel()
   //    is read by the line manager.
   virtual void      CheckInvalidation(const double lastPrice) { }

   //--- Backfill: called once from OnInit with the total available bars so
   //    an already-confirmed level shows immediately on attach, instead of
   //    waiting for the next new bar close. Default implementation walks
   //    backward calling OnBarClosed() until a valid level is found or
   //    history runs out.
   virtual void      Backfill(const int totalBars, const int maxLookback = 5000)
     {
      int limit = MathMin(totalBars, maxLookback);
      for(int shift = 1; shift < limit && !m_current.valid; shift++)
         OnBarClosed(shift);
     }

   //--- Current level snapshot (may be invalid if nothing detected yet).
   LiquidityLevel    GetCurrentLevel() const { return m_current; }

protected:
   //--- Helper for subclasses: publish a (possibly) new level, assigning a
   //    fresh id only when the price/time actually changed, so the line
   //    manager can tell "same level, unchanged" from "new level arrived".
   void PublishLevel(const double price, const datetime barTime, const ENUM_LIQUIDITY_SIDE side)
     {
      bool isSameLevel = m_current.valid
                          && m_current.side == side
                          && MathAbs(m_current.price - price) < _Point * 0.5
                          && m_current.barTime == barTime;
      if(isSameLevel)
         return; // nothing changed — avoid bumping id / redraw churn

      m_current.valid   = true;
      m_current.price   = price;
      m_current.barTime = barTime;
      m_current.side    = side;
      m_current.id      = m_nextId++;
     }
  };
