# Vendor comparison, Hallam Group, December 2025

Commissioned comparison of bulk export behaviour across six platforms in
the same category. Hallam ran the same workload on each and recorded
what the product told the operator while it ran.

## What operators are told

| Platform | Progress shown | Estimate given | Notification on completion |
| --- | --- | --- | --- |
| Platform A | Percentage complete | Yes | Email and webhook |
| Platform B | Stage name only | No | Email |
| Platform C | Percentage complete | Yes | Webhook |
| Platform D | Nothing | No | Email |
| Platform E | Rows processed | Yes | Email and webhook |
| Kestrel | Nothing | No | Email |

Four of the six platforms give the operator an estimate before the run
begins. Kestrel and Platform D give nothing at all, and both were the
platforms where Hallam's testers most often checked whether the job was
still alive.

## Durations

Kestrel was not the slowest platform tested. On the standard workload it
placed third of six on median duration and second on the 95th
percentile, so the absolute speed of the export is competitive.

The report's conclusion is blunt about where the gap is. Kestrel's
weakness in this category is not throughput but the complete absence of
in-flight information, which the report describes as the single largest
difference between the products tested.
