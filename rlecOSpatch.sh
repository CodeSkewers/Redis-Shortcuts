#!/bin/bash

# --Variables
clusterNode=$1
connect=("ssh -q")

#Create Inventory
master=$($connect $clusterNode "rladmin status nodes |grep master |awk '{print \$3}'")
slaves=$($connect $clusterNode "rladmin status nodes |grep slave |awk '{print \$3}'")
slaveNum=( $($connect $clusterNode "rladmin status nodes |grep slave |awk '{print \$1}' |cut -d ':' -f2"))
dbStat=$($connect $clusterNode "rladmin status shards |grep db |awk '{print \$8}'")
reBalance=$($connect $clusterNode "rladmin migrate endpoint_to_shards commit")

#Check Supervisorctl
rlecSupcheck=("supervisorctl status cm_server |awk '{print \$2}'")
rlecStopall=("supervisorctl stop all")
rlecSupRestart=("service rlec_supervisor restart")

#OS Patching and Validations
osPatch=("$rlecStopall; yum -y update; reboot")
osCheck=("uptime |awk '{print \$3}'")
reBalance=("rladmin migrate endpoint_to_shards commit")


#Restart rlec_supervisor if necessary
echo "Verifying rlec_supervisor."
echo ""
for i in $slaves $master
do
    ctlCheck=("$connect $i $rlecSupcheck")
    $ctlCheck

    if [[ `$ctlCheck` == 'RUNNING' ]]
        then
               echo "rlec_supervisor is running properly on $i, continuing with procedure."
            else
               echo "rlec_supervisor isn't functioning properly on $i, retsarting"
                $connect $i $rlecSupRestart
                sleep 20
            fi

done

#OS Patch Slave Nodes
echo "Conducting OS Patching..."

for j in $slaves

do
    ctlCheck2=("$connect $j $rlecSupcheck")
    echo ""
    echo $j
    $connect $j $osPatch
    sleep 5s
    until [[ `$ctlCheck2` == 'RUNNING' ]]
    do
        echo ""
        echo "Awaiting system reboot..."
        sleep 20
    done
    echo ""
    echo "Node is up and running, and the Redis services are started on node $j,  Continuing script."
    echo ""
done

#Failing over and upgrading master node
echo "Failing over $master from master node status"
oldMaster=$master
$connect $master "rlutil change_master master=${slaveNum[0]}"
sleep 20
echo "Upgrading $oldMaster"
    ctlCheck2=("$connect $oldMaster $rlecSupcheck")
    echo ""
    echo $oldMaster
    $connect $oldMaster $osPatch

    sleep 5
    until [[ `$ctlCheck2` == 'RUNNING' ]]
    do
        echo ""
        echo "Awaiting system reboot..."
        sleep 20
    done
echo ""
echo "Node is up and running, and the Redis services are started on node $oldMaster."
echo "OS patching process completed"
echo ""

# --Validations

echo "Validating DB health"
echo ""
echo "Rebalancing Databases if necessary..."
echo""
$connect $clusterNode $reBalance
sleep 30
echo""
echo "Checking DB status"

for k in $dbStat
do
        sleep 120
        if [[ $k == 'OK' ]]
        then
            echo "Database shard status reporting 'OK' "
        else
            echo "An issue with one of the databases in the cluster exists, please investigate!"
        sleep 1
        fi
done
