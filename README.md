![GitHub](https://img.shields.io/github/license/DravenTec/Phantombot-Update-Script)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/DravenTec/Phantombot-Update-Script)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/DravenTec/Phantombot-Update-Script)

# Phantombot Update Script

This Bash script updates the Phantombot software.

## Prerequisites

The bot script and the update script must be located in the home directory of the user, as recommended by Phantombot, e.g. `/home/botuser/`. The user 'botuser' must have sudo privileges to start and stop the bot. It's important that both the script and the bot are located directly in the home directory and sudo privileges are available.

## Update Script

The script performs the following steps:

1. Checks if the required commands are installed on the system.
2. Checks if the Phantombot service is active and attempts to stop it.
3. Checks for arguments passed when running the script and determines the version to be updated.
4. Downloads the latest version of Phantombot release from Github.
5. Extracts the downloaded ZIP archive and copies the files to the appropriate locations.
6. (Optionally) Copies required files for Scripts, if desired.
7. Sets the correct permissions for the executable files.
8. Creates a backup of the old bot with the current update date.

**Note: This script is provided as-is and should be used with caution.**
**Please make sure to backup your bot and data before running the update script.**
