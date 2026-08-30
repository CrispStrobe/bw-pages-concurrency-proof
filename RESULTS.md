# What this proved

Repo: `CrispStrobe/bw-pages-concurrency-proof` · site
<https://crispstrobe.github.io/bw-pages-concurrency-proof/> · measured 2026-08-30.

For `CrispStrobe/brickwright-lite` ROADMAP §2.1. That item carries a warning
paid for in downtime — a previous attempt at the fix published a **mismatched
tree**, an `index.html` naming chunks that 404 — and an instruction: prove it
somewhere other than that repo. This is the record.

The site is the smallest thing that can show the failure from outside:
`index.html` names `chunks/app.<sha>.js`, and that file exists only for the
commit that built it. A mixed tree is a 404 on the chunk, visible to `curl`,
with no logs involved. `scripts/watch-site.sh` samples every 5 s and prints only
CHANGES, so the transcript is the publication order.

## The measurement on the real repo, first

`brickwright-lite`, 200 most recent `build.yml` runs on `main`
(2026-08-24T23:17Z .. 2026-08-30T05:47Z):

```
success   101
failure    26
cancelled  72     <- 36 %
```

Of the 72 cancelled, classified by asking each run for its jobs:

```
62   ZERO JOBS      cancelled while queued. No runner, no verdict, no minutes.
 4   build:success  a green tree whose deploy was cancelled.
 6   build:cancelled after starting.
```

62 verdicts thrown away in six days. `concurrency: pages-${{ github.ref }}` is
one group for all of `main`, and GitHub holds exactly one pending entry per
group: a third push cancels the second while it is still queued.

## Phase 1 — the baseline shape, reproduced

`.github/workflows/pages.yml` as lite ships it: group keyed on the ref,
`cancel-in-progress: false`, build and deploy as two jobs of one run. Build
padded to 60 s so a burst overlaps. Then `scripts/burst.sh 5 baseline`.

| run | commit | conclusion | jobs |
|---|---|---|---|
| 33295710031 | f9bf057 baseline 1/5 | success | 2 |
| 33295713813 | 1dd0253 baseline 2/5 | **cancelled** | **0** |
| 33295717265 | eb0e6f3 baseline 3/5 | **cancelled** | **0** |
| 33295720367 | cbd59ec baseline 4/5 | **cancelled** | **0** |
| 33295723351 | 041e835 baseline 5/5 | success | 2 |

**5 pushes, 2 verdicts.** Three runs never got a job. This is the item as
written, reproduced in isolation.

## Phase 2 — the candidate

Three changes, nothing else:

1. the run's concurrency group is keyed on the **commit** for pushes
   (`github.sha`), on the PR number for pull requests. No two pushes share a
   group, so none is cancelled while queued.
2. the **deploy job** carries the one shared group that is left
   (`pages-deploy`, `cancel-in-progress: false`). Publication stays serialized;
   validation stops being.
3. the deploy **refuses to publish a tree older than the published one**.
   Ordering by queue release is not ordering by commit, and "the site lags
   several commits, arriving out of order" is what that costs.

First burst (`candidate 1..5/5`), runs 33295873557, 33295875547, 33295877641,
33295881123, 33295882892:

```
build:success  deploy:success
build:success  deploy:cancelled
build:success  deploy:success
build:success  deploy:cancelled
build:success  deploy:success
```

**5 pushes, 5 build verdicts, 0 starved.** Two deploys were superseded while
pending in the shared group — which is the intended outcome, an older tree not
publishing. Note the cost, so nobody is surprised by it: a superseded deploy
marks its RUN `cancelled` even though the build passed. That is distinguishable
from starvation and the distinction is mechanical — starvation has **zero
jobs**, this has `build: success`.

## The guard was wrong, and the scratch repo is why that is a footnote

Run **33295873557 attempt 2** re-ran an older commit (`654edac`) while
`ae89f11` was live. The guard printed:

```
published=654edacc7...  ours=654edacc7...
```

— it had read **itself**, concluded it was current, and **moved the live site
backwards** from `ae89f11` to `654edac`. Green check on the run.

Cause: declaring `environment: github-pages` makes GitHub create that
environment's deployment record when the **job starts**, before any step runs.
A guard that reads the newest `github-pages` deployment reads its own record.
The fix is to filter every occurrence of our own sha out of the list
(`jq 'select(.sha != $ours)'`); ours can appear more than once, because a re-run
adds another.

Second defect, same guard, run 33296240426: `gh api --jq` takes one argument and
no `--arg` — "accepts 1 arg(s), received 4". The step failed, and the deploy was
therefore skipped rather than run unguarded: the guard is **fail-closed**, which
is the right direction for a step whose job is to withhold a publish.

Both of these would have been a live-site incident in `brickwright-lite`. Both
cost nothing here. That is the whole argument for the instruction §2.1 gives.

## Phase 3 — the fixed candidate

`scripts/burst.sh 5 final`, runs 33296399703, 33296406582, 33296408593,
33296413340, 33296416120:

```
build:success  deploy:success
build:success  deploy:success
build:success  deploy:success
build:success  deploy:cancelled
build:success  deploy:success
```

**5/5 build verdicts.** `github-pages` deployment records, in creation order:

```
06:16:58  f178bf5   final 1/5
06:17:09  a445a1e   final 2/5
06:18:01  20b46e2   final 3/5
06:18:03  5978389   final 4/5   (record only -- its deploy job was cancelled)
06:18:07  d083bed   final 5/5
```

Strictly increasing by commit. The site transcript over the same window:

```
06:12:54  served=f21e3dbf7  chunk=200
06:17:57  served=a445a1e1b  chunk=200
06:18:26  served=d083bed25  chunk=200
```

Forward only, and the chunk `index.html` named was 200 at every sample — no
mismatched tree at any point during a five-deep burst.

## The guard, proven positively

Re-ran **33296399703** (`f178bf5`, the OLDEST commit of the burst) with
`d083bed` live:

```
published=d083bed25e831d4f3ba4524043638b2e1ade0820  ours=f178bf5cc5280f285...
compare ours...published = ahead
Run actions/deploy-pages@v4 = skipped
```

Run conclusion **success**; site still `d083bed`. An older tree presented for
publication stands down and says so, instead of winning because it happened to
reach the front of the queue last.

## The mismatched-tree hazard, and why it is out of scope by construction

The incident §2.1 warns about came from a per-**job** split. Artifact names are
unique within a RUN, not across runs: two jobs of one run writing
`github-pages`, or a deploy job resolving that name while a sibling was still
uploading, publishes an `index.html` from one tree beside chunks from another.
Separate RUNS cannot do this to each other — each run's artifact is scoped to
its own `GITHUB_RUN_ID` and `deploy-pages` resolves it there.

So the invariant is: **build and upload stay in one job, and the deploy takes
the artifact from its own run and never fetches one by name.** None of the three
changes touches it, which is why builds may run in parallel here and could not
then. In lite it is pinned by `test/pages-deploy-ordering.test.mjs` rather than
left as a comment.

## Known residual, stated rather than discovered later

The guard trusts a deployment RECORD as "published", and a record exists for a
deploy job that started and was then cancelled. The site can therefore sit one
commit behind if the newest deploy job's `deploy-pages` step itself FAILS after
an older run has already stood down for it. It cannot happen through
cancellation — a job is only cancelled when a newer one enters the group, and
the newest always deploys — and the next push or `deploy-daily` corrects it.
