#!/bin/bash

#
# Author: DravenTec
# Version: 1.6
# Date: 2026-03-23
# Description: PhantomBot Auto-Updater
#
# Changes in 1.6:
#   - [C-1] Renamed TMPDIR -> TMP_WORKDIR (avoids shadowing system env var)
#   - [C-2] Added trap for cleanup on INT/TERM/EXIT (no more temp dir leaks)
#   - [C-3] Added gzip -t integrity check after backup creation
#   - [C-4] Added safety guard before rm -rf on BOT_DIR
#   - [M-1] Version detection now uses GitHub Releases API (no fragile redirect)
#   - [M-2] User-supplied version argument validated via strict regex
#   - [M-3] Extracted directory name auto-detected from ZIP, not assumed
#   - [M-4] Pre-run check and removal of leftover ${BOT_DIR}-new directory
#   - [M-5] Downloaded file validated as valid ZIP before extraction
#   - [M-6] Service status verified after start (not just exit code of start cmd)
#   - [N-1] pv is now optional (graceful fallback without progress bar)
#   - [N-2] Lock file via flock prevents concurrent executions
#   - [N-3] Consistent use of "${BOT_DIR}-new" throughout
#   - [N-4] Replaced cp -av with cp -a + per-item summary line
#   - [N-5] Disk space pre-check before download and backup
#   - [N-6] sudo privileges pre-checked at startup before any destructive action
#

# --------------------- Configuration ---------------------
LATEST_RELEASE_PROJEKT="PhantomBot/PhantomBot"
SERVICE_NAME="phantombot"
REQUIRED_COMMANDS=("curl" "wget" "grep" "sed" "unzip" "file" "chmod" "systemctl" \
                   "mkdir" "mv" "cp" "sudo" "tar" "flock" "df" "awk" "gzip")
BOT_DIR="$HOME/phantombot"
BACKUP_DIR="$HOME/backup"
TMP_WORKDIR=$(mktemp -d)
TIMESTAMP=$(date +"%d-%m-%Y_%Hh%Mm%Ss")
ZIPFILE=""
LOCKFILE="/tmp/phantombot-update.lock"
NEEDED_MB=1024       # Minimum free disk space in MB required before starting
SERVICE_START_WAIT=3 # Seconds to wait after service start before verifying state
# ---------------------------------------------------------

# --------------- Cleanup trap (C-2) ----------------------
# Runs on INT, TERM, and normal EXIT — ensures temp dir is always removed.
cleanup() {
    local exit_code=$?
    if [[ -d "$TMP_WORKDIR" ]]; then
        echo "🧹 Entferne temporäre Dateien..."
        rm -rf "$TMP_WORKDIR"
    fi
    # Release flock file descriptor silently
    exec 200>&- 2>/dev/null || true
    exit "$exit_code"
}
trap cleanup INT TERM EXIT
# ---------------------------------------------------------

# Prints an error message and exits with code 1.
# The trap above ensures cleanup runs on exit.
handle_error() {
    echo ""
    echo "❌ Fehler: $1"
    exit 1
}

# --------------- Version detection (M-1) -----------------
# Uses the official GitHub Releases API instead of a fragile redirect URL.
# Falls back to handle_error if no version can be determined.
get_latest_release() {
    local repo="$1"
    local latest
    latest=$(curl -sf "https://api.github.com/repos/${repo}/releases/latest" \
        | grep -o '"tag_name": *"v[^"]*"' \
        | grep -o '[0-9][^"]*')
    [[ -z "$latest" ]] && handle_error "Konnte letzte Version nicht ermitteln. GitHub API nicht erreichbar?"
    echo "$latest"
}

# --------------- Helper: copy with status output (N-4) ---
# Usage: copy_if_exists <source> <destination> <label>
# Copies source to destination if it exists; prints a status line either way.
copy_if_exists() {
    local src="$1"
    local dst="$2"
    local label="$3"
    if [[ -e "$src" ]]; then
        cp -a "$src" "$dst" \
            && echo "  ✅ ${label} kopiert." \
            || echo "  ⚠️  Fehler beim Kopieren: ${label}"
    else
        echo "  ⚠️  Nicht gefunden, übersprungen: ${label}"
    fi
}
# ---------------------------------------------------------

echo ""
echo "🔄 Starte PhantomBot Update..."
echo ""

# --------------- Lock file (N-2) -------------------------
# Prevents two instances of this script from running simultaneously.
exec 200>"$LOCKFILE"
flock -n 200 || handle_error "Eine andere Instanz dieses Skripts läuft bereits. ($LOCKFILE)"

