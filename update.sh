#!/bin/bash
#
# Author: DravenTec
# Version: 1.2
# Date: 2023-08-10
# Description: This script updates the Phantombot software.
#
# The bot script and the update script must be located in the user's home directory.
# As per Phantombot's instructions, this could be, for example, /home/botuser/.
# The user 'botuser' must be authorized to start and stop the bot using sudo.
# It's important that both the script and the bot are located directly in the
# home directory and that sudo rights are available.
#

# Variables
LATEST_RELEASE_PROJEKT="PhantomBot/PhantomBot"
SERVICE_NAME="phantombot"
REQUIRED_COMMANDS=("curl" "wget" "grep" "sed" "unzip" "chmod" "systemctl" "mkdir" "mv" "cp" "sudo" "pv" "gzip")

# Functions

#
# Code by lukechilds from https://gist.github.com/lukechilds/a83e1d7127b78fef38c2914c4ececc3c
#
get_latest_release() {
  LATEST_RELEASE=`curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                                            # Get tag line
    sed -E 's/.*v([^"]+)".*/\1/'`                                                   # Pluck JSON value
}

handle_error() {
   echo "Error: $1"
   exit 1
}

# Start Update Script

echo "PhantomBot Update Script"
sleep 1

# Check if required Commands avaiable
for command in "${REQUIRED_COMMANDS[@]}"; do
  if ! command -v $command >/dev/null 2>&1; then
    handle_error "The required tool '$command' is not installed."
  fi
done

# Check if Phantombot is running
SERVICE_STATUS=$(systemctl is-active $SERVICE_NAME)
if [[ "$SERVICE_STATUS" == "active" ]]; then
  echo "Phantombot is active, trying to stop it..."
  sudo systemctl stop $SERVICE_NAME || handle_error "Phantombot could not be stopped, update aborted,"
fi

# Check if arguments were passed when executing the script
if [ -z "$1" ]
then
   echo "No argument supplied. Getting latest release..."
   get_latest_release $LATEST_RELEASE_PROJEKT
   sleep 0.5
   echo "Updating to version v$LATEST_RELEASE"
   RELEASE=$LATEST_RELEASE
else
   echo "Updating to provided version v$1"
   RELEASE=$1
fi

# Download der neuen Bot Version
DOWNLOADLINK=https://github.com/$LATEST_RELEASE_PROJEKT/releases/download/v$RELEASE/PhantomBot-$RELEASE.zip
echo "Starting download from "$DOWNLOADLINK
sleep 0.5
if ! wget $DOWNLOADLINK -q --show-progress; then
  sudo systemctl start $SERVICE_NAME || handle_error "Error occurred during download. Stopping Update Script and starting Bot"
fi

ZIPFILE=PhantomBot-$RELEASE.zip
FOLDER=PhantomBot-$RELEASE
echo ""
echo "Download finished: "$ZIPFILE
sleep 0.5

# Moving the current bot from phantombot to phantombot-old
echo ""
echo "Moving phantombot to phantombot-old..."
mv ~/phantombot ~/phantombot-old

# Unzip the new bot and move it to phantombot
echo ""
echo "Extracting $ZIPFILE"
sleep 0.5
unzip -o $ZIPFILE | awk 'BEGIN {ORS=" "} {print "."}'
echo ""
echo "Moving $FOLDER to phantombot"
mv ~/$FOLDER ~/phantombot
sleep 0.5

# Copying the config, scripts and language files
echo ""
echo "Copying config, scripts, lang..."
cp -Rv ~/phantombot-old/config/ ~/phantombot/
cp -Rv ~/phantombot-old/scripts/custom/ ~/phantombot/scripts/
cp -Rv ~/phantombot-old/scripts/lang/custom/ ~/phantombot/scripts/lang/


### Optional Commands ###
# Example for optional commands
###
#echo ""
#echo "Copying required files for Songrequest"
#cp -v ~/phantombot-old/web/common/js/socketWrapper.js ~/phantombot/web/common/js/
#cp -v ~/phantombot-old/web/common/js/wsConfig.js ~/phantombot/web/common/js/
#cp -Rv ~/phantombot-old/web/obs/requests-chart/ ~/phantombot/web/obs/
### Optional Commands End ###


# Copy the old logs, if this is not desired comment with a #.
cp -Rv ~/phantombot-old/logs/ ~/phantombot/

# Set the correct permission for the bot to run
echo ""
echo "Setting the right privileges to launch.sh, launch-service.sh, and the included java runtime files executable"
cd ~/phantombot
chmod u+x launch-service.sh launch.sh ./java-runtime-linux/bin/java
cd ~

# Create the backup folder and move the old bot with the current date of the update.
echo ""
echo "Creating Backup folder and moving phantombot-old to backup/phantombot-"$(date +"%d-%m-%Y_%Hh%Mm%Ss")
[ ! -d "$HOME/backup" ] && mkdir -p "$HOME/backup"
cd ~/phantombot-old
tar cf - . | pv -s $(du -sb ~/phantombot-old | awk '{print $1}') | gzip > ~/backup/phantombot-$(date +"%d-%m-%Y_%Hh%Mm%Ss").tar.gz
cd ~
rm -R ~/phantombot-old
#mv ~/phantombot-old ~/backup/phantombot-$(date +"%d-%m-%Y_%Hh%Mm%Ss")
sleep 0.5

# Deleting the downloaded update file
echo ""
echo "Removing downloaded release file"
rm $ZIPFILE
sleep 0.5

# Starting the bot and ending the update script
echo ""
echo "Trying to start Phantombot..."
sudo systemctl start $SERVICE_NAME ||handle_error "Error while starting Phantombot"
echo "Phantombot was started successfully."
echo ""
echo "Update done..."
sleep 0.5
