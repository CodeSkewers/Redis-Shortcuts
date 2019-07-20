#!/bin/bash

#################################################################################
# This script will automatically look for all of the Redis Enterprise databases #
# on your system and upgrade them after you perform a cluster version upgrade. ##
### Created by: Jude Cadet.  Any questions, please email jcadet3@icloud.com. ####
#################################################################################
 

#Variables:
rladmin=/opt/redislabs/bin/rladmin

## Gather existing Database names:
DBs=($($rladmin status databases | grep db |awk '{print $2}' ))

for i in `echo ${DBs[@]}`; do
echo "Upgrading $i...";
$rladmin upgrade db $i;
done