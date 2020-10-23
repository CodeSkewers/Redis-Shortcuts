#!/bin/bash

# Connection Variables
clusterNode=$1
copy=("scp -q")
connect=("ssh -q")

# Inventory Variables
rladmin=("/opt/redislabs/bin/rladmin")
rlutil=("/opt/redislabs/bin/rlutil")
master=$($connect $clusterNode "$rladmin status nodes |grep master |awk '{print \$3}'")
slaves=($($connect $clusterNode "$rladmin status nodes |grep slave |awk '{print \$3}'" ))
DBs=($($connect $clusterNode "$rladmin status databases |grep db |awk '{print \$2}'" ))

# Utility Variables
oldSockpath=("/tmp")
newSockpatch=("/var/opt/redislabs/run")
createSockpath=("$rlutil create_socket_path socket_path=$newSockpatch")
setSockpath=("$rlutil set_socket_path socket_path=$newSockpatch")
reStartdb=("$rladmin restart db")
reBalance=("$rladmin migrate endpoint_to_shards commit")

# Supervisorctl Variables
supCtl=("/opt/redislabs/bin/supervisorctl")
rlecSupcheck=("$supCtl status cm_server |awk '{print \$2}'")
rlecSupRestart=("service rlec_supervisor restart")



# -- Execution

#Check Socket Files
 echo ""
echo "Checking socket files..."
if $connect $master [[ -e  $newSockpatch/*.sock ]]
then
    echo "Socket Files exist in the proper location, discontinuing script process"
    exit 1
else
    echo "Socekt files need to be migrated, continuing process"
fi
#Restart rlec_supervisor if necessary
echo "Verifying rlec_supervisor."
echo ""
for i in $master "${slaves[@]}"
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

#Creating new socket path on all nodes
echo "Creating new socket paths."
echo ""
for j in $master "${slaves[@]}"
do
    $connect $j $createSockpath
    sleep 10
done


# Setting new socket path on Master
$connect $master $setSockpath
sleep 20

#restart rlec_supervisor on all nodes
echo "Restarting rlec_supervisor"
echo ""
for k in $master "${slaves[@]}"
do
    $connect $k $rlecSupRestart
    sleep 30
done
# Restart Databases
echo "Restartinging databases"
for l in "${DBs[@]}"
do
    echo "Restarting $l ..."
    $connect $master $reStartdb $l
    sleep 20
done

# Rebanancing Databases
echo "Rebalancing Databases and endpoints"
echo ""
$connect $master $reBalance
echo ""
echo "Socket File Replacement complete"
