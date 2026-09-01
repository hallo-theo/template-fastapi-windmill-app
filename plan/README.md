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
