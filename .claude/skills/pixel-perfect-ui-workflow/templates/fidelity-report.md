# Fidelity report — <screen> (<locale>, <viewport>@<dpr>x)

## Revisions
- App commit: · API commit (if any): · Reference sha256:
- Capture method: (capture_web.mjs | tool/ui_audit | device) and its exact JSON line
- Data in the capture: production behaviour | local API data | simulated | test fixture

## Gates
| Gate | Status | Evidence |
| ---- | ------ | -------- |
| A reference + viewport verified | | |
| B specification complete | | |
| C real app architecture used | | |
| D real screenshots captured | | |
| E differences measured | | |
| F regressions + functional tests pass | | |
| G evidence + remaining discrepancies reported | | |

## Iterations
| # | Commit | MAE | SSIM | changed@16 | changed@32 | Worst region | Fix applied |
| - | ------ | --- | ---- | ---------- | ---------- | ------------ | ----------- |

## Remaining discrepancies (must be complete)
| Region | Type (layout / colour / typography / asset / environment) | Size of error | Cause | Fixable? |
| ------ | --------------------------------------------------------- | ------------- | ----- | -------- |

## Verdict
State the profile used (`controlled` or `cross_environment`), whether it passed, and what the numbers do
NOT prove. Never write "pixel-perfect" unless changed@16 is 0 % in a controlled environment.
