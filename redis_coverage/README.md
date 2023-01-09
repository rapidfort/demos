# Sample coverage script for redis.

This is a demonstration of how to write a simple coverage script, which is then used for hardening the application
using RapidFort's platform in a kubernetes environment.

You must have kubectl installed and have access to a k8s cluster.

In this script, we exercise the different configurations of redis (TLS and no TLS), run a set of
redis commands in each configuration, invoke some errors, and run some commands to make sure they are included
in the hardened image.

For more info on writing coverage scripts, please see https://bit.ly/rf-coverage-scripts
