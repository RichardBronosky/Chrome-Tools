#!/bin/bash
set -o nounset
set -o errexit

TMP_DIR=/tmp/chromiumdownload
APP_DIR=/Applications
BASE_URL=http://v11.lscache4.c.bigcache.googleapis.com/chromium-browser-continuous/Mac
LATEST_VER=$(curl -sS http://commondatastorage.googleapis.com/chromium-browser-continuous/Mac/LAST_CHANGE)
# Either of these could change at any moment.
FILE_NAME=chrome-mac.zip
APP_NAME=Chromium.app

# check current revision number
CURRENT_VER=$(/usr/libexec/PlistBuddy -c "print SVNRevision" $APP_DIR/$APP_NAME/Contents/Info.plist) || CURRENT_VER=0
CHANGELOG="http://build.chromium.org/buildbot/perf/dashboard/ui/changelog.html?url=/trunk/src&range=$LATEST_VER:$CURRENT_VER&mode=html"
echo $CHANGELOG | pbcopy
# bail if there is not a newer version
echo "Latest is $LATEST_VER. You have $CURRENT_VER."
echo "Changelog (in clipboard): $CHANGELOG"
[[ $LATEST_VER > $CURRENT_VER ]] && echo "Downloading." || { echo "Quitting."; exit 1; }

mkdir -p $TMP_DIR && cd $TMP_DIR
curl -O $BASE_URL/$LATEST_VER/$FILE_NAME
# I really wish they would create tar/gz files instead of zip files so that I could pipe curl to tar and not write the archive to disk.
unzip -qq $FILE_NAME
# Because this script rename the existing app with its version and moves it to the temp dir, it is safe to run while the app open.`
APP_NAME=$(basename ${FILE_NAME%%.zip}/*.app)
[[ -d $APP_DIR/$APP_NAME ]] && mv $APP_DIR/$APP_NAME ./${APP_NAME%%.app}.$CURRENT_VER.app
mv ${FILE_NAME%%.zip}/$APP_NAME $APP_DIR/$APP_NAME


