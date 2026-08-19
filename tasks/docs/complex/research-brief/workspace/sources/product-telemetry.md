# Export telemetry, 2025 Q4

Every export run is instrumented end to end. The figures below cover
41,207 completed runs between 1 October and 31 December 2025. Runs that
failed are excluded from the duration statistics and counted separately.

## Duration

| Statistic | Minutes |
| --- | --- |
| Median | 18 |
| 75th percentile | 34 |
| 95th percentile | 71 |
| 99th percentile | 186 |

The median run takes 18 minutes and the 95th percentile takes 71
minutes, so the slowest one run in twenty takes almost four times as
long as the typical one.

## Failures

Of the 43,006 runs started in the quarter, 1,799 did not complete, a
failure rate of 4.2 percent. Two thirds of the failures happened after
the run had been going for more than an hour.

## Size

| Statistic | Archive size |
| --- | --- |
| Median | 340 MB |
| 95th percentile | 2.9 GB |

Runs whose archive would exceed 2 GB are written out in 500 MB parts.
That threshold is crossed by 6 percent of runs, and those runs account
for 61 percent of the total bytes transferred.
