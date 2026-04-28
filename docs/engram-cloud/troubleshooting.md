[← Back to Engram Cloud](./README.md)

# Engram Cloud Troubleshooting

Use this guide when local Engram saves work but cloud sync does not advance. The safest rule is simple: **local SQLite is the source of truth; cloud is replication**. Back up the local database before repairing anything.

---

## Quick Triage

Run these commands first:

```bash
engram version
engram cloud status
engram cloud upgrade doctor --project <project>
engram sync --cloud --status --project <project>
```

Check three things:

| Signal | Healthy value | What it means |
|---|---|---|
| `engram version` | Latest release on client and server | Client/server version skew can block old chunk sync |
| `cloud status` | configured + auth ready | CLI has a server URL and runtime token |
| `doctor` | `ready` or actionable repair | Local metadata is safe to upload |
| `last_acked_seq` | Advances after sync | Cloud accepted the pending journal |

If the dashboard shows `0` observations but local saves exist, the cloud server has not accepted the client's pending sync yet. Do not delete local data.

---

## Command Map

Use the supported commands exactly:

```bash
engram cloud config --server https://your-cloud-host
engram cloud status
engram cloud enroll <project>
engram sync --cloud --project <project>
```

`engram cloud config --status` is not the documented status command. Use `engram cloud status`.

Cloud auth token is runtime config:

```bash
export ENGRAM_CLOUD_TOKEN="your-token"
```

The local `~/.engram/cloud.json` stores the server URL. The token is intentionally read from the environment.

---

## Error: `chunk_id does not match payload content hash`

This error means the legacy chunk upload endpoint rejected a payload because the client-provided `chunk_id` did not match the server-computed canonical hash.

### Fix

Upgrade both sides to `v1.14.8` or newer:

```bash
brew update
brew upgrade engram
engram version
```

Redeploy or restart the cloud server so the server binary also runs `v1.14.8` or newer.

Then retry:

```bash
engram sync --cloud --project <project>
engram sync --cloud --status --project <project>
```

### Why this works

In `v1.14.8`, the server treats the client `chunk_id` as advisory. The server validates and canonicalizes the payload, computes its own chunk ID, stores using the server-computed ID, and returns that ID. Valid payloads no longer get blocked by client/server canonicalization drift.

---

## Error: `session payload directory is required`

This is the common legacy manual-save blocker:

```text
session payload directory is required and cannot be inferred from local state (seq=N entity=session op=upsert)
```

It means a historical `session` mutation in `sync_mutations` is missing `directory`. Newer Engram versions write this field correctly, but old journal rows may still need repair before first cloud upload.

### Safe path: helper script

Engram includes a temporary rescue helper:

```bash
tools/repair-missing-session-directory.sh <project>
```

Run it from inside the real project directory. Dry-run is the default.

```bash
cd /absolute/path/to/project
tools/repair-missing-session-directory.sh <project>
```

Review the preview. If the detected `Directory:` is correct, apply:

```bash
tools/repair-missing-session-directory.sh --apply <project>
```

Then rerun the normal flow:

```bash
engram cloud upgrade doctor --project <project>
engram cloud upgrade repair --project <project> --dry-run
engram cloud upgrade repair --project <project> --apply
engram sync --cloud --project <project>
```

### What the script changes

The script patches one legacy row in `sync_mutations` by adding a JSON field:

```json
"directory": "/absolute/path/to/project"
```

It also updates `sessions.directory` only when the matching session row exists and its directory is empty.

It never changes `last_acked_seq`, never deletes mutations, and creates a timestamped database backup before `--apply`.

### How the script finds `seq`

If you do not pass `--seq`, the script runs:

```bash
engram cloud upgrade doctor --project <project>
```

and extracts the first matching blocker:

```text
seq=N entity=session op=upsert
```

If you already know the sequence:

```bash
tools/repair-missing-session-directory.sh --seq 873 <project>
tools/repair-missing-session-directory.sh --apply --seq 873 <project>
```

### How the script chooses `directory`

Precedence:

1. Explicit directory argument.
2. `git rev-parse --show-toplevel` from the current directory.
3. `pwd`.

The directory must be absolute. Good examples:

```text
/home/user/work/sias-app
/Users/user/work/sias-app
C:/Users/user/work/sias-app
```

Bad example:

```text
sias-app
```

On Windows/Git Bash, prefer forward slashes (`C:/Users/user/work/sias-app`) to avoid JSON and SQL escaping problems.

### Explicit directory mode

Use this when you are not currently inside the project directory:

```bash
tools/repair-missing-session-directory.sh --apply --seq 873 sias-app C:/Users/user/work/sias-app
```

### Manual inspection

If you want to inspect before using the helper:

```bash
sqlite3 ~/.engram/engram.db "select seq, entity, op, entity_key, payload from sync_mutations where seq = 873;"
sqlite3 ~/.engram/engram.db "select id, project, directory from sessions where id = 'manual-save-current';"
```

Do not manually edit SQLite without a backup.

---

## Error: `transport_failed`

`transport_failed` is a wrapper around network, auth, server, or payload errors. Look for the concrete error message below it.

| Concrete error | Next step |
|---|---|
| `chunk_id does not match payload content hash` | Upgrade client and server to `v1.14.8` or newer |
| `session payload directory is required` | Run the missing session directory helper |
| `401` or `auth_required` | Check `ENGRAM_CLOUD_TOKEN` on the client and server |
| `403` or `policy_forbidden` | Check `ENGRAM_CLOUD_ALLOWED_PROJECTS` on the server |
| `server_unsupported` | Redeploy a cloud server with mutation endpoints |

---

## Verification Checklist

After any repair, verify in this order:

```bash
engram cloud status
engram cloud upgrade doctor --project <project>
engram cloud upgrade repair --project <project> --dry-run
engram cloud upgrade repair --project <project> --apply
engram sync --cloud --project <project>
engram sync --cloud --status --project <project>
```

Expected result:

- `doctor` no longer reports the same blocker.
- `sync --cloud` completes without canonicalization errors.
- `last_acked_seq` advances.
- Dashboard stats stop showing `0` once data has been accepted by cloud.

---

## What Not To Do

- Do not delete `sync_mutations` rows to make the error disappear.
- Do not edit `last_acked_seq` manually.
- Do not invent a relative `directory` like `sias-app`.
- Do not assume dashboard `0` means local data is gone.
- Do not run repair without a database backup.

---

## Next Steps

- Cloud setup: [Quickstart](./quickstart.md)
- Full command reference: [DOCS.md — Cloud CLI](../../DOCS.md#cloud-cli-opt-in)
- Autosync details: [DOCS.md — Cloud Autosync](../../DOCS.md#cloud-autosync)
