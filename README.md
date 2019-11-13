# flux-secret
weave flux with gpg/gopass crypt option for secrets


#why ?
gitpos, reconciler
not as blown as hashicorp vault
opensource

##localtools needed
gpg
gopass
kustomize


##application needs
flux:
--manifest-generation=true #to enable kustomize usage

target application:
.flux.yaml with keygetter  # to execute keygetter
keygetter per application #actual keygetter (provide example)

## usage
amend variables to fit your needs such as location of the flux ssh and gpg keys in :
1_flux-gpg-key.yaml-template.sh
(name and describe variables)

location of the applications keystore and application repository
patch-flux.yaml
(name and describe variables)

enable ssh key to checkout applications secret store (any git implementation)

prepare your secret getter per application
(explain simple getter)

install namespace

use gpg and ssh key-getter

apply flux

enjoy
