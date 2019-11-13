# flux-secret
### weave flux with gpg/gopass crypt option for secrets in kubernetes

## purpose/usecase

We @ [caos](https://caos.ch) like opensource and we like the [GitOps](https://www.weave.works/technologies/gitops/) pattern, introduced by weaveworks.

[Flux](https://github.com/fluxcd/flux) by weaveworks is a fantastic tool to install and maintain software on kubernetes clusters automatically.

Once you start managing more than 1 cluster and more than just a few applications you might find yourself in the need to manage your secrets and/or sensible data in an easy way without human interaction.

There are plenty of solutions out there to manage secure data, one of the famous might be [Vault](https://www.vaultproject.io/) by hashicorp or [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) by bitnami. Both do the job very well and professional, but sometimes you don't wan't another big legacy product with your usecase. 

This is were [gopass](https://github.com/gopasspw/gopass) comes into play. This is a cool opensource gobased rewrite of good old unix pass, combined with git to store secrets remote. We already use it for our own secrets quite a while.

so we thought,.. why not combine 2 excellent tools in an easy manner? 

## the goal

simple:

 - An Kubernetes application shall get its secrets automatically. The secrets shall not be in cleartext ANYwhere. 
 - The interaction of secrets shall be as simple as possible for the Administrator AND for the application.
 - Secrets do have one or multiple owners that share responsibilities

## the solution

keep things simple !

we use flux as it is with the addition of manifests.

 - Manifest generators expect a valid yaml out of any command, collects them and once the yamls are valid, pushes them to your k8s cluster.
 - In addition we wrote a little helper that initializes gpg and a gopass store to get gopass up and running with the right permissions.
 - to keep things more managable, we use  [kustomize](https://github.com/kubernetes-sigs/kustomize)  to combine the "stock" flux implementation with our changes.

## requirements

 1. local requirements (what devops people need)
	 * [gopass](https://github.com/gopasspw/gopass)
	 * [fluxctl](https://docs.fluxcd.io/en/stable/references/fluxctl.html)
	 * [kustomize](https://github.com/kubernetes-sigs/kustomize)
	 * one ore more git repositories to store keys/secrets (depending on your needs)

## installation and usage of flux-secret

 1. create a gopass remote store in git and store
	 * flux ssh-keys (needed to checkout applications repository)
	 * flux gpg-keys (needed to authenticate against gopass on the application repository [see below])
	 * create a repository for your applications secrets and permission the above gpg key  via gopass to access the secrets

 2. replace variables in script
     `k8s/overlay/1_flux-gpg-key.yaml-template.sh`
     
      and let it know where it can find flux's sshkey and gpg key:
      
      ```# flux gpg key secrets
       FLUX_GPG_KEY=$(gopass <PATH_TO_SECRET>/gpg-private-key )
	   FLUX_SSH_PRIV_KEY=$(gopass <PATH_TO_SECRET>/ssh-private-key )```










# placeholder for initial ideas below (will be deleted)

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
