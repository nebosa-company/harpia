# Research brief: export workflow friction

## Question

Why do customers describe the data export as the worst part of their
week, and is the problem the time the export takes or something else?

## Method

Five existing sources were read end to end: fourteen customer interviews
run in February 2026, the January 2026 administrator survey, export
telemetry for 2025 Q4, the support ticket analysis for the same quarter,
and the Hallam Group vendor comparison commissioned in December 2025. No
new research was carried out. Every claim below is tied to the lines of
the source it comes from.

## Key numbers

| Question | Answer | Source | Lines |
| --- | --- | --- | --- |
| What share of survey respondents named the data export as the slowest part of their week? | 62% | sources/survey-2026.md | 11-11 |
| What is the median export duration, in minutes? | 18 | sources/product-telemetry.md | 11-11 |
| What is the 95th percentile export duration, in minutes? | 71 | sources/product-telemetry.md | 13-13 |
| How many tickets in the quarter mentioned an export timing out? | 137 | sources/support-analysis.md | 8-9 |
| How many of those timeout tickets describe a run that had not failed at all? | 84 | sources/support-analysis.md | 18-19 |
| How many usable responses did the survey receive? | 611 | sources/survey-2026.md | 3-4 |

## Findings

### F1. Customers cannot tell when a run will finish

The interviews return to the same complaint in different words: the
export gives no signal at all while it runs, so the operator has nothing
to plan around and nothing to tell anyone else.

> The export is the first thing I run and the last thing I trust. It
> finishes when it finishes, and I have never been able to tell anyone
> when that will be.

[sources/interviews.md:14-16]

### F2. The problem is predictability, not speed

The survey puts the export ahead of every other weekly task, and the
interviews say plainly that the complaint underneath is uncertainty
rather than duration.

> Sixty-two percent of respondents named the data export as the slowest
> part of their week, which is more than the other three answers put
> together.

[sources/survey-2026.md:16-18]

> Nobody asked for the export to be faster in absolute terms. Every
> complaint that sounded like speed turned out, on the second question, to
> be about not knowing when it would finish.

[sources/interviews.md:53-55]

### F3. The spread of durations is what makes planning impossible

Telemetry shows the typical run is short and the tail is long. A
customer who has seen both has no way to tell, mid-run, which one they
are in.

> The median run takes 18 minutes and the 95th percentile takes 71
> minutes, so the slowest one run in twenty takes almost four times as
> long as the typical one.

[sources/product-telemetry.md:16-18]

### F4. Most timeout tickets are about silence, not failure

The support data separates the two problems cleanly. The majority of
tickets tagged as timeouts concern runs that were working correctly and
simply had not said so.

> Reading the 137 tickets, 84 of them describe a run that had not failed
> at all. The customer had waited past the point where they expected an
> answer, assumed the run was stuck, and opened a ticket. In 62 of those
> 84 cases the export completed successfully while the ticket was open.

[sources/support-analysis.md:18-21]

### F5. Competitors are not faster, they are more talkative

The comparison is the strongest external evidence that throughput is not
the gap. On duration the platform is mid-field; on in-flight information
it is last with one other product.

> The report's conclusion is blunt about where the gap is. Kestrel's
> weakness in this category is not throughput but the complete absence of
> in-flight information, which the report describes as the single largest
> difference between the products tested.

[sources/vendor-comparison.md:29-32]

## Recommendations

- Show progress while a run is in flight, because F1 and F5 both point
  at the absence of any in-flight signal rather than at duration.
- Give an estimate at the start of a run and revise it as the run
  proceeds, which is what F3 says customers cannot infer for themselves.
- Notify on completion through the same channel the run was started
  from, so that the waiting described in F4 stops producing tickets.
- Leave throughput work out of this round: F2 and F5 agree that speed is
  not what customers are asking for.

## Evidence index

| Ref | Source | Lines |
| --- | --- | --- |
| E1 | sources/interviews.md | 14-16 |
| E2 | sources/survey-2026.md | 16-18 |
| E3 | sources/interviews.md | 53-55 |
| E4 | sources/product-telemetry.md | 16-18 |
| E5 | sources/support-analysis.md | 18-21 |
| E6 | sources/vendor-comparison.md | 29-32 |
