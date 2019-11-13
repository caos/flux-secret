#!/usr/bin/env bash
#example: initialize_gopass.sh git@github.com:<YOURORGANIZATION>/<YOURSECRETSTORE> <YOURSECRETSTORE>

SECRET_REPOSITORY=$1
SECRET_STORE=$2
LOGFILE=gopass.log

GOPASS_VERSION="1.8.6"


# Script for initial secret and key declaration for gpg/gopass
set -e

function fetch_gopass {
#download gopass executable 
wget https://github.com/gopasspw/gopass/releases/download/v$GOPASS_VERSION/gopass-$GOPASS_VERSION-linux-amd64.tar.gz 
tar xf ./gopass-$GOPASS_VERSION-linux-amd64.tar.gz 
mv ./gopass-$GOPASS_VERSION-linux-amd64/gopass /usr/local/bin
rm -rf ./gopass-$GOPASS_VERSION-linux-amd64*
}



function import_and_trust_gpg-key {
# import gpg keys to keystore
gpg --import /root/gpg-import/flux.asc &>> $LOGFILE
# trust imported keys
for fpr in $(gpg --list-keys --with-colons  | awk -F: '/fpr:/ {print $10}' | sort -u &>> $LOGFILE); do  echo -e "5\ny\n" |  gpg --command-fd 0 --expert --edit-key $fpr trust &>> $LOGFILE ; done
}

function  initialize_gopass_store {
#init gopass witht the technical gpg user
# e.g.: gopass  --yes init --crypto gpg-id <YOURID> --rcs gitcli
gopass  --yes init --crypto gpg-id $(gpg --list-keys --with-colons  | awk -F: '/pub:/ {print $5}') --rcs gitcli &>> $LOGFILE
}

function clone_remote_gopass_store {
# checkout the customers passtore 
gopass --yes clone $SECRET_REPOSITORY $SECRET_STORE --sync gitcli &>> $LOGFILE
}

fetch_gopass
import_and_trust_gpg-key
initialize_gopass_store
clone_remote_gopass_store
