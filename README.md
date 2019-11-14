# Flux-secret

Weave flux addon to use gpg/gopass for secrets in kubernetes.

## Purpose / Usecase

We @[caos](https://caos.ch) love opensource and realy like the [GitOps](https://www.weave.works/technologies/gitops/) pattern, introduced by [weaveworks](https://www.weave.works/).

[Flux](https://github.com/fluxcd/flux) by weaveworks is a fantastic tool to reconcile software on kubernetes clusters automatically.

Once you start managing more than one cluster with more than just a handful applications you might find yourself in the need to manage your secrets and/or sensitive data in an easy way without any human interaction.

There are plenty of solutions out there to manage secure data, one of the most famous might be [Vault](https://www.vaultproject.io/) by hashicorp or [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) by bitnami. Both do their job very well, but sometimes you don't wan't to use another product / service with your use case.

This is were [gopass](https://github.com/gopasspw/gopass) comes into play. Gopass is an opensource project written in Go which rewrites the good old password manager "pass", combined with git to store the managed secrets remotely. We are already using it for our own secrets for quite a while and are super happy with its functionality.

So, we thought,.. why not combine 2 excellent tools in an easy manner?

## The goal(s)

* An Kubernetes application shall get its secrets automatically. The secrets shall not be in cleartext ANYwhere
* The interaction with secrets shall be as simple as possible for the administrator/developer AND for the application
* Secrets shall have one or multiple owners that share responsibilities over the sensitive data
* Each interaction with secrets shall be documented and trackable (auditable)

## The NO goal(s)

* The wheel shall not be reinvented
* Everyone shall create their own crypto

## The solution

Keep things simple !

We use flux as it is, with the addition of [manifests](https://docs.fluxcd.io/en/stable/references/fluxyaml-config-files.html).

* Manifest generators expect a valid yaml out of any command, collects them and once every yaml is validated, pushes them to your kubernetes cluster(s)
* In addition to the generators we wrote a little helper that initializes gpg and a gopass store to get gopass up and running with the right permissions
* To keep things more managable, we use  [kustomize](https://github.com/kubernetes-sigs/kustomize)  to combine the "stock" flux implementation with our changes

![flux-secrets-workflow](images/flux-secrets-workflow.png?raw=true "flux-secrets-workflow")


## Requirements

1. Local requirements (what devops people need)

* [gopass](https://github.com/gopasspw/gopass)
* [fluxctl](https://docs.fluxcd.io/en/stable/references/fluxctl.html)
* [kustomize](https://github.com/kubernetes-sigs/kustomize)
* One ore more git repositorie(s) to store keys/secrets (depending on your needs)

## Preparation of flux-secret

1. Create a gopass remote store in git

* Flux ssh-keys (needed to checkout repository)
* Flux gpg-keys (needed to decrypt the secrets)

It should then look something like this:

```bash
gopass show $YOURSTORE/technical/k8s/$CLUSTERNAME/flux/

$YOURSTORE/technical/k8s/$CLUSTERNAME/flux/
├── gpg-private-key
├── gpg-public-key
├── ssh-private-key
└── ssh-public-key
```

2. Create another gopass remote store for your application(s) and add the above gpg key

* It should then look something like this:

```bash
gopass show $APPLICATIONSTORE/application/$APPLICATIONNAME/
$APPLICATIONSTORE/application/$APPLICATIONNAME/
├── prod
│   └── applicationsecrets
└── test
    └── applicationsecrets
```

```bash
gopass recipients list $APPLICATIONSTORE
├── $APPLICATIONSTORE (/Users/itsme/.password-store-$APPLICATIONSTORE)
    ├── 0x06C57F5CC61FF0C1 - devops person1 <devops1@yourdomain.com>
    ├── 0x06C46F5BB61FF0C1 - devops person2 <devops2@yourdomain.com>
    └── 0xF2169268EE2D3BB9 - flux-operator <yourfluxemail@yourdomain.com>
```

Use the ssh-key to grant access to a DEPLOYKEY or user to checkout the repository (depends on your git provider)

3. Let Flux know which gpg and ssh key to use and adjust variables in the script to your individual needs:
     `k8s/overlay/1_flux-gpg-key.yaml-template.sh`

## Flux gpg key secrets

```bash
FLUX_GPG_KEY=$(gopass $YOURSTORE/technical/k8s/$CLUSTERNAME/flux//gpg-private-key )
FLUX_SSH_PRIV_KEY=$(gopass $YOURSTORE/technical/k8s/$CLUSTERNAME/flux//ssh-private-key )
```

This script will create a secret for flux with it's own keys and we will execute it later.

4. Now that we do have (flux's) keys and permissioned a key to checkout and decrypt a secrets repository,
  we need to tell flux where it will find the application secrets and the manifests  

  Note: The application repository can be a complete different repository as it does not have secrets in it! It is the GitOps Repository that holds the declarative description of your application

e.g.:

```yaml
   containers:
      - name: flux
        # we want to initialize gpg and gopass when the container started
        lifecycle:
          postStart:
            exec:
            # tell flux which gopass repository you want to initialize
              command: ["/bin/bash", "-c", "/home/flux/initialize_gopass.sh git@github.com:<YOURORGANIZATION>/<YOURSECRETSTORE> <YOURSECRETSTORE>"]
        args:
        #tell flux where to find its application manifests:
        - --git-url=git@github.com:<YOURORGANIZATION>/<YOURAPPLICATIONOREPOSITORY>
        - --git-path=<PATHTOAPPLICATIONS>
        - --git-user=<YOURGHUSER>
        - --git-email=<YOURGHEMAIL>
        - --manifest-generation=true
```

5. prepare the application

* Write a .flux.yaml file that will be read by flux to install the application
   e.g.

```yaml
version: 1
commandUpdated:
  generators:
    - command: kustomize build .  #this will use kustomize to resolve the applications dependencies
    - command: ./secrets.yaml.sh  #this will execute the secrets script and return a yaml with the secret
```

* Point the secrets.yaml.sh to the secret(s) you want to attach with the application
   e.g.

```bash
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

## Install flux

Once we prepared the secrets, permissions and our demo application it's time to install flux.

```bash
cd cd k8s/overlay
#install namespace
kubectl apply -f 0_namespace.yaml

#install the secrets for flux in the above namespace
./1_flux-gpg-key.yaml-template.sh   # this will answer the devops person for its individual gpg passphrase

#apply flux
kustomize build | kubectl apply -f -
```

After flux's start, it will download and configure gopass with the delivered gpg and ssh keys.
afterwards it will scan the `--git-path=<PATHTOAPPLICATIONS>` parameter to install your application with the strategy provided in .flux.yaml.

Give it some time (2-5mins ish), it needs to build up its memcache and perform a couple of other tasks.
You might want to check it's logs.

Meaning: it will perform these two actions:

```bash
   - command: kustomize build .  #this will use kustomize to resolve the applications dependencies
   - command: ./secrets.yaml.sh  #this will execute the secrets script and return a yaml with the secret
```

And if both commands deliver a valid yaml, it will automatically install the whole application with secrets.

Let's doublecheck:

```bash
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

## Conclusion

It might seem a bit complicated at first,.. but we are talking about gitpos, gpg, ssh and automated password decryption
There are some moving targets, but that`s the way gpg works.

As the secrets (getter) script get's executed everytime a change has been made in the applications repository, all you have to do is to amend the gopass entry, the secrets will be delivered on every deployment without any user interaction.