# --------------- Dependency check ------------------------
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        handle_error "Benötigtes Tool '$cmd' nicht gefunden. Bitte installieren."
    fi
done

# --------------- Sudo pre-check (N-6) --------------------
# Verify that passwordless sudo for systemctl is available NOW,
# before stopping the service or doing any destructive work.
sudo -n systemctl status "$SERVICE_NAME" >/dev/null 2>&1 \
    || handle_error "Fehlende sudo-Rechte für 'systemctl'. Sudoers-Konfiguration prüfen."

# --------------- Disk space pre-check (N-5) --------------
AVAILABLE_MB=$(df -BM "$HOME" | awk 'NR==2 {gsub("M","",$4); print $4}')
if (( AVAILABLE_MB < NEEDED_MB )); then
    handle_error "Nicht genug Speicherplatz. Verfügbar: ${AVAILABLE_MB} MB," \
                 " benötigt: ~${NEEDED_MB} MB"
fi
echo "💾 Speicherplatz: ${AVAILABLE_MB} MB verfügbar (benötigt: ~${NEEDED_MB} MB) — OK"

# --------------- BOT_DIR safety guard (C-4) --------------
# Prevents a misconfigured or empty BOT_DIR from causing rm -rf on critical paths.
if [[ -z "$BOT_DIR" || "$BOT_DIR" == "/" || "$BOT_DIR" == "$HOME" ]]; then
    handle_error "BOT_DIR ist unsicher gesetzt: '${BOT_DIR}'. Bitte Konfiguration prüfen."
fi

# --------------- Version argument validation (M-2) -------
if [[ -z "$1" ]]; then
    echo "🔍 Ermittele aktuelle Version von GitHub..."
    RELEASE=$(get_latest_release "$LATEST_RELEASE_PROJEKT")
