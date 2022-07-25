#!/bin/bash
set -x
echo "Mysql Demo"

# pull the latest Mysql image
docker pull mysql:latest

# run rfstub to generate the stub. this creates a new image, Mysql:latest-rfstub
rfstub mysql:latest

# run the stub. add the SYS_PTRACE capability so that RapidFort can trace the runtime behavior
docker run -d --rm -eMYSQL_ROOT_PASSWORD=my_pass -p3306:3306 --name my-rf-test --cap-add=SYS_PTRACE mysql:latest-rfstub
sleep 15

# run some tests to exercise the application. 
curl https://raw.githubusercontent.com/rapidfort/community-images/main/community_images/common/tests/test.my_sql > test.my_sql
docker cp test.my_sql my-rf-test:/tmp/test.my_sql
docker exec -i my-rf-test /bin/bash -c "mysql -h localhost -uroot -pmy_pass mysql < /tmp/test.my_sql"

# stop the container
docker stop my-rf-test

# run rfharden to optimize and secure the image. this creates a new image, Mysql:latest-rfhardened
rfharden mysql:latest-rfstub

# check out the various images we created
docker images | grep mysql

# run the hardened image and test it again
docker run -d --rm -eMYSQL_ROOT_PASSWORD=my_pass -p3306:3306 --name mysql-hardened mysql:latest-rfhardened
sleep 15
docker cp test.my_sql mysql-hardened:/tmp/test.my_sql
docker exec -i mysql-hardened /bin/bash -c "mysql -h localhost -uroot -pmy_pass mysql < /tmp/test.my_sql"

# for more information, please view the Getting Started documentation
echo "https://docs.rapidfort.com/getting-started/docker"
