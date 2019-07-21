#!/bin/bash

#################################################################################
#### This script will automatically create a Redis Enterprise cluster on the ####
### master node, and join the other nodes to that same cluster. Feel free to ####
########################### customize to your needs. ############################
### Created by: Jude Cadet.  Any questions, please email jcadet3@icloud.com. ####
#################################################################################
 

# Variables:
node=$(echo `hostname` |cut -d '.' f1)
nodeNum=(${node:(-2)})
clustID= #define what the cluster name should be.
nodePre=(${node:0-2})
mIpAdr=($(host $nodePre'01' |awk '{print $4}'))
timer=(90)
restime=$[timer*($nodeNum)]
uName= #define the cluster administrative username.
idP= #define what you would like the cluster password to be.

## Functions

Function Run1() {
    /opt/redislabs/bin/rladmin cluster create name rediscluster-$clustID.company.com username $uName password $idP
}

Function Run2() {
    /opt/redislabs/bin/rladmin cluster join nodes $mIpAdr username $uName password $idP
}


###Run Script:

if [ "$nodeNum" == 01 ]
then
        echo "This is node $node, creating cluster."
        Run1
else
        echo "This is node $node, joining primary cluster."
        sleep $restime
        Run2
fi