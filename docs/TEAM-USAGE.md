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

**Shared team memory** — intended for knowledge that benefits the whole team.

- Default scope when saving observations (if not explicitly set to `personal`)
- Included in queries unless caller filters to `scope: personal` only
- When you export/sync to a shared git repo and teammates import, they receive these observations
- Use for decisions, patterns, conventions, and discoveries the team should know about

### `scope: personal`

**Your personal workspace** — a logical tag for organizing observations.

- `scope` is a filter/tag, not an access control mechanism
- Searches without a scope filter return BOTH `project` and `personal` observations
- The `scope` field appears in results so you can distinguish them
- Use for your own learnings, preferences, notes, and explorations

**Important**: When you run `engram sync`, it exports observations for the specified project (including both `scope: project` and `scope: personal`) into a new chunk. Over time, these chunks collectively contain all observations you've exported for that project. If you sync to a shared git repository and teammates import, they receive everything — regardless of scope. To keep personal notes truly private:
- Use a different project name (e.g., `myproject-personal` vs `myproject`)
- Maintain a separate `.engram/` sync directory for personal projects
- Or simply avoid using `scope: personal` for sensitive information in shared projects

### Rule of Thumb

Ask yourself: **"Should a teammate's AI agent find this?"**

- **Yes** → `scope: project`
- **No** → `scope: personal` (but remember: if you sync this project to a shared repo, teammates will still import personal-scope observations)

For truly private notes, use a separate project name (e.g., `myproject-personal`) and sync to a private git repo.

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

When saving shared project memory, use English:
- Title: "JWT authentication in auth.go"
- Content: "**What**: Implemented JWT authentication... **Why**: Session storage doesn't scale..."
- Scope: `project`

For personal notes, Spanish is fine:
- Title: "Aprendizaje sobre middleware de autenticación"
- Content: "**Qué**: Aprendí que el middleware debe validar..."
- Scope: `personal`

Note: Your AI agent (Claude, OpenCode, Codex, etc.) will call `mem_save` for you when you ask it to save observations. You typically don't need to craft MCP JSON manually.

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

**Example**: Ask your AI agent to save a discovery about Next.js middleware:

> "Save this to project memory: Next.js middleware runs on edge runtime and cannot use Node.js fs module. I discovered this while trying to read config files in middleware. Use environment variables or edge-compatible APIs instead."

The agent will create an observation with:
- Title: "Next.js middleware edge runtime limitation"
- Type: `discovery`
- Scope: `project`
- Content formatted with What/Why/Where/Learned structure

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

**Example**: Ask your AI agent to save a personal preference:

> "Save to my personal notes: I prefer Zustand over Redux for small projects because it has less boilerplate and a simpler API. Redux is still better for large apps with complex state."

The agent will create an observation with scope `personal` — visible in your local database (and included if you later sync/export this project to a shared repo).

---

## Git Sync for Teams

Engram uses git to sync observations across devices and teammates.

### How Sync Works

`engram sync` exports observations to a `.engram/` directory structure:

```
.engram/
├── manifest.json             ← Index of all chunks (small, mergeable)
└── chunks/
    ├── a3f8c1d2.jsonl.gz    ← Chunk 1 (gzipped JSON)
    ├── b7d2e4f1.jsonl.gz    ← Chunk 2
    └── ...
```

**Key points**:
- Each `engram sync` creates a **new chunk** (never modifies old ones), minimizing conflicts
- `manifest.json` is updated on each export and can still conflict during concurrent edits; pulling before exporting reduces manifest merge conflicts
- Chunk files have `.jsonl.gz` extension but currently contain **a single gzipped JSON object** (despite the `.jsonl.gz` naming)
- Imported chunk IDs are tracked in the **local SQLite database** (table `sync_chunks`), not in the `.engram/` directory
- Sync is **project-based**, not scope-based
- By default, syncs observations for the current project (detected from git repo)
- Use `--all` to export ALL projects
- Use `--project <name>` to specify a different project

### Team Sync Workflow

#### Step 1: Create a Shared Sync Repository

One team member creates a git repo for shared project memory:

```bash
# On GitHub/GitLab/Bitbucket
# Create a new repo: your-org/your-project-engram-sync
# Make it private if your project is proprietary
```

#### Step 2: Clone and Initialize

Each team member clones the sync repo:

```bash
# Clone the team sync repo to your local machine
git clone git@github.com:your-org/your-project-engram-sync.git ~/team-engram-sync
cd ~/team-engram-sync

# Initial sync structure will be created automatically on first export
```

#### Step 3: Regular Sync Workflow

```bash
# Navigate to the sync repository
cd ~/team-engram-sync

# Pull latest changes from teammates
git pull

# Import new chunks into your local database
engram sync --import

# Work on the project, create observations with your AI agent
# ...

# Export new observations to the sync repo
# (Run this from the sync repo directory)
engram sync --project myproject

# Or export ALL projects:
# engram sync --all

# Commit and push the new chunk
git add .engram/
git commit -m "sync: add new observations"
git push
```

**Tip**: The sync repo should contain ONLY the `.engram/` directory. When running `engram sync` from inside a dedicated sync repo, always pass `--project <actual-project>` (or use `--all`) so Engram does not auto-detect the sync repo name as the project. If you want to automate this, use a shell alias or wrapper script that always runs `engram sync --project <actual-project>`. You can also automate this with a git hook.

