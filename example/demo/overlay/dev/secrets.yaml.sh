#!/usr/bin/env bash
# Script for initial secret and key declaration for kube-seal server
set -e
#[[ `uname` = "Linux" ]] && ENCODE="base64 --wrap=0" || ENCODE="base64"

# apply via: generate-credentials-secret.sh | kubectl apply -f -

#update remote passwords
gopass sync &> /dev/null

# flux gpg key secrets
DEMO_SECRET=$(gopass $APPLICATIONSTORE/demo | base64 )

cat <<EOL
apiVersion: v1
data:
  demosecret: $DEMO_SECRET
kind: Secret
metadata:
  creationTimestamp: null
  name: demo-secret
  namespace: dev-demo
---
EOL
