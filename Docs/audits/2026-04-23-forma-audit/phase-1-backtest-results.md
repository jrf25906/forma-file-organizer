# B4 Phase 1 Destination Prediction Backtest Results

Date: 2026-04-24T04:05:44Z

Plan: `Docs/plans/2026-04-23-destination-prediction-ml-fix-plan.md`

## Command

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Integration" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/DestinationPredictionBacktest"
```

## Artifacts

- CSV: `/Users/jamesfarmer/Library/Containers/jamesfarmer.Forma-File-Organizing/Data/tmp/FormaDestinationPredictionBacktests/destination-prediction-backtest-1-2026-04-24T040544Z.csv`
- JSON: `/Users/jamesfarmer/Library/Containers/jamesfarmer.Forma-File-Organizing/Data/tmp/FormaDestinationPredictionBacktests/destination-prediction-backtest-1-2026-04-24T040544Z.json`

## Summary

| Metric | Value |
| --- | ---: |
| Resolved destination records | 116 |
| Skipped activities | 232 |
| Train records | 92 |
| Holdout records | 24 |
| Pattern-only Top-1 | 2/24 (0.083) |
| ML-only Top-1 | 0/24 (0.000) |
| ML minus pattern Top-1 | -0.083 |
| Gate decision | `insufficientResolvedRecords` |

ML prediction error:

```text
The operation couldn’t be completed. (Forma_File_Organizing.DestinationPredictionService.PredictionError error 2.)
```

## Gate Decision

Phase 2 is not unlocked.

The Phase 1 gate requires at least 500 historical resolved destination records and ML Top-1 accuracy at least 10 percentage points above pattern-only Top-1. This run only found 116 resolved records, so the sample-size gate failed before accuracy can justify live shadow measurement.

The measured accuracy is also not encouraging: pattern-only matched 2 holdout records, while ML matched 0 and still failed with unavailable probability output. Do not wire production telemetry or live shadow logging from this result alone. The acceptable next moves are to rerun after enough resolved history exists, import a larger representative resolved-history fixture, or pivot B4 toward removing the ML branch if the audit wants closure without waiting for more data.
