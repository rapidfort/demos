#!/bin/bash
set -x
echo "Redis Demo"

# pull the latest Redis image
docker pull redis:latest

# run rfstub to generate the stub. this creates a new image, redis:latest-rfstub
rfstub redis:latest

# run the stub. add the SYS_PTRACE capability so that RapidFort can trace the runtime behavior
docker run --rm -d -p 6379:6379 --cap-add=SYS_PTRACE --name my-rf-test redis:latest-rfstub
sleep 15

# run some tests to exercise the application. 
curl https://raw.githubusercontent.com/rapidfort/community-images/main/community_images/common/tests/test.redis > test.redis
docker cp test.redis my-rf-test:/tmp/test.redis
docker exec -i my-rf-test /bin/bash -c "cat /tmp/test.redis | redis-cli --pipe"

# stop the container
docker stop my-rf-test

# run rfharden to optimize and secure the image. this creates a new image, redis:latest-rfhardened
rfharden redis:latest-rfstub

# check out the various images we created
docker images | grep redis

# run the hardened image and test it again
docker run --rm -d -p 6379:6379 --name redis-hardened redis:latest-rfhardened
sleep 15
docker cp test.redis redis-hardened:/tmp/test.redis
docker exec -i redis-hardened /bin/bash -c "cat /tmp/test.redis | redis-cli --pipe"

# for more information, please view the Getting Started documentation
echo "https://docs.rapidfort.com/getting-started/docker"
