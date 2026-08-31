# MT5 Liquidity Indicator

An extensible current-liquidity indicator for MetaTrader 5. Draws a single
horizontal line at the currently "live" liquidity level, flush with the
relevant wick, and updates it as new levels are confirmed.

The codebase is deliberately structured so new liquidity concepts (equal
highs/lows, session high/low, order-block based, etc.) can be added as
new detector classes without touching the drawing logic or the main
indicator file. See `docs/TECHNICAL_DESIGN.md` for the architecture and
`docs/PROJECT_PLAN.md` for scope and status.

## Repository structure

```
MQL5/
  Include/Liquidity/
    LiquidityTypes.mqh          Shared enums/structs
    ILiquidityDetector.mqh      Abstract detector interface
    SwingLiquidityDetector.mqh  Concrete detector: fractal swing high/low
    LiquidityLineManager.mqh    Draws/updates the single liquidity line
  Indicators/
    LiquidityIndicator.mq5      Main indicator entry point (wiring only)
docs/
  TECHNICAL_DESIGN.md
  PROJECT_PLAN.md
```

## Installation

1. Copy `MQL5/Include/Liquidity/` into your terminal's
   `MQL5/Include/Liquidity/` folder.
2. Copy `MQL5/Indicators/LiquidityIndicator.mq5` into your terminal's
   `MQL5/Indicators/` folder.
3. Open MetaEditor, compile `LiquidityIndicator.mq5` (F7).
4. Attach the compiled indicator to a chart from the Navigator panel.

## Inputs

| Input                  | Default       | Description |
|-------------------------|---------------|-------------|
| `InpLeftBars`            | 5             | Bars required to the left to confirm a swing fractal |
| `InpRightBars`           | 5             | Bars required to the right to confirm a swing fractal |
| `InpSide`                | High          | Which side's liquidity to track (High / Low) |
| `InpInvalidateOnSweep`   | true          | Clear the level once price trades through it |
| `InpMaxBackfillBars`     | 5000          | How far back to look for a level on attach |
| `InpLineColor`           | DodgerBlue    | Line color |
| `InpLineWidth`           | 1             | Line width |
| `InpLineStyle`           | Solid         | Line style |

## Behavior notes

- **Non-repainting**: levels are only confirmed on fully closed bars.
- **Backfill on attach**: the most recently confirmed level is shown
  immediately rather than waiting for the next bar close.
- **Flush placement**: the line is drawn at the exact wick price the
  detector reports — there is no offset/rounding step that could
  introduce a visual gap.
- **Multi-instance safe**: chart objects are named per symbol/timeframe/
  side/chart id, so multiple copies of the indicator can run on the
  same chart without colliding.

## Extending with a new detector

1. Create `MQL5/Include/Liquidity/YourDetector.mqh` implementing
   `ILiquidityDetector` (see `SwingLiquidityDetector.mqh` as a template).
2. In `LiquidityIndicator.mq5`, `#include` it and swap the
   `new CSwingLiquidityDetector(...)` line for your class.

No other file needs to change — the line manager and main indicator
only ever talk to the `ILiquidityDetector` interface and the
`LiquidityLevel` struct.

## License

Proprietary — all rights reserved unless a license file is added.
