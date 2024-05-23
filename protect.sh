#!/bin/bash

set -x

test_api() {
  account_id=$1
  api_token=$2

  curl --location --request GET \
    "https://astra.demo.netapp.com/accounts/$account_id/core/v1/users" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $api_token" \
    | jq .  
}

list_apps() {
  account_id=$1
  api_token=$2
  managedCluster_id=$3

  curl --location --request GET \
    "https://astra.demo.netapp.com/accounts/$account_id/topology/v2/managedClusters/$managedCluster_id/apps" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $api_token" \
 | jq .
}

define_app() {
  account_id=$1
  api_token=$2
  managedCluster_id=$3

  curl -v --location --request POST \
    "https://astra.demo.netapp.com/accounts/$account_id/topology/v2/managedClusters/$managedCluster_id/apps" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $api_token" \
    --data-binary @- << EOF
{
  "type": "application/astra-app",
  "version": "2.2",
  "name": "teris",
  "namespaceScopedResources": [
    {
      "namespace": "retrogames",
      "labelSelectors": "app=tetris"
    }
  ]
}
EOF
}

do_protect() {
  read -p "Account ID: " account_id < /dev/tty
  read -p "API Token: " api_token < /dev/tty
  read -p "Managed Cluster ID: " managedCluster_id < /dev/tty
  test_api $account_id $api_token
  list_apps $account_id $api_token $managedCluster_id
  define_app $account_id $api_token $managedCluster_id
}

do_protect
