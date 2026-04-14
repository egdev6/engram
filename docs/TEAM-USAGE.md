[← Back to README](../README.md)

# Team Usage Guide

**How to use Engram collaboratively with shared project memory**

This guide covers scope conventions, language strategy, and git sync workflows for teams using Engram to share knowledge across developers and AI agents.

---

## Table of Contents

- [Scope Mental Model](#scope-mental-model)
- [Language Convention](#language-convention)
- [What to Save in Each Scope](#what-to-save-in-each-scope)
- [Git Sync for Teams](#git-sync-for-teams)
- [FAQ](#faq)

---

## Scope Mental Model

Every observation in Engram has a `scope` parameter with two possible values:

### `scope: project` (default)

**Shared team memory** — visible to all team members and their AI agents.

- Syncs via git to the team's shared sync repository
- Accessible to everyone working on the project
- Searchable by all teammates and their agents
- Use for decisions, patterns, conventions, and discoveries that benefit the whole team

### `scope: personal`

**Your personal workspace** — visible only to you and your AI agents.

- Syncs via git to your personal sync repository (separate from the team repo)
- Only accessible on your devices
- Not shared with teammates
- Use for your own learnings, preferences, notes, and explorations

### Rule of Thumb

Ask yourself: **"Should a teammate's AI agent find this?"**

- **Yes** → `scope: project`
- **No** → `scope: personal`

---

## Language Convention

### The Problem

When teams share project memory via `engram sync`, a language mismatch can fragment the knowledge base:

- Developer A (Spanish speaker) saves an observation in Spanish: `"Implementamos autenticación JWT en auth.go"`
- Developer B (English speaker) searches: `"How does authentication work?"`
- **Result**: No match. The English query doesn't match Spanish content, even though both observations are about the same code.

FTS5 (Engram's full-text search engine) is language-agnostic but **not multilingual** — it cannot match queries in one language against content in another.

### The Solution

**Establish a lingua franca for `scope: project` observations.**

For most international teams, this is **English** — the same language used for:
- Code (variable names, function names, comments)
- Commit messages
- Pull request descriptions
- Documentation

### Recommended Convention

| Scope | Language |
|-------|----------|
| `scope: project` | Team's lingua franca (usually English) |
| `scope: personal` | Any language you prefer |

**Why this works**:
- All teammates can search and find shared memories, regardless of their native language
- Personal notes remain flexible — use the language most comfortable for your own learning
- AI agents can discover cross-team knowledge without language barriers

**Example for a Spanish-speaking team at a US company**:

```bash
# Shared project memory — always English
engram mcp <<EOF
{
  "method": "tools/call",
  "params": {
    "name": "mem_save",
    "arguments": {
      "title": "JWT authentication in auth.go",
      "content": "**What**: Implemented JWT authentication...",
      "scope": "project"
    }
  }
}
EOF

# Personal notes — Spanish is fine
engram mcp <<EOF
{
  "method": "tools/call",
  "params": {
    "name": "mem_save",
    "arguments": {
      "title": "Aprendizaje sobre middleware de autenticación",
      "content": "**Qué**: Aprendí que el middleware debe validar...",
      "scope": "personal"
    }
  }
}
EOF
```

---

## What to Save in Each Scope

### `scope: project` — Shared Team Memory

Use for knowledge that helps the whole team:

#### Architecture & Design Decisions
- Why we chose PostgreSQL over MongoDB
- Authentication flow design
- API versioning strategy
- State management pattern (Redux, Zustand, Context)

#### Patterns & Conventions
- Error handling approach
- Testing patterns
- Code review checklist
- Naming conventions for endpoints

#### Discoveries & Gotchas
- "Supabase RLS requires service_role key for admin operations"
- "Next.js middleware runs on edge runtime — cannot use Node.js fs module"
- "Always use parameterized queries to prevent SQL injection"

#### Bugfixes with Cross-Team Value
- Root cause of production incident
- Non-obvious fix for a recurring bug
- Performance optimization with measurable impact

#### Configuration & Setup
- Required environment variables
- Local development setup steps
- CI/CD pipeline quirks

**Example**:

```bash
engram mcp <<EOF
{
  "method": "tools/call",
  "params": {
    "name": "mem_save",
    "arguments": {
      "title": "Next.js middleware edge runtime limitation",
      "content": "**What**: Next.js middleware runs on edge runtime and cannot use Node.js fs module\n**Why**: Discovered while trying to read config files in middleware\n**Where**: middleware.ts\n**Learned**: Use environment variables or edge-compatible APIs instead",
      "type": "discovery",
      "scope": "project"
    }
  }
}
EOF
```

---

### `scope: personal` — Your Learning Workspace

Use for your own notes, experiments, and preferences:

#### Personal Learnings
- "How useState works internally in React"
- "Mental model for async/await vs promises"
- "Shortcuts I always forget in VS Code"

#### User Preferences
- Preferred testing libraries
- Favorite debugging techniques
- Personal code snippets

#### Experiments & Explorations
- "Tried using Zod for validation — pros/cons"
- "Explored GraphQL subscriptions for real-time features"

#### Temporary Context
- Work-in-progress notes
- Ideas to explore later
- Personal TODO items

**Example**:

```bash
engram mcp <<EOF
{
  "method": "tools/call",
  "params": {
    "name": "mem_save",
    "arguments": {
      "title": "Personal preference: Zustand over Redux",
      "content": "**What**: I prefer Zustand for state management in small projects\n**Why**: Less boilerplate, simpler API, easier to test\n**Learned**: Redux is still better for large apps with complex state",
      "type": "preference",
      "scope": "personal"
    }
  }
}
EOF
```

---

## Git Sync for Teams

Engram uses git to sync observations across devices and teammates.

### Setup Overview

1. **Team sync repository** — shared repo for `scope: project` observations
2. **Personal sync repository** — your own repo for `scope: personal` observations

### Team Sync Workflow

#### Step 1: Create a Shared Sync Repository

One team member creates a git repo for shared project memory:

```bash
# On GitHub/GitLab/Bitbucket
# Create a new repo: your-org/your-project-engram-sync
# Make it private if your project is proprietary
```

#### Step 2: Each Developer Configures the Team Sync Repo

```bash
# Clone the team sync repo
git clone git@github.com:your-org/your-project-engram-sync.git ~/team-engram-sync

# Configure engram to use it for project-scoped observations
# (This would be done via engram CLI — consult `engram sync --help` for exact commands)
```

#### Step 3: Regular Sync

```bash
# Export project-scoped observations to git
engram sync export --scope project --output ~/team-engram-sync

# Commit and push
cd ~/team-engram-sync
git add .
git commit -m "sync: update project memory"
git push

# Pull teammates' updates
git pull

# Import into your local engram database
engram sync import --scope project --input ~/team-engram-sync
```

**Tip**: Automate this with a git hook or cron job.

---

### Personal Sync Workflow

For syncing your personal observations across your own devices:

```bash
# Create your personal sync repo (private)
# Example: your-username/engram-personal-sync

# Clone it
git clone git@github.com:your-username/engram-personal-sync.git ~/personal-engram-sync

# Export personal observations
engram sync export --scope personal --output ~/personal-engram-sync

# Commit and push
cd ~/personal-engram-sync
git add .
git commit -m "sync: laptop to desktop"
git push

# On another device: pull and import
cd ~/personal-engram-sync
git pull
engram sync import --scope personal --input ~/personal-engram-sync
```

---

## FAQ

### Can I mix languages in `scope: project`?

Technically yes, but **not recommended**. FTS5 cannot match queries in one language against content in another. If you mix languages, teammates will struggle to find each other's shared knowledge.

Establish a team convention (usually English) and stick to it for `scope: project`.

### What if my entire team speaks the same non-English language?

Then use that language for `scope: project`. The lingua franca principle applies — it doesn't have to be English, just **consistent** across the team.

Example: A team in Spain where everyone speaks Spanish can use Spanish for shared memory. The key is **all teammates use the same language for shared observations**.

### Do personal observations sync to the team repo?

**No**. `scope: personal` observations only sync to your **personal sync repository**, not the team's shared repo.

### Can I change an observation's scope after saving it?

Yes. Use `mem_update` to change the `scope` field:

```bash
engram mcp <<EOF
{
  "method": "tools/call",
  "params": {
    "name": "mem_update",
    "arguments": {
      "id": 123,
      "scope": "project"
    }
  }
}
EOF
```

### How do I know if an observation is `project` or `personal`?

Use `mem_search` or `mem_get_observation` — the response includes the `scope` field:

```json
{
  "id": 123,
  "title": "JWT auth implementation",
  "scope": "project",
  ...
}
```

### What happens if I accidentally save sensitive info in `scope: project`?

**Delete it immediately**:

```bash
# Hard delete (removes from database completely)
curl -X DELETE http://127.0.0.1:7437/observations/123?hard=true

# Also remove from git sync repo
cd ~/team-engram-sync
git rm <affected-file>
git commit -m "remove: sensitive observation #123"
git push
```

Then notify your team to pull and re-import.

### Can I have different `scope` conventions per project?

Yes. Each project has its own observations. You can configure scope/language conventions per-project if your team works on multiple projects with different norms.

---

## Summary

| Aspect | `scope: project` | `scope: personal` |
|--------|------------------|-------------------|
| **Visibility** | Shared with team | Only you |
| **Language** | Team lingua franca (usually English) | Any language |
| **Sync repo** | Team's shared git repo | Your personal git repo |
| **Use for** | Decisions, patterns, discoveries, team conventions | Personal learnings, preferences, experiments |

**Golden rule**: If a teammate's AI agent should find it → `scope: project` in the team's lingua franca. Otherwise → `scope: personal` in any language.

---

## Further Reading

- [DOCS.md](../DOCS.md) — Full technical reference for Engram
- [Agent Setup](AGENT-SETUP.md) — Configure Engram for your AI agent
- [Architecture](ARCHITECTURE.md) — How Engram works under the hood
