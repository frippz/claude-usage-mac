# Skills

The skills in this folder, how they load, where they come from and how they
are maintained. When to use them is in
[Agent skills](../../AGENTS.md#agent-skills).

Claude Code reads them through the `.claude/skills` symlink. A reference to
the "Skill tool" means loading the named skill; to run a skill, follow its
`SKILL.md`.

The repo carries a skill only when its workflow invokes it, a skill it
carries calls it, or maintaining the repo's own skills and agent
instructions needs it. General development tools, such as prototyping,
debugging or session handoffs, are each developer's own.

All skills here are ours: the repo changes them like any other file.

## Adapted from mattpocock/skills

Taken from https://github.com/mattpocock/skills by way of the adapted copies
in livingit-intelligence, including supporting files. License: MIT, full
notice in [LICENSE-mattpocock](LICENSE-mattpocock).

- Building and reviewing: `tdd`, `code-review`, and `codebase-design`,
  which `tdd` calls. Their examples are rewritten in Swift, and
  `code-review` takes its spec from the pull request or the developer's
  request when no issue exists.
- Design questions: `grilling`, and `domain-modeling` for
  [`GLOSSARY.md`](../../GLOSSARY.md) and [`docs/adr/`](../../docs/adr/).
- Maintaining skills and agent instructions: `writing-for-agents`.

Upstream revisions last compared, through livingit-intelligence:
`b0618bc436ad893b3c5e84e55fba86586d34a404`, and
`d81f3a183412e71a5b1e84ca21bc1a35eea03a60` for `domain-modeling`.

## Written here

- `pr-description`: the pull request body template, adapted from
  livingit-intelligence's.

A personal mattpocock-skills plugin shows its own copies with a
`mattpocock-skills:` prefix; this repo's skills are the unprefixed ones.

## Maintenance

Upstream is a source of ideas, not of updates. When upstream changes a skill
we adapted, review the change and take what we want, in part or not at all,
like any other edit. Record the revision a skill was last compared against
here.
