#!/usr/bin/env bash
# Environment for the Northwind programs. Source it from any folder:
#   . ./setenv.sh
# The password is asked once per shell; it is never stored in this file.

NW_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export FGLPROFILE="$NW_HOME/fglprofile"
export FGLDBPATH="$NW_HOME/schema"
export FGLRESOURCEPATH="$NW_HOME/bin"
export FGLLDPATH="$NW_HOME/bin${FGLLDPATH:+:$FGLLDPATH}"

# Informix client (CSDK 4.50, used by the dbmifx_9 driver)
export INFORMIXDIR="${INFORMIXDIR:-/opt/informix/CSDK450}"
export INFORMIXSERVER="${INFORMIXSERVER:-informix}"
export LD_LIBRARY_PATH="$INFORMIXDIR/lib:$INFORMIXDIR/lib/esql${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

export NW_USER="${NW_USER:-genero}"
if [ -z "$NW_PASSWORD" ]; then
    read -r -s -p "Password for $NW_USER: " NW_PASSWORD
    echo
    export NW_PASSWORD
fi

echo "Northwind environment set: FGLPROFILE=$FGLPROFILE, user $NW_USER"