else
    if [[ ! "$1" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        handle_error "Ungültiges Versionsformat: '$1'. Erwartet z.B.: 3.14.0"
    fi
    RELEASE="$1"
fi

echo "📌 Zielversion: v${RELEASE}"
echo ""

ZIPFILE="PhantomBot-${RELEASE}-full.zip"
DOWNLOAD_URL="https://github.com/${LATEST_RELEASE_PROJEKT}/releases/download/v${RELEASE}/${ZIPFILE}"

# --------------- Stop service ----------------------------
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "⏹️  Stoppe laufenden Dienst '${SERVICE_NAME}'..."
    sudo systemctl stop "$SERVICE_NAME" \
        || handle_error "Fehler beim Stoppen von '${SERVICE_NAME}'"
else
    echo "ℹ️  Dienst '${SERVICE_NAME}' ist nicht aktiv – kein Stop nötig."
fi

# --------------- Download --------------------------------
echo "⬇️  Lade: $DOWNLOAD_URL"
cd "$TMP_WORKDIR" || handle_error "Fehler beim Wechseln ins Temp-Verzeichnis: $TMP_WORKDIR"
wget "$DOWNLOAD_URL" -q --show-progress \
    || handle_error "Download fehlgeschlagen. Existiert Version v${RELEASE}? URL: ${DOWNLOAD_URL}"

# --------------- ZIP validation (M-5) --------------------
file "$ZIPFILE" | grep -q "Zip archive" \
    || handle_error "Heruntergeladene Datei ist kein gültiges ZIP-Archiv. Download möglicherweise fehlerhaft."

# --------------- Backup ----------------------------------
if [[ -d "$BOT_DIR" ]]; then
    echo "📦 Erstelle Backup der alten Version..."
    mkdir -p "$BACKUP_DIR" || handle_error "Konnte Backup-Verzeichnis nicht erstellen: $BACKUP_DIR"
    BACKUP_FILE="${BACKUP_DIR}/phantombot-${TIMESTAMP}.tar.gz"

    # N-1: Use pv if available, otherwise fall back silently
    if command -v pv >/dev/null 2>&1; then
        tar cf - "$BOT_DIR" \
            | pv -s "$(du -sb "$BOT_DIR" | awk '{print $1}')" \
            | gzip > "$BACKUP_FILE" \
            || handle_error "Backup fehlgeschlagen (mit pv)."
    else
        echo "  ℹ️  pv nicht gefunden – Backup ohne Fortschrittsanzeige."
        tar czf "$BACKUP_FILE" "$BOT_DIR" \
            || handle_error "Backup fehlgeschlagen."
    fi

    # C-3: Verify backup integrity before touching the live installation
    echo "  🔍 Prüfe Backup-Integrität..."
    gzip -t "$BACKUP_FILE" \
        || handle_error "Backup-Integritätsprüfung fehlgeschlagen. Abbruch ohne Änderungen."
    echo "  ✅ Backup verifiziert: $BACKUP_FILE"
else
    echo "⚠️  Warnung: Bot-Ordner '${BOT_DIR}' nicht gefunden – Backup wird übersprungen."
fi

# --------------- Clean up leftover -new dir (M-4) --------
if [[ -d "${BOT_DIR}-new" ]]; then
    echo "⚠️  Alter Temp-Ordner '${BOT_DIR}-new' gefunden (fehlgeschlagenes Update?) – wird entfernt..."
    rm -rf "${BOT_DIR}-new" \
        || handle_error "Konnte '${BOT_DIR}-new' nicht entfernen."
fi

# --------------- Extract ---------------------------------
echo "📂 Entpacke neue Version..."
unzip -q "$ZIPFILE" || handle_error "Fehler beim Entpacken von '${ZIPFILE}'"

# M-3: Auto-detect extracted directory name from ZIP, do not assume it
EXTRACTED_DIR=$(unzip -Z1 "$ZIPFILE" | head -1 | cut -d/ -f1)
if [[ -z "$EXTRACTED_DIR" ]]; then
    handle_error "Konnte entpacktes Verzeichnis nicht aus ZIP ermitteln."
fi
if [[ ! -d "$EXTRACTED_DIR" ]]; then
    handle_error "Erwartetes Verzeichnis '${EXTRACTED_DIR}' nach dem Entpacken nicht gefunden."
fi

mv "$EXTRACTED_DIR" "${BOT_DIR}-new" \
    || handle_error "Fehler beim Umbenennen von '${EXTRACTED_DIR}' zu '${BOT_DIR}-new'"

# --------------- Copy config, scripts, logs --------------
echo "🛠️  Übernehme Konfiguration, Skripte und Logs..."
copy_if_exists "$BOT_DIR/config"                          "${BOT_DIR}-new/"             "config/"
copy_if_exists "$BOT_DIR/scripts/custom"                  "${BOT_DIR}-new/scripts/"     "scripts/custom/"
copy_if_exists "$BOT_DIR/scripts/lang/custom"             "${BOT_DIR}-new/scripts/lang/" "scripts/lang/custom/"
copy_if_exists "$BOT_DIR/logs"                            "${BOT_DIR}-new/"             "logs/"

echo "🎵 Kopiere Songrequest-Dateien..."
copy_if_exists "$BOT_DIR/web/common/js/socketWrapper.js"  "${BOT_DIR}-new/web/common/js/" "socketWrapper.js"
copy_if_exists "$BOT_DIR/web/common/js/wsConfig.js"       "${BOT_DIR}-new/web/common/js/" "wsConfig.js"
copy_if_exists "$BOT_DIR/web/obs/requests-chart"          "${BOT_DIR}-new/web/obs/"      "requests-chart/"

# --------------- Set permissions -------------------------
echo "🔧 Setze Dateirechte..."
cd "${BOT_DIR}-new" || handle_error "Fehler beim Zugriff auf neuen Bot-Ordner '${BOT_DIR}-new'"
chmod u+x launch*.sh ./java-runtime-linux/bin/java \
    || handle_error "Fehler beim Setzen der Dateirechte."

# --------------- Replace old bot with new (C-4 guard active)
echo "📁 Ersetze alten Bot durch neue Version..."
rm -rf "$BOT_DIR"
mv "${BOT_DIR}-new" "$BOT_DIR" \
    || handle_error "Fehler beim Verschieben von '${BOT_DIR}-new' nach '${BOT_DIR}'"

# --------------- Start service ---------------------------
echo "▶️  Starte Phantombot..."
sudo systemctl start "$SERVICE_NAME" \
    || handle_error "Fehler beim Starten von Phantombot."

# M-6: Wait and verify the service actually stays up
echo "  ⏳ Warte ${SERVICE_START_WAIT}s und prüfe Dienststatus..."
sleep "$SERVICE_START_WAIT"
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    handle_error "Dienst wurde gestartet, läuft aber nicht. Logs prüfen mit: journalctl -u ${SERVICE_NAME} -n 50"
fi

echo ""
echo "✅ Update erfolgreich abgeschlossen auf Version v${RELEASE}"
echo ""
exit 0
