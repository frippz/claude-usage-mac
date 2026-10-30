---
name: code-review
description: "Review the changes since a fixed point (commit, branch, tag, or merge-base), or a merge's conflict resolution, along three axes: Standards (does the code follow this repo's documented coding standards?), Spec (does the code match what the originating issue/spec asked for?) and Bugs (is the code wrong or unsafe at runtime?). Runs the axes in parallel sub-agents, verifies the Bugs findings, tags every finding Important, Nit or Pre-existing and reports the axes side by side. Use when the developer wants to review a branch, a PR, work-in-progress changes, or asks to \"review since X\"."
---

Three-axis review of the diff between `HEAD` and a fixed point the developer supplies:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?
- **Bugs**: is the code wrong or unsafe when it runs?

The axes run as **parallel sub-agents** so they don't pollute each other's context; a fresh **verifier** sub-agent then confirms or drops each Bugs finding, and this skill aggregates the reports.

## Tags

Every finding cites a `file:line` and carries exactly one tag:

- **Important:** a confirmed bug, a spec requirement missing or implemented wrongly, or a breach of a documented standard.
- **Nit:** a baseline smell, or harmless scope creep.
- **Pre-existing:** a defect that is not [introduced](#1-pin-the-fixed-point), on any axis.

## Process

### 1. Pin the fixed point

Whatever the developer said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`. When the developer asks for a merge's conflict resolution instead, the diff command is `git show --remerge-diff <merge>` and the commit list is that merge alone.

Before going further, confirm the fixed point, or the merge, resolves (`git rev-parse <ref>`) and the diff is non-empty. A bad ref or empty diff should fail here, not inside parallel sub-agents.

When the developer gives findings an earlier review already reported, pass them to every sub-agent as already reported; each axis reports only new findings. When the diff is an open pull request's, the findings in its body's Review notes (`gh pr view <PR> --json body`) count as already reported too.

A defect counts as introduced when the diff introduced it or, when the developer gives the pull request's base, any commit since that base did.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. The spec or issue the developer gave as input.
2. Issues referenced in the commit messages or the pull request (`#123`, `Closes #45`), fetched with `gh issue view`.
3. The pull request's TLDR and Problem sections, or the request the change was built from as the developer stated it in the session.
4. If nothing is found, ask the developer where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Search the repo for every file that documents how code should be written. When `CODING_STANDARDS.md` or `CONTRIBUTING.md` exists, it must be on the list.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a Nit.** Each smell is a labelled heuristic ("possible Feature Envy"), never a breach of a standard. Like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change, or a new helper duplicates one that already exists in the repo. → reuse or extract the shared shape.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Spawn the three sub-agents in parallel

Issue the three sub-agent calls together, in the foreground, and collect the reports they return. Every prompt includes the diff command, the commit list, the [tags](#tags) pasted in full, any findings already reported, the pull request's base when given, step 1's sentence on what counts as introduced, and the brief's closing rule: "Cite a `file:line` and one tag for every finding. Under 400 words."

**Standards sub-agent prompt** adds:

- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full (the sub-agent has no other access to it).
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); and (b) any baseline smell you spot: name it and quote the hunk. A documented repo standard overrides the baseline. Skip anything tooling enforces."

**Spec sub-agent prompt** adds:

- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep), Important when it changes behaviour the spec settles or excludes; (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding; for a missing requirement, cite the `file:line` where it belongs."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

**Bugs sub-agent prompt** adds:

- The repo's list of what a defect looks like here, when it documents one, such as [What a defect looks like here](../../../CODING_STANDARDS.md#what-a-defect-looks-like-here).
- The brief: "Read the diff against the whole repo: its callers, the access rules and routes around it, and the tests it touches. Report defects: code that is wrong or unsafe when it runs, starting with the kinds the defect list names. For a bug fix, say whether the change fixes the root cause or only a symptom. Name each finding's bug class (for example 'OAuth token written to a log') and list every instance of it in the diff and the files it changes; an introduced instance is Important wherever you see it, and any other is Pre-existing."

### 5. Verify the Bugs findings

When the Bugs axis reports findings, give them and the diff command to one fresh sub-agent, without the other axes' reports or your own view. Its brief: "For each finding, read the cited code and the code paths around it, then return it as confirmed or dropped, with a one-line reason. Drop a finding the code does not bear out." Report only confirmed Bugs findings.

### 6. Aggregate

Open with the number of findings per axis and per tag. When no finding is Important, say so plainly: "Nothing Important."

Then present the three reports under `## Standards`, `## Spec` and `## Bugs` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings, because the axes are deliberately separate (see _Why separate axes_).

## Why separate axes

A change can pass one axis and fail another:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**
- Code that meets the spec and the standards but logs the OAuth token → **Bugs fail.**

Reporting them separately stops one axis from masking another.
