---
name: pr-description
description: "Use when writing a PR body."
---

Use this template for the PR body. Keep it short, skip preambles, and use the terms in `GLOSSARY.md`.

```markdown
## TLDR

<What this PR changes, in a few sentences. Name anything not verified.>

Closes #N

## How to test

1. Run `./build.sh` on this branch.
2. <One action in the menu bar app, the widget or Settings, using the UI's exact labels.>
   - <What the reviewer should see.>

<The expected visible change, or "No visible change from `main` is expected.">

<details>
<summary><b>Problem</b></summary>

<What was wrong or missing, and for whom.>

</details>

<details>
<summary><b>Solution</b></summary>

<What this PR changes and why this approach. Note deliberate behaviour changes.>

</details>

<details>
<summary><b>Testing</b></summary>

<Only what CI and the diff do not show: what was not verified and why, evidence beyond the required checks, and required checks that failed or were skipped.>

</details>

<details>
<summary><b>Rendered check</b></summary>

<Only when the rendered check ran: the snapshot PNGs looked at, in which colour schemes, and anything that looked wrong with its reason. No screenshots.>

</details>

<details>
<summary><b>Review notes</b></summary>

<Each Nit shown to the developer and left unfixed, each finding the review's verifier dropped and each finding the developer agreed to reject, as `file:line` with a one-line reason.>

</details>

## Notes

<Risks and open questions for reviewers.>

**Undo:** <Only when reverting the merge does not undo the change, such as a changed widget kind, App Group or settings key that placed widgets or stored defaults depend on: how to undo it.>

**Missed by:** <Only for a fix to a bug that reached `main`: the check or review that should have caught it.>

### Pre-existing defects fixed

<Small defects that predate this PR, fixed in files it already changes: each file and what was wrong.>

### Ideas

<Suggestions not acted on.>
```

Write How to test when a reviewer can see the change in the running app, and cover there what only a human can verify.

Write one `Closes #N` line per issue the PR completes, and drop the line when there is none. Elsewhere in the body, never put a closing keyword (close, closes, closed, fix, fixes, fixed, resolve, resolves, resolved) directly before an issue reference: GitHub closes that issue on merge. Write "#14 can be closed after merge", not "Close #14".

Drop a section that has nothing to say, and a heading left with nothing under it. Report only what was done and run.
