# Grocery Accounting

Project description, stack, commands, and coding conventions live in
**AGENTS.md** (tracked, shared across AI coding tools).

The Blueprint workflow contract lives in **blueprint/context/workflow.md**. This
project runs in local-only visibility, so `.claude/`, `blueprint/`, and this file
are gitignored and `AGENTS.md` carries no workflow contents. Skills that point at
`AGENTS.md` for the workflow, project configuration, or dashboard activity
contract should read `blueprint/context/workflow.md` instead.

Blueprint skills load planning context, coding standards, and the active spec
only when the current command needs them.

@AGENTS.md
@blueprint/context/workflow.md
