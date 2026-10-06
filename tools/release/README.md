# Release pipeline

CI (`.github/workflows/godot.yml`) exports Holdfast for the web (single-threaded,
so it needs no special server headers) and Windows on every push to `main`, and
keeps them as downloadable artifacts. It uses **no secrets** today.

## What M4 (Steam upload) will need

Added only when M4 starts, as GitHub Actions secrets set by the Setup Desk. Never
in the repository, never pasted in chat.

| Secret | What it is | Who creates it |
|---|---|---|
| `STEAM_USERNAME` | A dedicated Steam build account (not the owner's), with only "Edit app metadata" and "Publish app changes to Steam" on Holdfast's app | Owner, via the Setup Desk |
| `STEAM_CONFIG_VDF` | steamcmd's `config.vdf` after one Steam Guard login of that account, base64-encoded, so CI can log in without a code | Setup Desk, once |
| Holdfast app and depot IDs | Not secret; go in the upload script once the Steamworks app exists | Setup Desk |

The upload job will push to a **beta branch** only. Setting a build live stays a
manual step in Steamworks and needs the owner's go-ahead. Signing for Windows and
macOS is out of scope until a decision says otherwise (see HF-M1-06).
