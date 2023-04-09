# Phantombot Update Script

This Bash script updates the Phantombot software.

## Prerequisites

The bot script and the update script must be located in the home directory of the user, as recommended by Phantombot, e.g. `/home/botuser/`. The user 'botuser' must have sudo privileges to start and stop the bot. It's important that both the script and the bot are located directly in the home directory and sudo privileges are available.

## Variables

The following variables are used in the script:

- `LATEST_RELEASE_PROJECT`: The name of the project and repository on Github from which to download the latest version of Phantombot release.
- `SERVICE_NAME`: The name of the service for Phantombot.
- `REQUIRED_COMMANDS`: A list of required commands (tools) that need to be installed on the system.

## Functions

The script includes the following functions:

- `get_latest_release()`: This function uses the Github API to retrieve the latest version of Phantombot release.
- `handle_error()`: This function displays an error message and exits the script.

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

Note: This script was created by DravenTec and is version 1.0. Last updated on April 9, 2023.
