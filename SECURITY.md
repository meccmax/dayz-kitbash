# Security

Kitbash is a **local, offline, client-side tool**. It is a single HTML file plus
a few PowerShell helper scripts. This document is a plain-English summary of a
security review of the project, what the tool can and cannot do, and how you can
verify all of it yourself.

> **Type of review:** maintainer self-review (code audit), last updated
> **2026-06-29**. This is not a paid third-party audit. The whole project is
> open source and small enough to read end-to-end — please do.

## TL;DR

- **No network.** The app makes **zero external requests** — no analytics, no
  telemetry, no "phone home", no CDNs, no third-party libraries.
- **No remote code.** No `eval`, no `new Function`, no dynamically loaded scripts.
- **Runs locally.** Your data lives only in your browser (IndexedDB autosave) and
  in files you explicitly choose to save. Nothing leaves your machine.
- **The PowerShell scripts only call your own DayZ Tools** on local files. They
  download nothing and contact no network.
- **Single, unminified file.** `index.html` is human-readable — you can audit the
  entire app in one sitting.

## What the tool does (and doesn't) touch

| Capability | Details |
|---|---|
| Network access | **None.** The page only `fetch`es its own `templates/index.json` and template images from the same local folder. |
| Storage | Browser **IndexedDB** (autosave) + files you save/export via the browser's file picker. |
| Filesystem writes | Only through the browser **File System Access API** — you pick the folder each time; the page cannot write anywhere you didn't choose. Falls back to a normal download otherwise. |
| Code execution | The HTML app executes no shell commands. The **`*.ps1` scripts** you choose to run invoke your locally-installed DayZ Tools (`BankRev`, `ImageToPAA`, `AddonBuilder`, `DSUtils`). |
| Third-party deps | None. No npm packages, no bundled libraries. |
| Telemetry | None. |

## Findings & resolutions

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | Low | `run.bat` / the documented `python -m http.server` command binds to all interfaces (`0.0.0.0`), exposing the served folder to the local network while running. | **Fixed** — now binds `127.0.0.1` (loopback only). |
| 2 | Low | Loading an **untrusted project file** (`.forge.json`) or imported `config.cpp` could inject HTML through an item's stored texture field, since it was written into `innerHTML`. (Single-user, local, no secrets or server — low impact.) | **Fixed** — thumbnails are now set via a DOM property and gated to the `data:image/` scheme; all other user-supplied fields were already HTML-escaped. |
| 3 | Informational | The generated `build.ps1` embeds your project's mod/class names. Since you run a script you generated from your own input, this is self-contained, but treat generated scripts like any script: read before running, and prefer alphanumeric mod/class names. | By design / documented. |

No high or critical issues were identified.

## Threat model

The realistic risk for a tool like this is **a malicious project file**. If
someone hands you a `.forge.json` or `config.cpp`, treat it as untrusted data —
the same caution you'd apply to any file. Finding #2 above closed the one place
where such a file could have done more than populate fields. The app holds no
credentials and talks to no server, so impact is limited even in the worst case.

The PowerShell scripts run with your permissions and call Bohemia Interactive's
own DayZ Tools binaries. They are short and readable — review them before running
if you obtained them from anywhere other than this repository.

## Verify it yourself

- **Read the source.** `index.html` is one unminified file. Search it for
  `fetch`, `http`, `eval` — you'll find only the local `templates` fetches.
- **Watch the network.** Open your browser DevTools → Network tab while using the
  app. You'll see only local (`localhost`) requests.
- **Scan the files.** Run your antivirus or upload the files to a service like
  VirusTotal. (We don't bundle any executables — only text: HTML and `.ps1`/`.bat`.)
- **Read the scripts.** `build.ps1` (generated on export) and `build-templates.ps1`
  are plain PowerShell you can inspect line by line.

## Reporting a vulnerability

Found something? Please open a
[GitHub issue](https://github.com/meccmax/dayz-kitbash/issues) (for non-sensitive
reports) or use GitHub's **private vulnerability reporting** on the repository's
Security tab. I'll respond as soon as I can.
