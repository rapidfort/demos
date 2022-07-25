#!/bin/bash

echo "Nginx Demo"

# pull the latest NGINX image
docker pull nginx:latest

# run rfstub to generate the stub. this creates a new image, nginx:latest-rfstub
rfstub nginx:latest

# run the stub. add the SYS_PTRACE capability so that RapidFort can trace the runtime behavior
docker run --rm -d -p9999:80 --name=my-rf-test --cap-add=SYS_PTRACE nginx:latest-rfstub
sleep 15

# run some tests to exercise the application. you can also point your browser to localhost:9999
curl localhost:9999

# stop the container
docker stop my-rf-test

# run rfharden to optimize and secure the image. this creates a new image, nginx:latest-rfhardened
rfharden nginx:latest-rfstub

# check out the various images we created
docker images grep nginx

# run the hardened image and test it again
docker run --rm -d -p9999:80 nginx:latest-rfhardened
sleep 15
curl localhost:9999

# for more information, please view the Getting Started documentation
echo "https://docs.rapidfort.com/getting-started/docker"
