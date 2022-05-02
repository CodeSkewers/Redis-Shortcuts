#!/bin/bash


#Connection Variables
connect=("ssh -q")

# Inventory Variables
conf=("inventory.json")
keys=( $(jq -r 'keys' $conf |cut -d '"' -f2) )

cuNum=$(jq '. | length' $conf)

unset keys[0]
unset keys[64]


#API Pulls
function apiPull() {
    for i in "${keys[@]}"
    do
        cNode=$(jq -r ".$i | .node" $conf)
        logIn=$(jq -r ".$i | .login" $conf)
        apiUrl=$(jq -r ".$i | .url" $conf)
        apiExPull=("curl -l -k -u $logIn -X GET -H 'Content-type: application/json' $apiUrl 2>/dev/null | jq .expiration_date")
        apiLimitPull=("curl -l -k -u $logIn -X GET -H 'Content-type: application/json' $apiUrl 2>/dev/null | jq .shards_limit")
        cuUrl=$(echo "$apiUrl" | cut -d '/' -f3 | cut -d ':' -f1)
        echo $i
        echo $cuUrl
        $connect $cNode $apiExPull
        $connect $cNode $apiLimitPull
        echo ""
    done
}

echo "Cluster ID,Cluster URL,Expiration Date,License Limit" >rlec-CuLicense.csv
apiPull | sed 's/^$/%/g' | tr '\n' ',' | tr '%' '\n' | sed 's/^,//g' | sed 's/,$//g' | egrep '[a-zA-Z0-9]' >>rlec-CuLicense.csv
