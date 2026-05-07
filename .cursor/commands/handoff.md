# foobar

## Conversation Handoff & Token Compression

Compress the current chat history into a dense handoff packet.

### Objectives

- Minimize output tokens using technical shorthand.
- Retain all state, logic decisions, and pending tasks.
- Format for machine readability by the next LLM session.

### Output Format

<handoff>
**CONTEXT**: [User Goal/System State/Tech Stack]
**STATE**: [Crucial variables/file paths/API keys discussed]
**DONE**: [Bullet list of resolved logic/steps]
**TODO**: [Next specific coding tasks]
**BLOCKED**: [Unresolved errors or missing info]
</handoff>

### Compression Rules

- Use fragments, not sentences.
- Use `->` for workflows.
- Omit conversational filler ("The user asked for...").
- Reference code blocks by name or line range only.
