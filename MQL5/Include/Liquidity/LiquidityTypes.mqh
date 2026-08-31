//+------------------------------------------------------------------+
//|                                              LiquidityTypes.mqh   |
//|  Shared types for the extensible Liquidity Indicator framework.  |
//|  Keep this file free of any detection or drawing logic — it only |
//|  defines the vocabulary that detectors and the line manager      |
//|  share, so new detectors never need to touch drawing code and    |
//|  vice versa.                                                     |
//+------------------------------------------------------------------+
#property strict

//--- The side of the market a liquidity level sits on.
enum ENUM_LIQUIDITY_SIDE
  {
   LIQUIDITY_SIDE_NONE = 0,   // no valid level yet
   LIQUIDITY_SIDE_HIGH = 1,   // resting above price (sell-side liquidity target)
   LIQUIDITY_SIDE_LOW  = 2    // resting below price (buy-side liquidity target)
  };

//--- A single liquidity level as understood by any detector.
//    Detectors fill this in; the line manager only ever reads it.
struct LiquidityLevel
  {
   bool              valid;       // false until a detector has found a real level
   double            price;       // exact price to draw the line at (flush w/ wick)
   datetime          barTime;     // time of the bar that produced/anchors the level
   ENUM_LIQUIDITY_SIDE side;      // high-side or low-side liquidity
   long              id;          // monotonically increasing id; changes => "new" level

   void Reset()
     {
      valid   = false;
      price   = 0.0;
      barTime = 0;
      side    = LIQUIDITY_SIDE_NONE;
      id      = -1;
     }
  };
