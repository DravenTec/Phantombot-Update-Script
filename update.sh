#!/bin/bash

#
# Author: DravenTec
# Version: 1.5
# Date: 2025-05-09
# Description: PhantomBot Auto-Updater
#

# --------------------- Konfiguration ---------------------
LATEST_RELEASE_PROJEKT="PhantomBot/PhantomBot"
SERVICE_NAME="phantombot"
REQUIRED_COMMANDS=("curl" "wget" "grep" "sed" "unzip" "chmod" "systemctl" "mkdir" "mv" "cp" "sudo" "pv" "tar")
BOT_DIR="$HOME/phantombot"
BACKUP_DIR="$HOME/backup"
TMPDIR=$(mktemp -d)
TIMESTAMP=$(date +"%d-%m-%Y_%Hh%Mm%Ss")
ZIPFILE=""
# ---------------------------------------------------------

handle_error() {
    echo "❌ Fehler: $1"
    echo "🧹 Entferne temporäre Dateien..."
    rm -rf "$TMPDIR"
    exit 1
}

get_latest_release() {
    local repo=$1
    local latest=$(curl -s -L -o /dev/null -w "%{url_effective}" "https://github.com/$repo/releases/latest" | grep -oP 'tag/v\K[0-9.]+')
    [[ -z "$latest" ]] && handle_error "Konnte letzte Version nicht ermitteln."
    echo "$latest"
}

echo "🔄 Starte PhantomBot Update..."

# Prüfe erforderliche Tools
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v $cmd >/dev/null 2>&1; then
        handle_error "Benötigtes Tool '$cmd' fehlt."
    fi
done

# Stoppe Bot falls aktiv
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "⏹️ Stoppe laufenden Dienst '$SERVICE_NAME'..."
    sudo systemctl stop "$SERVICE_NAME" || handle_error "Fehler beim Stoppen von $SERVICE_NAME"
fi

# Bestimme Zielversion
if [ -z "$1" ]; then
    echo "🔍 Ermittele letzte Version..."
    RELEASE=$(get_latest_release "$LATEST_RELEASE_PROJEKT")
else
    RELEASE="$1"
fi

ZIPFILE="PhantomBot-${RELEASE}-full.zip"
DOWNLOAD_URL="https://github.com/$LATEST_RELEASE_PROJEKT/releases/download/v${RELEASE}/$ZIPFILE"

# Lade ZIP
echo "⬇️ Lade $DOWNLOAD_URL"
cd "$TMPDIR" || handle_error "Fehler beim Wechseln ins Temp-Verzeichnis"
wget "$DOWNLOAD_URL" -q --show-progress || handle_error "Fehler beim Herunterladen"

# Backup erstellen
if [ -d "$BOT_DIR" ]; then
    echo "📦 Erstelle Backup der alten Version..."
    mkdir -p "$BACKUP_DIR"
    tar cf - "$BOT_DIR" | pv -s $(du -sb "$BOT_DIR" | awk '{print $1}') | gzip > "$BACKUP_DIR/phantombot-${TIMESTAMP}.tar.gz" || handle_error "Backup fehlgeschlagen"
else
    echo "⚠️ Warnung: Kein vorhandener Bot-Ordner gefunden – Backup wird übersprungen."
fi

# Entpacken
echo "📂 Entpacke neue Version..."
unzip -q "$ZIPFILE" || handle_error "Fehler beim Entpacken"
mv "PhantomBot-$RELEASE" "$BOT_DIR-new" || handle_error "Fehler beim Verschieben der entpackten Daten"

# Konfiguration übernehmen
echo "🛠️ Übernehme Konfiguration, Skripte und Logs ..."
[[ -d "$BOT_DIR/config" ]] && cp -av "$BOT_DIR/config" "$BOT_DIR-new/" || echo "⚠️ Konfigurationsordner nicht gefunden."
[[ -d "$BOT_DIR/scripts/custom" ]] && cp -av "$BOT_DIR/scripts/custom" "$BOT_DIR-new/scripts/" || echo "⚠️ Custom-Skripte fehlen."
[[ -d "$BOT_DIR/scripts/lang/custom" ]] && cp -av "$BOT_DIR/scripts/lang/custom" "$BOT_DIR-new/scripts/lang/" || echo "⚠️ Custom-Sprachen fehlen."
[[ -d "$BOT_DIR/logs" ]] && cp -av "$BOT_DIR/logs" "$BOT_DIR-new/" || echo "⚠️ Logs fehlen."

echo "🎵 Kopiere Songrequest-Dateien..."
cp -av "$BOT_DIR/web/common/js/socketWrapper.js" "$BOT_DIR-new/web/common/js/" 2>/dev/null || echo "⚠️ socketWrapper.js fehlt"
cp -av "$BOT_DIR/web/common/js/wsConfig.js" "$BOT_DIR-new/web/common/js/" 2>/dev/null || echo "⚠️ wsConfig.js fehlt"
cp -av "$BOT_DIR/web/obs/requests-chart" "$BOT_DIR-new/web/obs/" 2>/dev/null || echo "⚠️ requests-chart fehlt"

# Rechte setzen
echo "🔧 Setze Dateirechte..."
cd "$BOT_DIR-new" || handle_error "Fehler beim Zugriff auf neuen Bot-Ordner"
chmod u+x launch*.sh ./java-runtime-linux/bin/java

# Ersetze alten Bot durch neuen
echo "📁 Ersetze alten Bot durch neue Version..."
rm -rf "$BOT_DIR"
mv "$BOT_DIR-new" "$BOT_DIR" || handle_error "Fehler beim Verschieben der neuen Version"

# Starte Bot
echo "▶️ Starte Phantombot..."
sudo systemctl start "$SERVICE_NAME" || handle_error "Fehler beim Starten von Phantombot"

# Cleanup
echo "🧹 Entferne temporäre Dateien..."
rm -rf "$TMPDIR"

echo "✅ Update abgeschlossen auf Version v$RELEASE"
exit 0
