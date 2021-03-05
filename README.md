# Tekton Pipelines for Java Applications
# Work In Progress: This documentation is incomplete

This pipeline implements a developer experience that flows like:

1. From the Delveloper Catalog, select the `create-rolling-replace-quarkus-fast-jar-app` Template, and provide the Git URL and Branch that you will be working from.

1. The template will trigger a Tekton TaskRun which will:

   1. Create a Tekton `TriggerTemplate`, `TriggerBinding`, and `EventListener` which will execute a `PipelineRun` when triggered by a GitLab webhook

   1. Create a GitLab Webhook that responds to `push` events by hitting the EventListener Route

1. A simple `git push` to the selected branch of your GitLab repository will trigger a build & deploy pipeline which will replace any previous deployments with a rolling release.

Developer Joy!
## Installation:

### Expose a route for the OKD Internal Registry:

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

### Create pipeline images and push to the internal OKD registry:

I have provided several opinionated images for this pipeline:

1. `jdk-11-app-runner.Dockerfile`

    This image is a simple fat jar runner.  It is based on the UBI 8 Minimal image, OpenJDK 11, and uses the java runner script from `fabric8`.

1. `maven-jdk-mandrel-builder.Dockerfile`

    This image is an app builder for JDK 11 and Mandrel 20 applications.  It will build Spring Boot, Quarkus JVM and Quarkus Native applications.

    The image includes Maven 3.6.3, git, OpenJDK 11, and Mandrel 20.

1. `buildah-nonroot.Dockerfile`

    This image modifies the `quay.io/buildah/stable:latest` image to allow for non-privileged builah.

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

podman build -t ${IMAGE_REGISTRY}/openshift/maven-jdk-mandrel-builder:3.6.3-11-20.3 -f maven-jdk-mandrel-builder.Dockerfile .
podman tag ${IMAGE_REGISTRY}/openshift/maven-jdk-mandrel-builder:3.6.3-11-20.3 ${IMAGE_REGISTRY}/openshift/maven-jdk-mandrel-builder:latest

podman build -t ${IMAGE_REGISTRY}/openshift/buildah:nonroot -f buildah-nonroot.Dockerfile .

podman push ${IMAGE_REGISTRY}/openshift/origin-cli:4.6.0 --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/origin-cli:latest --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/ubi-minimal:8.3 --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/ubi-minimal:latest --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/jdk-11-app-runner:1.3.8 --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/jdk-11-app-runner:latest --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/maven-jdk-mandrel-builder:3.6.3-11-20.3 --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/maven-jdk-mandrel-builder:latest --tls-verify=false
podman push ${IMAGE_REGISTRY}/openshift/buildah:nonroot --tls-verify=false

```

```bash
image-registry.openshift-image-registry.svc:5000
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
oc process --local -f namespace-config/maven-mirror-template.yaml -p MVN_MIRROR_ID=${MAVEN_GROUP} -p MVN_MIRROR_NAME=${MAVEN_GROUP} -p MVN_MIRROR_URL=${NEXUS_URL}/${MAVEN_GROUP} | oc apply -f -
oc apply -f namespace-config/java-cloud-native.yaml
oc apply -f namespace-config/okd-tekton.yaml
oc apply -f namespace-config/gitlab-webhook.yaml

oc apply -f templates -n openshift
```

### Deploy an Application:

Label your namespace:

```bash
oc label namespace my-library maven-mirror-config="" tekton-java="" okd-tekton="" tekton-gitlab=""
```

```bash
NAMESPACE=
PROJECT_NAME=
GIT_REPOSITORY=
GIT_BRANCH=

oc process openshift//quarkus-jvm-pipeline-gitlab-dev -p APP_NAME=${PROJECT_NAME} -p GIT_REPOSITORY=${GIT_REPOSITORY} -p GIT_BRANCH=${GIT_BRANCH} | oc apply -n ${NAMESPACE} -f -
```

Create a Secret for your git repo:

```bash
mkdir ~/git-ssh
ssh-keygen -t ed25519 -f ~/git-ssh/git.id_ed25519 -N ''

GIT_HOST=gitlab.your.domain.org
SSH_KEY=$(cat ~/git-ssh/git.id_ed25519 | base64 -w0 )
KNOWN_HOSTS=$(ssh-keyscan ${GIT_HOST} | base64 -w0 )
cat << EOF > git-ssh-secret.yml
apiVersion: v1
kind: Secret
metadata:
    name: git-ssh-secret
    annotations:
      tekton.dev/git-0: ${GIT_HOST}
type: kubernetes.io/ssh-auth
data:
    ssh-privatekey: ${SSH_KEY}
    known_hosts: ${KNOWN_HOSTS}
EOF

oc apply -f git-ssh-secret.yml
rm -f git-ssh-secret.yml
oc patch sa pipeline --type merge --patch '{"secrets":[{"name":"git-ssh-secret"}]}'
```

Upload `~/git-ssh/git.id_ed25519.pub` to your gitlab server as an SSH key for the service account that you want to access your code.
### If you need to clean up lots of image pieces and parts that are laying around, the do this:

__Warning:__ This will delete all of the container images on your system.  It will also likely free up a LOT of disk space.
```bash
podman system prune --all --force
```

```yaml
kind: BuildConfig
apiVersion: build.openshift.io/v1
metadata:
  annotations:
    app.openshift.io/vcs-ref: wip
    app.openshift.io/vcs-uri: 'https://github.com/lab-monkeys/tekton-pipelines.git'
  name: maven-jdk-mandrel-builder
  namespace: eric-test
  labels:
    app: quarkus-builder-image
    app.kubernetes.io/component: quarkus-builder-image
    app.kubernetes.io/instance: quarkus-builder-image
    app.kubernetes.io/part-of: quarkus-builder
spec:
  nodeSelector: null
  output:
    to:
      kind: ImageStreamTag
      name: 'quarkus-builder-image:latest'
  resources: {}
  successfulBuildsHistoryLimit: 5
  failedBuildsHistoryLimit: 5
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: maven-jdk-mandrel-builder.Dockerfile
  postCommit: {}
  source:
    type: Git
    git:
      uri: 'https://git.delta.com/ericsauer/tekton-pipelines.git'
      ref: wip
    contextDir: /images
  triggers:
    - type: ConfigChange
  runPolicy: Serial
  ```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-defaults
  namespace: openshift-pipelines
  labels:
    app.kubernetes.io/instance: default
    app.kubernetes.io/part-of: tekton-pipelines
data:
  default-service-account: "pipeline"
  default-managed-by-label-value: "openshift-pipelines"
  default-pod-template: |
    securityContext:
      runAsUser: 1000640000
      fsGroup: 1000640000

  ```
  