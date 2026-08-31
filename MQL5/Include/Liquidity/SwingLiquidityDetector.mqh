//+------------------------------------------------------------------+
//|                                     SwingLiquidityDetector.mqh    |
//|  Concrete detector: classic N-bar fractal swing high/low.         |
//|                                                                    |
//|  A swing HIGH at bar i (i = LeftBars back from the newest closed   |
//|  bar) is confirmed once RightBars bars have closed to its right    |
//|  with lower highs on both sides — i.e. it is fully confirmed and   |
//|  will never repaint. Same logic mirrored for swing LOW.            |
//|                                                                    |
//|  The most recently confirmed swing high is "current sell-side      |
//|  liquidity"; the most recently confirmed swing low is "current     |
//|  buy-side liquidity". Whichever the indicator is configured to     |
//|  track (see the Side input in the main file) is what gets          |
//|  published.                                                        |
//+------------------------------------------------------------------+
#property strict

#include "ILiquidityDetector.mqh"

class CSwingLiquidityDetector : public ILiquidityDetector
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_leftBars;
   int               m_rightBars;
   ENUM_LIQUIDITY_SIDE m_trackSide;   // which side this instance tracks

public:
   CSwingLiquidityDetector(const int leftBars, const int rightBars, const ENUM_LIQUIDITY_SIDE trackSide)
     : m_leftBars(MathMax(1, leftBars)),
       m_rightBars(MathMax(1, rightBars)),
       m_trackSide(trackSide)
     {
     }

   virtual bool Init(const string symbol, const ENUM_TIMEFRAMES tf) override
     {
      m_symbol = symbol;
      m_tf     = tf;
      return true;
     }

   //--- closedBarShift: shift (>=1) of the most recently CLOSED bar on the
   //    chart timeframe, i.e. shift 0 is the still-forming bar and must
   //    never be passed in here.
   //--- Once price trades through a resting level, it has been "swept" and
   //    is no longer a current liquidity target. Off by default at the
   //    caller's discretion (see g_invalidateOnSweep in the main file);
   //    always safe to call, it just no-ops while m_current is invalid.
   virtual void CheckInvalidation(const double lastPrice) override
     {
      if(!m_current.valid)
         return;

      bool swept = (m_current.side == LIQUIDITY_SIDE_HIGH && lastPrice >= m_current.price)
                || (m_current.side == LIQUIDITY_SIDE_LOW  && lastPrice <= m_current.price);

      if(swept)
         m_current.Reset();
     }

   virtual void OnBarClosed(const int closedBarShift) override
     {
      // The candidate fractal bar sits m_rightBars to the right of its own
      // left/right lookback window, all of which must already be closed.
      int candidateShift = closedBarShift + m_rightBars;
      int oldestNeeded    = candidateShift + m_leftBars;

      if(Bars(m_symbol, m_tf) <= oldestNeeded)
         return; // not enough history yet

      if(m_trackSide == LIQUIDITY_SIDE_HIGH || m_trackSide == LIQUIDITY_SIDE_NONE)
         CheckSwingHigh(candidateShift);

      if(m_trackSide == LIQUIDITY_SIDE_LOW || m_trackSide == LIQUIDITY_SIDE_NONE)
         CheckSwingLow(candidateShift);
     }

private:
   void CheckSwingHigh(const int candidateShift)
     {
      double candidateHigh = iHigh(m_symbol, m_tf, candidateShift);

      for(int i = 1; i <= m_leftBars; i++)
         if(iHigh(m_symbol, m_tf, candidateShift + i) >= candidateHigh)
            return; // not a fractal — something to the left is equal/higher

      for(int i = 1; i <= m_rightBars; i++)
         if(iHigh(m_symbol, m_tf, candidateShift - i) >= candidateHigh)
            return; // not a fractal — something to the right is equal/higher

      // Confirmed swing high => sell-side liquidity resting above price.
      // Flush placement: use the exact wick high, not a rounded/offset value.
      PublishLevel(candidateHigh, iTime(m_symbol, m_tf, candidateShift), LIQUIDITY_SIDE_HIGH);
     }

   void CheckSwingLow(const int candidateShift)
     {
      double candidateLow = iLow(m_symbol, m_tf, candidateShift);

      for(int i = 1; i <= m_leftBars; i++)
         if(iLow(m_symbol, m_tf, candidateShift + i) <= candidateLow)
            return;

      for(int i = 1; i <= m_rightBars; i++)
         if(iLow(m_symbol, m_tf, candidateShift - i) <= candidateLow)
            return;

      // Confirmed swing low => buy-side liquidity resting below price.
      PublishLevel(candidateLow, iTime(m_symbol, m_tf, candidateShift), LIQUIDITY_SIDE_LOW);
     }
  };
