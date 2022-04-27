#!/bin/bash

# Connection Variables
clusterNode=$1
copy=("scp -q")
connect=("ssh -q")
ugBin=("redislabs-6.0.6-39-rhel7-x86_64.tar")
ARCHIVE=/home/jcadet/redis/software/$ugBin

# Inventory Variables
rladmin=("/opt/redislabs/bin/rladmin")
master=$($connect $clusterNode "$rladmin status nodes |grep master |awk '{print \$3}'")
slaves=($($connect $clusterNode "$rladmin status nodes |grep slave |awk '{print \$3}'" ))
DBs=($($connect $clusterNode "$rladmin status databases |grep db |awk '{print \$2}'" ))

# Utility Variables
instDir=("/tmp/redis_install")
dirCreate=("mkdir $instDir")
unPack=("tar xvf $instDir/$ugBin -C $instDir")
ugRun=("cd $instDir && ./install.sh -y")
ugDB=("$rladmin upgrade db")
cleanUp=("rm /tmp/redis_install/* -rf")
certFix=("/opt/redislabs/bin/python2.7 -O /opt/redislabs/sbin/sync_certificates.py --action load_certificates_from_disk")
reBalance=("$rladmin migrate endpoint_to_shards commit")
cfgBkp=("mkdir /rds_bkp && cp -Rp /var/opt/redislabs/persist/ /rds_bkp")
certBkp=("mkdir /rds_bkp/bkp_certs && cp -Rp /etc/opt/redislabs/*.pem /rds_bkp/bkp_certs")

# Create install directories & copy files.
echo ""
echo "Upgrade Preparations"
echo ""
for i in $master "${slaves[@]}"
do
    echo ""
    #Backups
    echo "Backing up config files and certs..."
    $connect $i $cfgBkp
    $connect $i $certBkp

    #Create install directory.
    echo "Creating install directories if necessary..."
    if $connect $i [[ -d  $instDir ]]
    then
        echo "/tmp/redis_install exists on node $i, continuing install"
    else
        echo "/tmp/redis_install does NOT exist on node $i, creating directory..."
        $connect $i $dirCreate
    fi
    sleep 10

    #Copy files
    if $connect $i [[ -e  $instDir/$ugBin ]]
    then
        echo "Upgrade files exist on node $i, continuing install"
    else
        echo "Copying upgrade files to $i ..."
        $copy $i $ARCHIVE $i:$instDir
    fi
done

# Upgrade Redis Software
echo ""
echo "Performing Redis Enterprise cluster Upgrade"
echo ""

for j in $master "${slaves[@]}"
do
    if $connect $i [[ -e  $instDir/install.sh ]]
    then
        echo ""
        echo "Binary tarball is already extracted on $j, continuing upgrade..."
    else
        echo ""
        echo "Extracting Redis Upgrade Binaries on $j ..."
        $connect $j $unPack
        sleep 10
    fi
    $connect $j $certFix
    sleep 10
    $connect $j $ugRun
    sleep 40
done

echo "Upgrading databases"

for k in "${DBs[@]}"
do
    echo "Upgrading $k ..."
    $connect $master $ugDB $k
    sleep 20
done

# Cleaning up install files

echo ""
for l in $master "${slaves[@]}"
do
    echo "Cleaning up install files on $l ..."
    $connect $l $cleanUp
    sleep 5
done
echo ""
echo "Rebalancing Databases and endpoints"
echo ""
$connect $master $reBalance
echo ""
echo "Upgrade Complete"
