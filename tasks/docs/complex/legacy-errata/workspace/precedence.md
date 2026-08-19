# Which document wins

The operations documentation grew for six years without anybody owning
it. Six documents now describe overlapping ground and they do not all
agree. Before merging them, apply these rules, in this order, to decide
which statement of a fact is the correct one:

1. **Signature beats everything.** A document whose front matter says
   `status: signed` was approved by the accountable owner. Where a
   signed document and an unsigned one disagree, the signed one is
   correct, whatever their dates.

2. **Then the later document wins.** Where two documents of the same
   status disagree, the one with the later `updated:` date in its front
   matter is correct.

3. **Then the file name.** If the rules above still leave a tie, the
   document whose file name sorts first alphabetically is correct.

A document being wrong about one fact says nothing about the rest of it.
Every document in the set is right about something, and a fact that only
one document states is not in dispute at all — it is simply the fact.
