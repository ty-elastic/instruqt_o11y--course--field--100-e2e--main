#!/bin/bash

source $PWD/assets/scripts/retry.sh

get_version_for_package_from_elastic() {
    printf "$FUNCNAME for $1...\n"

    output=$(curl -s -X GET "https://epr.elastic.co/search" \
        -w "\n%{http_code}")

    # Extract HTTP status code
    http_code=$(echo "$output" | tail -n1)
    http_response=$(echo "$output" | sed '$d')
    if [ "$http_code" != "200" ]; then
        printf "$FUNCNAME...ERROR $http_code: $http_response\n"
        return 1
    fi

    PACKAGE=$(echo $http_response | jq -r '.[] | select (.name == "'$1'")')
    PACKAGE_NAME=$(echo $PACKAGE | jq -r '.name')
    PACKAGE_VERSION=$(echo $PACKAGE | jq -r '.version')

    if [[ -z "$PACKAGE_NAME" ]]; then
        printf "$FUNCNAME...ERROR: PACKAGE_NAME is unset\n"
        return 1
    fi

    printf "$FUNCNAME...PACKAGE_NAME=$PACKAGE_NAME, PACKAGE_VERSION=$PACKAGE_VERSION\n"
    export PACKAGE_NAME=$PACKAGE_NAME
    export PACKAGE_VERSION=$PACKAGE_VERSION
    return 0
}

get_version_for_package_from_stack() {
    printf "$FUNCNAME for $1...\n"

    output=$(curl -s -X GET "$2/api/fleet/epm/packages" \
        -w "\n%{http_code}" \
        -H 'kbn-xsrf: true' \
        -H 'x-elastic-internal-origin: Kibana' \
        -H "Authorization: ApiKey ${3}")

    # Extract HTTP status code
    http_code=$(echo "$output" | tail -n1)
    http_response=$(echo "$output" | sed '$d')
    if [ "$http_code" != "200" ]; then
        printf "$FUNCNAME...ERROR $http_code: $http_response\n"
        return 1
    fi

    PACKAGE=$(echo $http_response | jq -r '.items[] | select (.name == "'$1'")')
    PACKAGE_NAME=$(echo $PACKAGE | jq -r '.name')
    PACKAGE_VERSION=$(echo $PACKAGE | jq -r '.version')

    if [[ -z "$PACKAGE_NAME" ]]; then
        printf "$FUNCNAME...ERROR: PACKAGE_NAME is unset\n"
        return 1
    fi

    printf "$FUNCNAME...PACKAGE_NAME=$PACKAGE_NAME, PACKAGE_VERSION=$PACKAGE_VERSION\n"
    export PACKAGE_NAME=$PACKAGE_NAME
    export PACKAGE_VERSION=$PACKAGE_VERSION
    return 0
}

install_integration_package() {
    printf "$FUNCNAME for $1...\n"

    unset $PACKAGE_NAME
    unset $PACKAGE_VERSION

    # fast path
    get_version_for_package_from_elastic $1
    if [ $? -ne 0 ]; then
        get_version_for_package_from_stack $1 $2 $3
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi

    output=$(curl -s -X POST "$2/api/fleet/epm/packages/$PACKAGE_NAME/$PACKAGE_VERSION" \
        -w "\n%{http_code}" \
        -H 'kbn-xsrf: true' \
        -H 'x-elastic-internal-origin: Kibana' \
        -H "Authorization: ApiKey ${3}")

    # Extract HTTP status code
    http_code=$(echo "$output" | tail -n1)
    http_response=$(echo "$output" | sed '$d')
    if [ "$http_code" != "200" ]; then
        printf "$FUNCNAME for $1...ERROR $http_code: $http_response\n"
        return 1
    fi

    export INTEGRATION_DASHBOARDS=$(echo $http_response | jq -r '.items[] | select (.type == "dashboard")')
    
    printf "$FUNCNAME for $1...SUCCESS\n"
    return 0
}
export -f install_integration_package

