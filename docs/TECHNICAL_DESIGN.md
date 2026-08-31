# Technical Design — MT5 Liquidity Indicator

## 1. Goal

Display exactly one horizontal line on the chart representing the
current "live" liquidity level, placed precisely at the relevant wick
with no visual gap, updating correctly as new levels are confirmed —
without repainting, and without relying on excessive user parameters
to compensate for incorrect underlying logic.

## 2. Architecture overview

The indicator is split into three independent layers so that changing
one never requires changing the others:

```
 ┌────────────────────────┐
 │  LiquidityIndicator.mq5 │   wiring only: OnInit / OnCalculate / OnDeinit
 └───────────┬─────────────┘
             │ uses
 ┌───────────▼─────────────┐        ┌──────────────────────────┐
 │  ILiquidityDetector      │        │  CLiquidityLineManager   │
 │  (abstract interface)    │        │  (owns 1 chart object)   │
 │                          │        │                          │
 │  + Init()                │        │  + Init()                │
 │  + OnBarClosed()         │        │  + Update(level)         │
 │  + CheckInvalidation()   │        │  + Hide()                │
 │  + Backfill()            │        └──────────────────────────┘
 │  + GetCurrentLevel()     │                     ▲
 └───────────┬──────────────┘                     │
             │ implemented by                     │ consumes
 ┌───────────▼──────────────┐                      │
 │ CSwingLiquidityDetector   │──────────────────────┘
 │ (fractal swing high/low)  │   LiquidityLevel struct
 └────────────────────────────┘
```

- **`LiquidityTypes.mqh`** — the only file both sides depend on. Defines
  `LiquidityLevel` (price, bar time, side, monotonic id) and
  `ENUM_LIQUIDITY_SIDE`. Detectors write this struct; the line manager
  only ever reads it.
- **`ILiquidityDetector.mqh`** — abstract base class. Owns the shared
  "publish a level" bookkeeping (`PublishLevel()`), so subclasses only
  need to implement the actual detection rule.
- **`CSwingLiquidityDetector`** — first concrete detector: classic N-bar
  fractal swing high/low.
- **`CLiquidityLineManager`** — the only class that touches chart
  objects. It reconciles the chart to whatever `LiquidityLevel` it's
  given: hide if invalid, no-op if unchanged, redraw if the id changed.
- **`LiquidityIndicator.mq5`** — thin glue. Creates one detector and one
  line manager, drives them from `OnCalculate`, nothing else.

## 3. Non-repainting design

Two mechanisms combine to guarantee the indicator never repaints:

1. **Confirmation window**: `CSwingLiquidityDetector` only accepts a
   candidate bar as a confirmed swing once `InpRightBars` bars have
   *closed* to its right with no higher/lower value on either side.
   By construction, a level published this way can never later be
   un-published or moved to a different price.
2. **Closed-bar-only evaluation**: `OnCalculate` tracks `Bars()` and
   only calls `OnBarClosed()` for shifts that have actually closed. If
   `Bars()` jumps by more than 1 between ticks (reconnect, bulk history
   load), the loop walks every newly closed bar, oldest first, so none
   are skipped.

The forming (current) bar, shift 0, is never passed to a detector.

## 4. Flush line placement

`CLiquidityLineManager` draws an `OBJ_HLINE` at the exact `level.price`
value the detector produced — the detector is responsible for supplying
the true wick price (`iHigh`/`iLow` at the confirmed bar), not a
rounded or padded value. Because a horizontal line object is priced
directly rather than positioned via pixel/offset math, there is no
source of "gap" between the line and the wick as long as the detector's
price is correct.

## 5. Sweep invalidation

`CheckInvalidation()` is called every tick. For the swing detector, a
level is considered swept (and cleared) once the current bid trades
through its price on the resting side (bid ≥ level for a high, bid ≤
level for a low). This is optional (`InpInvalidateOnSweep`) since
whether a swept level should disappear or persist is a product
decision, not purely technical.

## 6. Extension points

To add a new liquidity concept (equal highs/lows, session high/low,
order-block based, etc.):

1. Implement `ILiquidityDetector` in a new `.mqh` file.
2. Override `OnBarClosed()` with the new rule, calling `PublishLevel()`
   when a level is confirmed.
3. Optionally override `CheckInvalidation()` if the new concept has its
   own notion of "no longer current."
4. Swap the detector construction in `LiquidityIndicator.mq5`'s
   `OnInit()` — or extend it with an input-driven switch between
   multiple detectors if more than one should be selectable at once.

No changes to `CLiquidityLineManager` or the rest of `OnCalculate` are
required, since both only interact with the `ILiquidityDetector`
interface and the `LiquidityLevel` struct.

## 7. Known limitations / open items

- `ENUM_LIQUIDITY_SIDE_NONE` ("track both sides") is defined but not
  fully supported — `LiquidityLevel` can only represent one active
  level at a time. Tracking both sides simultaneously would need two
  detector instances (one per side) plus a second line manager, or a
  `LiquidityLevel[2]` extension.
- Sweep detection uses `SYMBOL_BID` on every tick; for a strictly
  wick-based sweep definition (rather than bid-touch), this would need
  to move into the closed-bar path instead.
- No unit tests are included; validation has been manual/visual against
  chart examples. See `PROJECT_PLAN.md` for planned test coverage.
