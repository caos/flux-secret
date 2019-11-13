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

 * An Kubernetes application shall get its secrets automatically. The secrets shall not be in cleartext ANYwhere. 
 * The interaction with secrets shall be as simple as possible for the administrator AND for the application.
 * Secrets do have one or multiple owners that share responsibilities over the sensible data
 * each interaction with secrets is documented and trackable

## the solution

keep things simple !

we use flux as it is, with the addition of [manifests](https://docs.fluxcd.io/en/stable/references/fluxyaml-config-files.html).

 * Manifest generators expect a valid yaml out of any command, collects them and once the yamls are valid, pushes them to your k8s cluster.
 * In addition we wrote a little helper that initializes gpg and a gopass store to get gopass up and running with the right permissions.
 * to keep things more managable, we use  [kustomize](https://github.com/kubernetes-sigs/kustomize)  to combine the "stock" flux implementation with our changes.

## requirements

 1. local requirements (what devops people need)
	 * [gopass](https://github.com/gopasspw/gopass)
	 * [fluxctl](https://docs.fluxcd.io/en/stable/references/fluxctl.html)
	 * [kustomize](https://github.com/kubernetes-sigs/kustomize)
	 * one ore more git repositories to store keys/secrets (depending on your needs)

## preparation of flux-secret

 1. create a gopass remote store in git and store
	 * flux ssh-keys (needed to checkout applications repository)
	 * flux gpg-keys (needed to authenticate against gopass on the application repository)
	 * it should then look something like this:
```
gopass show $YOURSTORE/technical/k8s/$CLUSTERNAME/flux/

$YOURSTORE/technical/k8s/$CLUSTERNAME/flux/
├── gpg-private-key
├── gpg-public-key
├── ssh-private-key
└── ssh-public-key
```

  2. create another gopass remote store for your application(s) and permission the above gpg key
     * it should then look something like this:
```
gopass show $APPLICATIONSTORE/application/$APPLICATIONNAME/
$APPLICATIONSTORE/application/$APPLICATIONNAME/
├── prod
│   └── applicationsecrets
└── test
    └── applicationsecrets


gopass recipients list $APPLICATIONSTORE
├── $APPLICATIONSTORE (/Users/itsme/.password-store-$APPLICATIONSTORE)
    ├── 0x06C57F5CC61FF0C1 - devops person1 <devops1@yourdomain.com>
    ├── 0x06C46F5BB61FF0C1 - devops person2 <devops2@yourdomain.com>
    └── 0xF2169268EE2D3BB9 - flux-operator <yourfluxemail@yourdomain.com>

```
use the ssh-key to permission a DEPLOYKEY or user to checkout the repository (depends on your git implementation)


 3. let flux know which gpg and ssh key to use and replace variables in script to your individual needs:
     `k8s/overlay/1_flux-gpg-key.yaml-template.sh`
     
     
```
# flux gpg key secrets
FLUX_GPG_KEY=$(gopass $YOURSTORE/technical/k8s/$CLUSTERNAME/flux//gpg-private-key )
FLUX_SSH_PRIV_KEY=$(gopass $YOURSTORE/technical/k8s/$CLUSTERNAME/flux//ssh-private-key )
```

this script will create a secret for flux with it's own keys and we will execute it later. 

 4. Now that we do have (flux's) keys and permissioned a key to checkout and decrypt a secrets repository,
    we need to tell flux where it will find the application secrets and the manifests  

    Note: The application repository can be a complete different repository as it does not have secrets in it! It is the GitOps Repository that holds the declarative description of your application

e.g.:

```
   containers:
      - name: flux
        # we want to initialize gpg and gopass when the container started
        lifecycle:
          postStart:
            exec:
			  # tell flux which gopass repository you want to initialize
              command: ["/bin/bash", "-c", "/home/flux/initialize_gopass.sh git@github.com:<YOURORGANIZATION>/<YOURSECRETSTORE> <YOURSECRETSTORE>"]
        ....
        args:
		#tell flux where to find its application manifests:
        - --git-url=git@github.com:<YOURORGANIZATION>/<YOURAPPLICATIONOREPOSITORY>
        - --git-path=<PATHTOAPPLICATIONS>
        - --git-user=<YOURGHUSER>
        - --git-email=<YOURGHEMAIL>
        - --manifest-generation=true
```


 5. prepare the application
   * write a .flux.yaml file that will be read by flux to install the application
   e.g.

```
version: 1
commandUpdated:
  generators:
    - command: kustomize build .  #this will use kustomize to resolve the applications dependencies
    - command: ./secrets.yaml.sh  #this will execute the secrets script and return a yaml with the secret
```
   * point the secrets.yaml.sh to the secret(s) you want to attach with the application
   e.g.

```
#update remote passwords
gopass sync &> /dev/null   #update remote store

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
```

## install of flux
once we prepared the secrets, permissions and our demo application it's time to install flux.

```
cd cd k8s/overlay
#install namespace
kubectl apply -f 0_namespace.yaml

#install the secrets for flux in the above namespace
./1_flux-gpg-key.yaml-template.sh   # this will answer the devops person for its individual gpg passphrase

#apply flux
kustomize build | kubectl apply -f -

```

after flux's start, it will download and configure gopass with the delivered gpg and ssh keys.
afterwards it will scan the 

```
--git-path=<PATHTOAPPLICATIONS>
```

parameter to install your application with the strategy provided in .flux.yaml

give it some time (2-5mins ish), it needs to build up its memcache and perform a couple of tasks.
you might want to check it's logs.

meaning: it will perform both actions:

```
   - command: kustomize build .  #this will use kustomize to resolve the applications dependencies
   - command: ./secrets.yaml.sh  #this will execute the secrets script and return a yaml with the secret
```
and if both commands deliver a valid yaml, it will automatically install the whole application with secrets.

let's doublecheck:

```
#secrets:
kubectl get secrets -n dev-demo
NAME                  TYPE                                  DATA   AGE
demo-secret           Opaque                                1      some seconds

#deployment and service:
kubectl get all -n dev-demo
NAME                        READY   STATUS    RESTARTS   AGE
pod/demo-7cb6bfdd4d-8v9pk   1/1     Running   0          some seconds

NAME                   TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)          AGE
service/demo-service   ClusterIP   10.0.5.179   <none>        80/TCP,443/TCP   some seconds

NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/demo   1/1     1            1           some seconds

NAME                              DESIRED   CURRENT   READY   AGE
replicaset.apps/demo-7cb6bfdd4d   1         1         1       some seconds

```


## conclusion

It might seem a bit complicated at first,.. but we are talking about gitpos, gpg, ssh and automated password decryption
There are some moving targets, but that`s the way gpg works.

As the secrets (getter) script get's executed everytime a change has been made in the applications repository, all you have to do is to amend the gopass entry, the secrets will be delivered on every deployment without any user interaction.

