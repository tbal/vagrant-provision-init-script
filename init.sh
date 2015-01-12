#!/usr/bin/env bash

# adjust tag manually if you create a new git tag
VERSION_TAG="v0.2.1"


###
# CONFIG
##
GIT_PACKAGE_NAME="git-core"
SCRIPT_COLLECTION_GIT_REMOTE="https://github.com/tbal/vagrant-provision-script-collection.git"
SCRIPT_COLLECTION_GIT_CLONE_ARGS="-b master --depth 1"
SCRIPT_COLLECTION_PATH="/tmp/vagrant-provision-script-collection"
SEARCH_PATHS=".:/vagrant:$SCRIPT_COLLECTION_PATH"
STRING_FILE_LIST_SEPARATOR=":"



###
# BASH OPTIONS
##
# any subsequent commands which fail (even in pipes) will cause the shell script to exit immediately
set -o errexit
set -o pipefail



###
# FUNCTION DEFINITIONS
##
cleanup() {
    echo "##### Cleaning up #####"
    rm -rf "$SCRIPT_COLLECTION_PATH"
}



###
# MAIN SCRIPT
##

echo "##### PROVISION INIT SCRIPT ($VERSION_TAG) #####"



# install git
if [ ! `which git` ]; then
    echo "##### Installing git #####"
    apt-get update > /dev/null
    apt-get install -qq "$GIT_PACKAGE_NAME"
fi



# download script collection
if [ ! -d $SCRIPT_COLLECTION_PATH ]; then
    echo "##### Downloading script collection #####"
    git clone $SCRIPT_COLLECTION_GIT_CLONE_ARGS "$SCRIPT_COLLECTION_GIT_REMOTE" "$SCRIPT_COLLECTION_PATH"
fi



# validate if all arguments are either valid local files or script collection aliases
echo "##### Validating arguments #####"

SCRIPTS=
for ARG in "$@"; do

    # argument is a local file in one of the search pathes (first match will be used)
    while read SEARCH_PATH; do

        # transform relative paths to absolute paths
        # TODO: check first character == "." and replace it with current absolute path
        [ "$SEARCH_PATH" == "." ] && SEARCH_PATH="$(dirname `readlink -f "$0"`)"

        if [ -f "$SEARCH_PATH/$ARG" ]; then
            SCRIPTS="${SCRIPTS}${STRING_FILE_LIST_SEPARATOR}${SEARCH_PATH}/$ARG"
            continue 2;
        fi

    done < <(echo "$SEARCH_PATHS" | tr $STRING_FILE_LIST_SEPARATOR "\n")


    # argument is an alias for a file of the script collection
    if [ -f "$SCRIPT_COLLECTION_PATH/$ARG.sh" ]; then
        SCRIPTS="${SCRIPTS}${STRING_FILE_LIST_SEPARATOR}${SCRIPT_COLLECTION_PATH}/$ARG.sh"
        continue;
    fi


    # neither local file, nor alias => invalid argument
    echo "ERROR: Invalid argument: $ARG" 1>&2
    echo "##### Aborting #####"
    cleanup
    exit

done



# remove first character, which is a separator used for concatenation
SCRIPTS=${SCRIPTS:1}



# execute scripts
while read SCRIPT; do

    echo "##### Executing script: $SCRIPT #####"
    /bin/chmod +x "$SCRIPT" && source "$SCRIPT"

done < <(echo "$SCRIPTS" | tr $STRING_FILE_LIST_SEPARATOR "\n")



# cleanup temporary files
cleanup
