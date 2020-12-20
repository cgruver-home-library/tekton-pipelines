# Tekton Pipelines for Java Applications

This project provides an opinionated set of pipelines that allow development teams to set up CI/CD for their projects without maintaining pipeline boilerplate within their development code base.

The capabilities provided are achieved by taking advantage of OpenShift Templates exposed through the Catalog, and the Namespace Configuration Operator which synchronizes and maintains common artifacts across labeled namespaces.

## Quarkus JVM

## Quarkus Fast-JAR

## Quarkus Native

## Spring Boot

# WIP: This documentation is incomplete

## Installation:

Create a maven group in your local maven nexus: homelab-central

### Expose a route for the OKD Internal Registry:

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

### Create pipeline images and push to the internal OKD registry:

```bash
cd images

IMAGE_REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
podman login -u $(oc whoami) -p $(oc whoami -t) --tls-verify=false ${IMAGE_REGISTRY}

podman pull quay.io/openshift/origin-cli:4.6.0
podman tag quay.io/openshift/origin-cli:4.6.0 ${IMAGE_REGISTRY}/openshift/origin-cli:4.6.0
podman tag quay.io/openshift/origin-cli:4.6.0 ${IMAGE_REGISTRY}/openshift/origin-cli:latest

podman pull registry.access.redhat.com/ubi8/ubi-minimal:8.3
podman tag registry.access.redhat.com/ubi8/ubi-minimal:8.3 ${IMAGE_REGISTRY}/openshift/ubi-minimal:8.3
podman tag registry.access.redhat.com/ubi8/ubi-minimal:8.3 ${IMAGE_REGISTRY}/openshift/ubi-minimal:latest


podman build -t ${IMAGE_REGISTRY}/openshift/jdk-11-app-runner:1.3.8 -f jdk-11-app-runner.Dockerfile .
podman tag ${IMAGE_REGISTRY}/openshift/jdk-11-app-runner:1.3.8 ${IMAGE_REGISTRY}/openshift/jdk-11-app-runner:latest

podman build -t ${IMAGE_REGISTRY}/openshift/maven-jdk-mandrel-builder:3.6.3-11-20.2 -f maven-jdk-mandrel-builder.Dockerfile .
podman tag ${IMAGE_REGISTRY}/openshift/maven-jdk-mandrel-builder:3.6.3-11-20.2 ${IMAGE_REGISTRY}/openshift/maven-jdk-mandrel-builder:latest

podman build -t ${IMAGE_REGISTRY}/openshift/buildah:nonroot -f buildah-nonroot.Dockerfile .

podman push ${IMAGE_REGISTRY}/openshift/origin-cli:4.6.0 --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/origin-cli:latest --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/ubi-minimal:8.3 --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/ubi-minimal:latest --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/jdk-11-app-runner:1.3.8 --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/jdk-11-app-runner:latest --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/maven-jdk-mandrel-builder:3.6.3-11-20.2 --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/maven-jdk-mandrel-builder:latest --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/buildah:nonroot --tls-verify=false

```

Install Namespace Configuration Operator:

```bash
git clone https://github.com/redhat-cop/namespace-configuration-operator.git
cd namespace-configuration-operator
oc adm new-project namespace-configuration-operator
oc apply -f deploy/olm-deploy -n namespace-configuration-operator
```

### Deploy Pipeline objects:

Create a Maven Group in your Nexus instance.

Create Maven Proxies for:

- `https://repo1.maven.org/maven2/`
- `https://repo.maven.apache.org/maven2`
- `https://origin-maven.repository.redhat.com/ga/`

Add all of the maven proxies that you created to your new maven group.

```bash
MAVEN_GROUP=<The Maven Group You Just Created>
NEXUS_URL=https://nexus.your.domain.com:8443/repository
oc process --local -f namespace-config/namespace-configuration-maven-mirror-template.yaml -p MVN_MIRROR_ID=${MAVEN_GROUP} -p MVN_MIRROR_NAME=${MAVEN_GROUP} -p MVN_MIRROR_URL=${NEXUS_URL}/${MAVEN_GROUP} | oc apply -f -
oc apply -f namespace-config/namespace-configuration-java-cloud-native.yaml 

oc apply -f templates -n openshift
```

### Deploy an Application:

Label your namespace:

```bash
oc label namespace my-namespace maven-mirror-config="" tekton-java-cloud-native=""
```

```bash
NAMESPACE=
PROJECT_NAME=
GIT_REPOSITORY=
GIT_BRANCH=
CONFIG_GIT_REPOSITORY=
CONFIG_GIT_BRANCH=
CONFIG_GIT_PATH=

oc process openshift//quarkus-jvm-pipeline-dev -p APP_NAME=${PROJECT_NAME} -p GIT_REPOSITORY=${GIT_REPOSITORY} -p GIT_BRANCH=${GIT_BRANCH} -p CONFIG_GIT_REPOSITORY=${CONFIG_GIT_REPOSITORY} -p CONFIG_GIT_BRANCH=${CONFIG_GIT_BRANCH} -p CONFIG_GIT_PATH=${CONFIG_GIT_PATH} | oc apply -n ${NAMESPACE} -f -
```

Generate a GitHub Personal Access Token

Create a Secret for your git repo:

```yaml
apiVersion: v1
kind: Secret
metadata:
    name: git-secret
    annotations:
    tekton.dev/git-0: github.com
type: kubernetes.io/ssh-auth
data:
    token: <GitHub Access Token>
    secret: <A-Pass-Phrase-For-The-Repo-Web-Hook-Secret>
```

Or, use SSH access:

```bash
ssh-keygen -t rsa -f ~/.ssh/git.id_rsa -N ''

GIT_HOST=github.com
SSH_KEY=$(cat ~/.ssh/git.id_rsa | base64 -w0 )
KNOWN_HOSTS=$(ssh-keyscan ${GIT_HOST} | base64 -w0 )
cat << EOF > git-secret.yml
apiVersion: v1
kind: Secret
metadata:
    name: git-secret
    annotations:
      tekton.dev/git-0: ${GIT_HOST}
type: kubernetes.io/ssh-auth
data:
    ssh-privatekey: ${SSH_KEY}
    known_hosts: ${KNOWN_HOSTS}
EOF

oc apply -f git-secret.yml
rm -f git-secret.yml
oc patch sa pipeline --type merge --patch '{"secrets":[{"name":"git-secret"}]}'
```

### If you need to clean up lots of image pieces and parts that are laying around, the do this:

__Warning:__ This will delete all of the container images on your system.  It will also likely free up a LOT of disk space.
```bash
podman system prune --all --force
```
