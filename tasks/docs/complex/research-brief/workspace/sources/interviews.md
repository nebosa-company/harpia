# Customer interviews, February 2026

Fourteen customers were interviewed between 3 and 21 February about the
data export workflow. Interviews ran 40 to 55 minutes and followed the
same script. Excerpts below are verbatim; names are replaced by a role
and an account size band.

Of the fourteen, nine have written their own script or scheduled job
around the export rather than using the console, and five run it by hand
from the console every time.

## Data engineer, large account

The export is the first thing I run and the last thing I trust. It
finishes when it finishes, and I have never been able to tell anyone
when that will be.

I schedule it for two in the morning purely so that the uncertainty
happens while I am asleep. That is not a workflow, that is a
superstition.

## Operations lead, mid account

We have three people whose Monday is shaped by this. They start the
export, they go and do something else, they come back, and about one
Monday in four they find it has failed and they start again.

The failure is never explained. It says the run did not complete, which
we already knew.

## Analyst, small account

I do not think of it as slow. I think of it as unpredictable, which is
worse, because I cannot plan around it. Twenty minutes would be fine.
Twenty minutes or ninety minutes is not fine.

## Platform engineer, large account

We wrote a wrapper around it in the end. The wrapper polls, retries
twice, and pages us if the whole thing takes more than two hours. That
wrapper is now a piece of production software that we maintain, for an
export button.

## Finance systems owner, mid account

The part that costs us is the reconciliation afterwards, not the export
itself. When the export is split into parts we have to stitch them back
together before anything downstream will read it, and nothing tells us
in advance how many parts there will be.

## What the interviews did not show

Nobody asked for the export to be faster in absolute terms. Every
complaint that sounded like speed turned out, on the second question, to
be about not knowing when it would finish.
