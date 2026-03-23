![GitHub](https://img.shields.io/github/license/DravenTec/Phantombot-Update-Script)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/DravenTec/Phantombot-Update-Script)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/DravenTec/Phantombot-Update-Script)

# Phantombot Update Script

This Bash script automatically updates [PhantomBot](https://github.com/PhantomBot/PhantomBot)
to the latest release (or a specific version), safely backs up the existing installation,
migrates your configuration and custom files, and restarts the service.

---

## Prerequisites

### Directory Layout

The bot and the update script must both be located in the **home directory** of the
bot user, as recommended by PhantomBot — for example `/home/botuser/`. The script
assumes the following structure:

```
/home/botuser/
├── update.sh          ← this script
├── phantombot/        ← active PhantomBot installation
└── backup/            ← created automatically; stores compressed backups
```

### Permissions

The bot user (`botuser`) must have **passwordless `sudo` privileges** for `systemctl`
in order to start and stop the PhantomBot service. The script verifies this at startup
and will abort with a clear error message if the privilege is missing.

Example `/etc/sudoers` entry (adjust username and service name as needed):

```
botuser ALL=(ALL) NOPASSWD: /bin/systemctl start phantombot, /bin/systemctl stop phantombot, /bin/systemctl status phantombot
```

### Required System Tools

The following tools must be installed and available in `$PATH`. The script checks for
all of them at startup and exits immediately if any are missing.

| Tool | Purpose | Usually available |
|------|---------|-------------------|
| `curl` | GitHub API version query | Most distros |
| `wget` | Downloading the release ZIP | Most distros |
| `grep` / `sed` | Text processing | All distros |
| `unzip` | Extracting the release archive | Most distros |
| `file` | Validating the downloaded file | Most distros |
| `gzip` | Backup compression + integrity check | All distros |
| `tar` | Backup creation | All distros |
| `chmod` | Setting executable permissions | All distros |
| `systemctl` | Service management | systemd systems |
| `mkdir` / `mv` / `cp` | File operations | All distros |
| `sudo` | Privilege escalation for systemctl | Most distros |
| `flock` | Concurrent-run protection (lock file) | Most distros (`util-linux`) |
| `df` / `awk` | Disk space check | All distros |

> **Optional:** `pv` (pipe viewer) is used to display a progress bar during backup
> creation. If `pv` is not installed, the backup runs silently without a progress
> bar — all other functionality is unaffected.
>
> Install with: `sudo apt install pv` (Debian/Ubuntu) or `sudo yum install pv` (RHEL/CentOS)

---

## Usage

### Update to the latest release

```bash
./update.sh
```

The script queries the GitHub Releases API and automatically determines the latest
version of PhantomBot.

### Update to a specific version

```bash
./update.sh 3.14.0
```

The version number must follow the format `MAJOR.MINOR.PATCH` (e.g. `3.14.0`).
Invalid formats are rejected with an error before any changes are made.

---

## What the Script Does

The script performs the following steps in order:

1. **Concurrent run protection** — Acquires a lock file (`/tmp/phantombot-update.lock`).
   If another instance is already running, the script exits immediately.

2. **Dependency check** — Verifies that all required tools are available in `$PATH`.

3. **Sudo pre-check** — Confirms that passwordless `sudo systemctl` access is working
   before any destructive action is taken.

4. **Disk space check** — Ensures at least **1 GB of free disk space** is available
   in the home directory before starting (covers download + backup).

5. **Version resolution** — Uses the GitHub Releases API to determine the latest
   version, or validates the user-supplied version argument.

6. **Stop service** — If the PhantomBot service is running, it is stopped gracefully
   via `systemctl`.

7. **Download** — Downloads the release ZIP from GitHub into a secure temporary
   directory. The downloaded file is validated to be a genuine ZIP archive before
   proceeding.

8. **Backup** — Creates a compressed `.tar.gz` backup of the current installation
   in `~/backup/`, including a timestamp in the filename. The backup is verified
   with `gzip -t` before any files are touched.

9. **Extract** — Unpacks the new release. The extracted directory name is
   auto-detected from the ZIP contents (not assumed), making the script robust
   against naming changes between releases.

10. **Migrate files** — Copies the following from the old installation to the new one:
    - `config/` — Bot configuration
    - `scripts/custom/` — Custom scripts
    - `scripts/lang/custom/` — Custom language files
    - `logs/` — Log history
    - `web/common/js/socketWrapper.js` — Song request socket wrapper
    - `web/common/js/wsConfig.js` — Song request WebSocket config
    - `web/obs/requests-chart/` — Song request chart overlay

11. **Set permissions** — Applies executable permissions to `launch*.sh` and the
    bundled Java runtime.

12. **Replace installation** — Removes the old `phantombot/` directory (after the
    backup has been verified) and moves the new version into place.

13. **Start service** — Starts the PhantomBot service via `systemctl`, then waits
    3 seconds and confirms the service is still in the `active (running)` state.

14. **Cleanup** — Removes the temporary working directory. The cleanup also runs
    automatically on script interruption (Ctrl+C, SIGTERM).

---

## Backup Files

Backups are stored in `~/backup/` with the following naming scheme:

```
phantombot-DD-MM-YYYY_HHhMMmSSs.tar.gz
```

Example: `phantombot-23-03-2026_14h05m30s.tar.gz`

Each backup contains the entire `phantombot/` directory as it existed before the
update. The archive is integrity-checked before the old installation is removed.

> **Note:** Backups are not automatically rotated. Monitor available disk space
> and remove old backups manually as needed.

---

## Error Handling

- All errors print a clear `❌ Fehler:` message and exit immediately.
- Temporary files are always cleaned up, even on unexpected interruption.
- If the service fails to start or crashes after start, the script exits with an
  error and suggests checking `journalctl -u phantombot -n 50`.
- The old installation is only removed **after** the backup has been successfully
  created and verified.

---

## Notes

> **This script is provided as-is. Use it with caution.**  
> Always ensure you have a valid, tested backup before running an update.  
> Review the script before first use and adjust the configuration section at the
> top of the file (`SERVICE_NAME`, `BOT_DIR`, `BACKUP_DIR`) to match your setup.
