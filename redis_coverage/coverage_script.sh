#!/bin/bash

# Sample coverage script for redis.
#
# This is a demonstration of how to write a simple coverage script, which is then used for hardening the application
# using RapidFort's platform in a kubernetes environment.
#
# You must have kubectl installed and have access to a k8s cluster.
#
# In this script, we exercise the different configurations of redis (TLS and no TLS), run a set of
# redis commands in each configuration, invoke some errors, and run some commands to make sure they are included
# in the hardened image.
#
# For more info on writing coverage scripts, please see https://bit.ly/rf-coverage-scripts
#

set -x

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <k8s-namespace> <tag>"
    exit 1
fi

NAMESPACE=$1 #ci-dev
TAG=$2 #6.2.6-debian-10-r103
echo "Running image generation for $0 $1 $2"

IREGISTRY=docker.io                             # input registry
IREPO=bitnami/redis                             # which repo in the registry?
OACCOUNT=codervinod                             # replace with your own account userid
PUB_REPO=${OACCOUNT}/redis                      # this is where the generated images will get pushed to
OREPO=${PUB_REPO}-rfstub                        # stubbed image

HELM_RELEASE=redis-release                      # local var


create_stub()
{
    # Usage: create_stub
    #
    # Create the RapidFort stubbed version of the container.
    # Stubbing process scans the image for components and generates the SBOM and vulnerabilties report, as well
    # as an instrumented version of the application with "-rfstub" added to the image tag.
    #

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
    # Usage: test_no_tls <image-repo>
    #
    # image-repo: pass the name of the image to run the tests on...
    #
    # Run the redis tests on the no-TLS configuration of redis
    #
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

    # copy common_commands.sh into container
    kubectl -n ${NAMESPACE} cp common_commands.sh ${HELM_RELEASE}-master-0:/tmp/common_commands.sh

    # run script
    kubectl -n ${NAMESPACE} exec -i ${HELM_RELEASE}-master-0 -- /tmp/common_commands.sh

    # copy redis_coverage.sh into container
    kubectl -n ${NAMESPACE} cp redis_coverage.sh ${HELM_RELEASE}-master-0:/tmp/redis_coverage.sh

    # run script
    kubectl -n ${NAMESPACE} exec -i ${HELM_RELEASE}-master-0 -- /tmp/redis_coverage.sh

    # bring down helm install
    helm delete ${HELM_RELEASE} --namespace ${NAMESPACE}

    # delete the PVC associated
    kubectl -n ${NAMESPACE} delete pvc --all
}


test_tls()
{
    # Usage: test_tls <image-repo>
    #
    # image-repo: pass the name of the image to run the tests on...
    #
    # Run the redis tests on the TLS configuration of redis
    #
    local IMAGE_REPOSITORY=$1
    echo "Testing redis with TLS"

    # Install certs
    kubectl apply -f cert_manager.yml
    kubectl --namespace ${NAMESPACE} apply -f tls_certs.yml

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
    kubectl --namespace ${NAMESPACE} delete -f tls_certs.yml
    kubectl delete -f cert_manager.yml

    # delete the PVC associated
    kubectl -n ${NAMESPACE} delete pvc --all
}

harden_image()
{
    # Usage: harden_image
    #
    # Create the hardened image and push it to the output repo

    # Create the hardened image
    rfharden ${IREGISTRY}/${IREPO}:${TAG}-rfstub

    # Change tag to point to output docker account
    docker tag ${IREGISTRY}/${IREPO}:${TAG}-rfhardened ${PUB_REPO}:${TAG}

    # Push stub to output dockerhub account
    docker push ${PUB_REPO}:${TAG}

    echo "Hardened images pushed to ${PUB_REPO}:${TAG}"
}


main()
{
    # create the RapidFort stub (instrumented version of the container)
    create_stub

    # Run the tests in both TLS and no-TLS configurations
    # Each test runs a set of redis commands exercising various redis functionalities

    test_no_tls ${OREPO}        # test non tls config
    test_tls ${OREPO}           # test TLS config

    harden_image                # harden image

    # test hardened images
    test_no_tls ${PUB_REPO}
    test_tls ${PUB_REPO}
}

main
