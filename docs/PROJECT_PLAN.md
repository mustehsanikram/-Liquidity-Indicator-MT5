# Project Plan — MT5 Liquidity Indicator

## Objective

Build an extensible MT5 indicator that identifies and displays the
current liquidity level as a single, precisely-placed, non-repainting
horizontal line, with an architecture that supports adding new
liquidity-detection concepts without reworking existing code.

## Scope

**In scope**
- Single current-liquidity line display (one side at a time: high or low)
- Fractal swing high/low as the first detection method
- Non-repainting, closed-bar-confirmed logic
- Backfill of the most recent level on attach
- Optional sweep-based invalidation
- Extensible architecture (interface-based detectors)

**Out of scope (this phase)**
- Simultaneous dual-sided (high + low) display in a single instance
- Alerting (price-touch / sweep notifications)
- Multi-timeframe liquidity aggregation
- Additional detection methods beyond swing high/low (equal highs/lows,
  session high/low, order-block based) — planned as future phases,
  each as a self-contained detector class

## Phases

### Phase 1 — Core architecture & first detector (complete)
- `LiquidityTypes.mqh`, `ILiquidityDetector.mqh` interface
- `CSwingLiquidityDetector` (fractal swing high/low)
- `CLiquidityLineManager` (single flush line, no-gap placement)
- `LiquidityIndicator.mq5` wiring, compiled and pushed to `main`

### Phase 2 — Robustness fixes (complete)
- Historical backfill on attach
- Multi-bar-close-safe walking (handles reconnects/history jumps)
- Sweep-based invalidation (optional)
- Unique per-instance chart object naming
- Return-value checks/logging on chart object operations

### Phase 3 — Validation (planned)
- Manual visual verification against provided chart examples
- Forward-test on a demo account across at least one full session
  to confirm no repainting and correct real-time line updates
- Edge cases to verify explicitly:
  - Terminal restart / history gap mid-session
  - Symbol with unusual `_Point`/`_Digits` (e.g. 3-digit JPY pairs)
  - Multiple instances on one chart with different `InpSide` values

### Phase 4 — Additional detectors (future / on request)
- Equal highs/lows detector
- Session high/low detector (e.g. Asian session liquidity)
- Each added as an isolated class per the extension guide in
  `TECHNICAL_DESIGN.md`, with no changes to Phase 1–2 files expected

## Milestones / status

| Milestone                                   | Status      |
|----------------------------------------------|-------------|
| Core architecture + swing detector           | Done        |
| Robustness fixes (backfill, invalidation, naming) | Done   |
| Pushed to `main`                              | Done        |
| Documentation (this set)                      | Done        |
| Demo-account forward validation               | Not started |
| Additional detector types                     | Not started |

## Risks / open questions

- Sweep invalidation currently checks bid on every tick; if the
  intended definition of "swept" is wick-based rather than bid-touch,
  this needs to be revisited before Phase 3 sign-off.
- Dual-sided simultaneous display is not yet supported — confirm
  whether this is actually required before scoping Phase 4.
