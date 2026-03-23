# Changelog

All notable changes to this project are documented in this file.  
Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.6] — 2026-03-23

Full robustness and safety overhaul based on static code review.
16 issues resolved across 3 severity levels.

### Fixed — Critical
- **[C-1]** Renamed `TMPDIR` variable to `TMP_WORKDIR` to avoid shadowing the
  system-wide `$TMPDIR` environment variable used by core utilities.
- **[C-2]** Added `trap cleanup INT TERM EXIT` so the temporary working directory
  is always removed on script exit, including Ctrl+C and SIGTERM interruptions.
  Removed redundant manual `rm -rf` cleanup calls from `handle_error`.
- **[C-3]** Added `gzip -t` integrity check on the newly created backup archive
  before any modification to the live installation is performed.
- **[C-4]** Added a safety guard that aborts the script if `BOT_DIR` is empty,
  `/`, or equal to `$HOME` before any `rm -rf` is executed.

### Fixed — Major
- **[M-1]** Replaced fragile GitHub release version detection (via HTTP redirect
  URL parsing) with the official GitHub Releases API (`/repos/.../releases/latest`).
  Also replaced `grep -oP` (PCRE-dependent) with POSIX-compatible `grep -o`.
- **[M-2]** Added strict regex validation (`^[0-9]+\.[0-9]+(\.[0-9]+)?$`) for the
  user-supplied version argument `$1` to prevent injection and misuse.
- **[M-3]** Extracted directory name is now auto-detected from the ZIP file listing
  via `unzip -Z1` instead of being hard-coded/assumed.
- **[M-4]** Added pre-extraction check: if `${BOT_DIR}-new` already exists from a
  previous failed run, it is removed before extraction begins.
- **[M-5]** After download, the file is verified to be a valid ZIP archive using
  the `file` command. An HTML error page would no longer silently fail at unzip.
- **[M-6]** After `systemctl start`, the script waits 3 seconds and then calls
  `systemctl is-active` to confirm the service is actually running — not just
  that the start command exited successfully.

### Fixed — Minor
- **[N-1]** `pv` is now an optional dependency. If not installed, the backup runs
  silently without a progress bar; all other functionality is unaffected.
- **[N-2]** Added lock file via `flock` (`/tmp/phantombot-update.lock`) to prevent
  two instances of the script from running simultaneously.
- **[N-3]** All occurrences of `"$BOT_DIR-new"` replaced with `"${BOT_DIR}-new"`
  for explicit, unambiguous variable boundary handling.
- **[N-4]** Replaced `cp -av` (verbose, floods terminal on large directories) with
  `cp -a` plus a per-item summary line via the new `copy_if_exists()` helper
  function. The helper also centralises missing-file warning logic.
- **[N-5]** Added disk space pre-check (`df -BM`) at startup. The script aborts if
  less than 1 GB is available in `$HOME` before downloading or creating a backup.
- **[N-6]** Added `sudo -n systemctl status` pre-check at startup to detect missing
  sudo privileges before the service is stopped or any files are modified.

### Added
- `copy_if_exists()` helper function for consistent, concise copy-with-status logic.
- `file` command added to `REQUIRED_COMMANDS` (used for ZIP validation).
- `flock`, `df`, `awk`, `gzip` added to `REQUIRED_COMMANDS`.
- `SERVICE_START_WAIT` and `NEEDED_MB` added as named configuration constants.
- `LOCKFILE` variable added to configuration section.

### Changed
- `REQUIRED_COMMANDS` expanded from 13 to 17 entries; `pv` removed (now optional).
- Script header updated with version, date, and full change summary.
- README.md completely rewritten to reflect new behaviour, full dependency table,
  updated prerequisites, and detailed step-by-step description.
- CHANGELOG.md created (this file).

---

## [1.5] — 2025-05-09

Initial public release.

### Features
- Checks for required system tools before proceeding.
- Stops the PhantomBot systemd service if active.
- Supports optional manual version argument (`$1`).
- Determines latest release version via GitHub redirect URL.
- Downloads the release ZIP using `wget`.
- Creates a compressed `.tar.gz` backup of the existing installation using
  `tar + pv + gzip`.
- Extracts the new release ZIP and migrates config, scripts, logs, and
  song request files.
- Sets correct executable permissions on launch scripts and Java runtime.
- Replaces the old installation directory with the new one.
- Starts the PhantomBot systemd service.
- Cleans up the temporary working directory on success.
