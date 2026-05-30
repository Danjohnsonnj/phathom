# Triage Labels

The skills speak in terms of canonical **category** and **state** roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

Every triaged issue should carry **exactly one category label and one state label**.

## Category roles

| Role in mattpocock/skills | Label in our tracker | Meaning                         |
| ------------------------- | -------------------- | ------------------------------- |
| `bug`                     | `bug`                | Something is broken             |
| `enhancement`             | `enhancement`        | New feature or improvement      |

## State roles

| Role in mattpocock/skills | Label in our tracker | Meaning                                  |
| ------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`            | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`              | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`         | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`         | `ready-for-human`    | Requires human implementation            |
| `wontfix`                 | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from these tables.

## Label hygiene

- **State labels are mutually exclusive.** Applying a new state label should **remove** the other state labels from the canonical set above.
- GitHub defaults (`question`, `documentation`, `help wanted`, etc.) are **not** triage-state substitutes. Prefer `needs-info` over `question` on triaged issues. Remove conflicting state labels when transitioning.
- **`to-prd` / `to-issues` default publish:** `ready-for-agent` plus the appropriate **category** label (`enhancement` is typical for PRDs).
