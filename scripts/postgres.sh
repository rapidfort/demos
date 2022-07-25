#!/bin/bash
set -x
echo "Postgres Demo"

# pull the latest Postgres image
docker pull postgres:latest

# run rfstub to generate the stub. this creates a new image, Postgres:latest-rfstub
rfstub postgres:latest

# run the stub. add the SYS_PTRACE capability so that RapidFort can trace the runtime behavior
docker run -d --rm -ePOSTGRES_PASSWORD=my_pass -p5432:5432 --name my-rf-test --cap-add=SYS_PTRACE postgres:latest-rfstub
sleep 15

# run some tests to exercise the application. 
curl https://raw.githubusercontent.com/rapidfort/community-images/main/community_images/common/tests/test.psql > test.psql
docker cp test.psql my-rf-test:/tmp/test.psql
docker exec -i my-rf-test /bin/bash -c "PGPASSWORD=my_pass psql -U postgres -d postgres -f /tmp/test.psql"

# stop the container
docker stop my-rf-test

# run rfharden to optimize and secure the image. this creates a new image, Postgres:latest-rfhardened
rfharden postgres:latest-rfstub

# check out the various images we created
docker images grep postgres

# run the hardened image and test it again
docker run -d --rm -ePOSTGRES_PASSWORD=my_pass -p5432:5432 --name posgres-hardened postgres:latest-rfhardened
sleep 15
docker cp test.psql posgres-hardened:/tmp/test.psql
docker exec -i posgres-hardened /bin/bash -c "PGPASSWORD=my_pass psql -U postgres -d postgres -f /tmp/test.psql"

# for more information, please view the Getting Started documentation
echo "https://docs.rapidfort.com/getting-started/docker"
