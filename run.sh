#!/bin/bash

set -e
set -x

WORKDIR=`mktemp -d`

function cleanup {
    rm -rf ${WORKDIR}
}

trap cleanup EXIT

function trivy_scan {
    # Perform trivy scans
    IMG=$(echo ${2} | sed 's/\//\-\-/g')
    mkdir -p ${IMG}/trivy
    trivy -f json -o ${1}/trivy/${IMG}.json image ${2}:latest
}

function grype_scan {
    # Perform grype scans
    IMG=$(echo ${2} | sed 's/\//\-\-/g')
    mkdir -p ${IMG}/grype
    grype -o json=${IMG}/grype/${IMG}.json ${2}:latest
}

for IMAGE in registry.access.redhat.com/ubi9 registry.access.redhat.com/ubi8 registry.access.redhat.com/ubi9-minimal registry.access.redhat.com/ubi8-minimal amazonlinux fedora; do

    SCANDIR=${WORKDIR}/$(echo ${IMAGE} | sed -e 's/regi.*\///g')

    echo "===== Processing ${IMAGE} =========================="

    # Install the latest package updates.
    cat > Containerfile <<EOF
FROM ${IMAGE}:latest
RUN yum -y update || microdnf -y update
EOF
    podman build -t ${IMAGE}-with-updates .
    trivy_scan ${SCANDIR} ${IMAGE}-with-updates
    grype_scan ${SCANDIR} ${IMAGE}-with-updates

    IMG=$(echo ${IMAGE}-with-updates | sed 's/\//\-\-/g')
    VERSION=$(date +%Y%m%d)
    (cd ${WORKDIR};
     tar cvfz ${IMG}-scanalysis.tar.gz * ;
     oras push ghcr.io/open-scanalysis/${IMG}:${VERSION} ${IMG}-scanalysis.tar.gz:application/vnd.uknown/layer.v1+gzip ;
     oras tag ghcr.io/open-scanalysis/${IMG}:${VERSION} latest
     rm -rf *
    )
done
