

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
