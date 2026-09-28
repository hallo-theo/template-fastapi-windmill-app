# Stage 3 · Build — `plan.md`

One file per change: `plan/<slug>.md`, produced in **plan mode** before any
code. Template:
[`hallo-theo/.github/sdlc`](https://github.com/hallo-theo/.github/tree/main/sdlc).

Names: files that change · order of work · tests that prove it · risks.

Pin its blob SHA in the PR body at approval:

```sh
git rev-parse HEAD:plan/<slug>.md
```

Without the pin, a "does the diff match the plan?" check compares the diff
against a plan that may have been rewritten in the same commit to match it —
passing trivially, forever.

## Front-Door repos: `roadmap.md` + `tickets.json`

On Front-Door-born repos this folder also holds the admin agent's build plan,
written by `admin-decompose.yml` after the first slice merges:

- `plan/roadmap.md` — the human-readable plan (mission, waves, out of scope,
  risks).
- `plan/tickets.json` — the machine-readable twin the Front Door ingests on
  merge to dispatch worker agents. Schema (every field required, ≤12 tickets,
  `blocked_by` only into lower waves) and full contract:
  [`hallo-theo/.github → sdlc/templates/roadmap.md`](https://github.com/hallo-theo/.github/blob/main/sdlc/templates/roadmap.md).

These two ride their own reviewed PR (`front-door/roadmap-*`) instead of the
SHA-pin ritual — the roadmap PR *is* the approval artifact, and later edits
land as visible follow-up PRs, never silent rewrites.
