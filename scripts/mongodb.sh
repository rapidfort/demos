#!/bin/bash

echo "Mongo Demo"

# pull the latest mongo image
docker pull mongo:latest

# run rfstub to generate the stub. this creates a new image, mongo:latest-rfstub
rfstub mongo:latest

# run the stub. add the SYS_PTRACE capability so that RapidFort can trace the runtime behavior
docker run -d --rm -eMONGO_INITDB_ROOT_USERNAME=root -eMONGO_INITDB_ROOT_PASSWORD=my_pass -p8081:8081 --name my-rf-test --cap-add=SYS_PTRACE mongo:latest-rfstub
sleep 15

# run some tests to exercise the application. 
curl https://raw.githubusercontent.com/rapidfort/community-images/main/community_images/common/tests/test.mongo > test.mongo
docker cp test.mongo my-rf-test:/tmp/test.mongo
docker exec -i my-rf-test /bin/bash -c "mongosh admin --authenticationDatabase admin -u root -p my_pass --file /tmp/test.mongo"

# stop the container
docker stop my-rf-test

# run rfharden to optimize and secure the image. this creates a new image, mongo:latest-rfhardened
rfharden mongo:latest-rfstub

# check out the various images we created
docker images grep mongo

# run the hardened image and test it again
docker run -d --rm -eMONGO_INITDB_ROOT_USERNAME=root -eMONGO_INITDB_ROOT_PASSWORD=my_pass -p8081:8081 --name mongo-hardened mongo:latest-rfhardened
sleep 15
docker cp test.mongo mongo-hardened:/tmp/test.mongo
docker exec -i mongo-hardened /bin/bash -c "mongosh admin --authenticationDatabase admin -u root -p my_pass --file /tmp/test.mongo"

# for more information, please view the Getting Started documentation
echo "https://docs.rapidfort.com/getting-started/docker"
