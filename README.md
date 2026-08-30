# bw-pages-concurrency-proof

Scratch repo. It exists for one measurement, recorded in `RESULTS.md`.

`CrispStrobe/brickwright-lite` ROADMAP §2.1 ("deploy starvation") has a warning
attached to it: a previous attempt at the fix **took the live site down** by
publishing a mismatched tree — an `index.html` naming chunks that 404. The
roadmap's instruction to whoever retries is therefore "prove it somewhere other
than this repo". This is that somewhere.

The site is deliberately the smallest thing that can *show* a mismatched tree:
`index.html` names `chunks/app.<sha>.js`, and that file exists only for the
commit that built it. A published tree that mixes two builds shows up as a 404
on the chunk, from the outside, without reading any logs.

Nothing here is a dependency of anything. Delete it when §2.1 is closed.
