#!/bin/sh

set -e

WORKDIR=`mktemp -d`

function cleanup {
    rm -rf ${WORKDIR}
}

trap cleanup EXIT

function trivy_scan {
    # Perform trivy scans
    mkdir -p ${1}/trivy
    trivy -f json image ${2}:latest > ${1}/trivy/${2}.json
}

function grype_scan {
    # Perform grype scans
    mkdir -p ${1}/grype
    grype -o json ${2}:latest > ${1}/grype/${2}.json
}

for IMAGE in amazonlinux fedora ubi8 ubi9 ubi8-minimal ubi9-minimal; do
    SCANDIR=${WORKDIR}/${IMAGE}

    echo "===== Processing ${IMAGE} =========================="

    trivy_scan ${SCANDIR} ${IMAGE}
    grype_scan ${SCANDIR} ${IMAGE}

    # Install the latest package updates.
    cat > Containerfile <<EOF
FROM ${IMAGE}:latest
RUN yum -y update || microdnf -y update
EOF
    podman build -t ${IMAGE}-updated .
    trivy_scan ${SCANDIR} ${IMAGE}-updated
    grype_scan ${SCANDIR} ${IMAGE}-updated

    # Install everything.
    if [[ ${IMAGE} != *-minimal ]]; then
      # Install the latest package updates.
      cat > Containerfile <<EOF
FROM ${IMAGE}:latest
RUN yum -y --skip-broken install \*
EOF
      podman build -t ${IMAGE}-full .
      trivy_scan ${SCANDIR} ${IMAGE}-full
      grype_scan ${SCANDIR} ${IMAGE}-full
    fi

    (cd ${WORKDIR}; tar cvfz ${IMAGE}-scanalisys.tar.gz ${IMAGE})
done

cp ${WORKDIR}/*.tar.gz .
