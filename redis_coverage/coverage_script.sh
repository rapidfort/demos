#!/bin/bash

set -x

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <k8s-namespace> <tag>"
    exit 1
fi

NAMESPACE=$1 #ci-dev
TAG=$2 #6.2.6-debian-10-r103
echo "Running image generation for $0 $1 $2"

IREGISTRY=docker.io
IREPO=bitnami/redis
OACCOUNT=codervinod
PUB_REPO=${OACCOUNT}/redis
OREPO=${PUB_REPO}-rfstub
HELM_RELEASE=redis-release


create_stub()
{
    # Pull docker image
    docker pull ${IREGISTRY}/${IREPO}:${TAG}
    # Create stub for docker image
    rfstub ${IREGISTRY}/${IREPO}:${TAG}

    # Change tag to point to rapidfort docker account
    docker tag ${IREGISTRY}/${IREPO}:${TAG}-rfstub ${OREPO}

    # Push stub to our dockerhub account
    docker push ${OREPO}
}


test_no_tls()
{
    local IMAGE_REPOSITORY=$1
    echo "Testing redis without TLS"
    # Install redis
    helm install ${HELM_RELEASE}  ${IREPO} --namespace ${NAMESPACE} \
        --set image.tag=${TAG} --set image.repository=${IMAGE_REPOSITORY} -f overrides.yml

    # waiting for pod to be ready
    echo "waiting for pod to be ready"
    kubectl wait pods ${HELM_RELEASE}-master-0 -n ${NAMESPACE} --for=condition=ready --timeout=10m

    # get Redis passwordk
    REDIS_PASSWORD=$(kubectl get secret --namespace ${NAMESPACE} ${HELM_RELEASE} -o jsonpath="{.data.redis-password}" | base64 --decode)


    # copy test.redis into container
    kubectl -n ${NAMESPACE} cp test.redis ${HELM_RELEASE}-master-0:/tmp/test.redis

    # run script
    kubectl -n ${NAMESPACE} exec -i ${HELM_RELEASE}-master-0 -- /bin/bash -c "cat /tmp/test.redis | REDISCLI_AUTH=\"${REDIS_PASSWORD}\" redis-cli -h localhost --pipe"

    # bring down helm install
    helm delete ${HELM_RELEASE} --namespace ${NAMESPACE}

    # delete the PVC associated
    kubectl -n ${NAMESPACE} delete pvc --all
}


test_tls()
{
    local IMAGE_REPOSITORY=$1
    echo "Testing redis with TLS"

    # Install certs
    kubectl apply --namespace ${NAMESPACE} -f tls_certs.yml

    #sleep 1 min
    echo "waiting for 1 min for setup"
    sleep 1m

    # Install redis
    helm install ${HELM_RELEASE} ${IREPO} --namespace ${NAMESPACE} \
        --set image.tag=${TAG} --set image.repository=${IMAGE_REPOSITORY} \
        --set tls.enabled=true --set tls.existingSecret=localhost-server-tls \
        --set tls.certCAFilename=ca.crt --set tls.certFilename=tls.crt \
        --set tls.certKeyFilename=tls.key -f overrides.yml

    # waiting for pod to be ready
    echo "waiting for pod to be ready"
    kubectl wait pods ${HELM_RELEASE}-master-0 -n ${NAMESPACE} --for=condition=ready --timeout=10m

    # get Redis passwordk
    REDIS_PASSWORD=$(kubectl get secret --namespace ${NAMESPACE} ${HELM_RELEASE} -o jsonpath="{.data.redis-password}" | base64 --decode)

    # copy test.redis into container
    kubectl -n ${NAMESPACE} cp test.redis ${HELM_RELEASE}-master-0:/tmp/test.redis

    # run script
    kubectl -n ${NAMESPACE} exec -i ${HELM_RELEASE}-master-0 -- /bin/bash -c "cat /tmp/test.redis | REDISCLI_AUTH=\"${REDIS_PASSWORD}\" redis-cli -h localhost --tls --cert /opt/bitnami/redis/certs/tls.crt --key /opt/bitnami/redis/certs/tls.key --cacert /opt/bitnami/redis/certs/ca.crt --pipe"

    # bring down helm install
    helm delete ${HELM_RELEASE} --namespace ${NAMESPACE}

    # delete certs
    kubectl delete --namespace ${NAMESPACE} -f tls_certs.yml

    # delete the PVC associated
    kubectl -n ${NAMESPACE} delete pvc --all
}

harden_image()
{
    # Create stub for docker image
    rfharden ${IREGISTRY}/${IREPO}:${TAG}-rfstub

    # Change tag to point to rapidfort docker account
    docker tag ${IREGISTRY}/${IREPO}:${TAG}-rfhardened ${PUB_REPO}:${TAG}

    # Push stub to our dockerhub account
    docker push ${PUB_REPO}:${TAG}

    echo "Hardened images pushed to ${PUB_REPO}:${TAG}"
}


main()
{
    # create RF stub
    create_stub
    # test with stub
    # test non tls config
    test_no_tls ${OREPO}

    # test TLS config
    test_tls ${OREPO}

    # harden image
    harden_image

    #test hardened images
    test_no_tls ${PUB_REPO}
    test_tls ${PUB_REPO}
}

main