---

### Syncing Personal Notes Separately

If you want to keep personal notes on multiple devices **without sharing them with the team**, use a separate project name:

```bash
# Use a different project name for personal work
# Example: when saving personal observations, use project "myname-notes"

# Create a separate sync repo (private)
git clone git@github.com:your-username/engram-personal.git ~/engram-personal
cd ~/engram-personal

# Sync only your personal project
engram sync --project myname-notes

# This keeps your personal notes separate from the team's shared project
```

**Important**: `engram sync` exports ALL observations for a project, including both `scope: project` and `scope: personal`. The `scope` field is a logical filter for queries, not an access control mechanism. If you mix personal and team observations in the same project and sync it, teammates will import everything.

---

## FAQ

### Can I mix languages in `scope: project`?

Technically yes, but **not recommended**. FTS5 cannot match queries in one language against content in another. If you mix languages, teammates will struggle to find each other's shared knowledge.

Establish a team convention (usually English) and stick to it for `scope: project`.

### What if my entire team speaks the same non-English language?

Then use that language for `scope: project`. The lingua franca principle applies — it doesn't have to be English, just **consistent** across the team.

Example: A team in Spain where everyone speaks Spanish can use Spanish for shared memory. The key is **all teammates use the same language for shared observations**.

### Do personal observations sync to the team repo?

**It depends**. `engram sync` exports ALL observations for a project, regardless of scope. If you have both `scope: personal` and `scope: project` observations in the same project and run `engram sync`, both will be exported to the sync repo.

To keep personal notes separate:
- Use a different project name for personal work (e.g., `myname-notes`)
- Sync that project to a separate, private git repository
- Never sync personal projects to the team's shared repo

The `scope` field is a logical filter for queries (e.g., your AI agent can filter searches by passing `scope: "personal"` as a parameter), not an access control mechanism for git sync.

### Can I change an observation's scope after saving it?

Yes. Ask your AI agent to update the observation's scope:

> "Update observation #123 to scope: project"

Or use the HTTP API directly:

```bash
curl -X PATCH http://127.0.0.1:7437/observations/123 \
  -H 'Content-Type: application/json' \
  -d '{"scope":"project"}'
```

### How do I know if an observation is `project` or `personal`?

Ask your AI agent to search or retrieve the observation. The response will include the `scope` field. 

Or query the HTTP API directly:

```bash
curl http://127.0.0.1:7437/observations/123
```

Response includes:
```json
{
  "id": 123,
  "title": "JWT auth implementation",
  "scope": "project",
  ...
}
```

### What happens if I accidentally save sensitive info in `scope: project`?

**Delete it immediately and notify your team**:

1. **Hard delete from local database**:
```bash
curl -X DELETE "http://127.0.0.1:7437/observations/123?hard=true"
```

2. **Remove from git sync repo**:

The observation is embedded in a compressed chunk file (`.engram/chunks/*.jsonl.gz`). Removing a single observation from a chunk is complex:

**Option A: Rewrite git history** (if the leak was recent):
```bash
cd ~/team-engram-sync
# Identify which chunk contains the observation (check manifest.json timestamps)
# Remove the chunk file using git-filter-repo (recommended) or BFG Repo-Cleaner

# Using git-filter-repo:
git filter-repo --path .engram/chunks/<chunk-id>.jsonl.gz --invert-paths

# Or using BFG:
# bfg --delete-files <chunk-id>.jsonl.gz

git push --force
```

**Important**: After rewriting history, all collaborators must either:
- Re-clone the repository, OR
- Run `git fetch --all && git reset --hard origin/main` (loses local changes)

History rewriting is disruptive for teams. Use Option B if multiple people have already pulled the leaked chunk.

**Option B: Accept the exposure** and rotate credentials:
- The chunk is already distributed to teammates who ran `git pull`
- Assume the secret is compromised
- Rotate the leaked credential/token immediately
- Delete the observation locally to prevent future exports

3. **Notify teammates** to:
   - Pull the updated repo (if you rewrote history)
   - Delete the observation from their local databases
   - Update any affected credentials

**Prevention**: Avoid saving API keys, tokens, or passwords in observations. Use environment variables or secret management tools instead.

### Can I have different `scope` conventions per project?

Yes. Each project has its own observations. You can configure scope/language conventions per-project if your team works on multiple projects with different norms.

---

## Summary

| Aspect | `scope: project` | `scope: personal` |
|--------|------------------|-------------------|
| **Visibility** | Included in all queries (default) | Included in all queries (default) |
| **Filtering** | Queries can filter to project-only | Queries can filter to personal-only |
| **Language** | Team lingua franca (usually English) | Any language |
| **Sync behavior** | Exported with project to git | Exported with project to git (same as project scope) |
| **Best practice** | Use for team knowledge | Use in separate project, sync to private repo |
| **Use for** | Decisions, patterns, discoveries, team conventions | Personal learnings, preferences, experiments |

**Golden rule**: If a teammate's AI agent should find it → `scope: project` in the team's lingua franca. For truly private notes → use a separate project name and sync to a private repo.

---

## Further Reading

- [DOCS.md](../DOCS.md) — Full technical reference for Engram
- [Agent Setup](AGENT-SETUP.md) — Configure Engram for your AI agent
- [Architecture](ARCHITECTURE.md) — How Engram works under the hood
