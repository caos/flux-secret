#!/usr/bin/env bash
# Script for initial secret and key declaration for kube-seal server
set -e
[[ `uname` = "Linux" ]] && ENCODE="base64 --wrap=0" || ENCODE="base64"

# apply via: generate-credentials-secret.sh | kubectl apply -f -

# flux gpg key secrets
FLUX_GPG_KEY=$(gopass <PATH_TO_SECRET>/gpg-private-key )
FLUX_SSH_PRIV_KEY=$(gopass <PATH_TO_SECRET>/ssh-private-key )

cat <<EOL
apiVersion: v1
data:
  flux.asc: $FLUX_GPG_KEY
kind: Secret
metadata:
  creationTimestamp: null
  name: flux-gpg-keys
  namespace: flux
---
apiVersion: v1
data:
  identity: $FLUX_SSH_PRIV_KEY
kind: Secret
metadata:
  creationTimestamp: null
  name: flux-ssh-config
  namespace: flux
EOL
