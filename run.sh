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
    mkdir -p ${1}/trivy
    trivy -f json -o ${1}/trivy/${2}.json image ${2}:latest
}

function grype_scan {
    # Perform grype scans
    mkdir -p ${1}/grype
    grype -o json=${1}/grype/${2}.json ${2}:latest
}

for IMAGE in amazonlinux fedora ubi8 ubi9 ubi8-minimal ubi9-minimal; do
    SCANDIR=${WORKDIR}/${IMAGE}

    echo "===== Processing ${IMAGE} =========================="

    # Install the latest package updates.
    cat > Containerfile <<EOF
FROM ${IMAGE}:latest
RUN yum -y update || microdnf -y update
EOF
    podman build -t ${IMAGE}-with-updates .
    trivy_scan ${SCANDIR} ${IMAGE}-with-updates
    grype_scan ${SCANDIR} ${IMAGE}-with-updates

    (cd ${WORKDIR}; tar cvfz ${IMAGE}-scanalisys.tar.gz ${IMAGE})
done

cp ${WORKDIR}/*.tar.gz .
