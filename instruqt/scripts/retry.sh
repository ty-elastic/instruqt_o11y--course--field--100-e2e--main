#!/bin/bash

retry_command() {
    local max_attempts=8
    local timeout=5
    local attempt=1
    local exit_code=0

    while [ $attempt -le $max_attempts ]
    do
        "$@"
        exit_code=$?

        if [ $exit_code -eq 0 ]; then
            break
        fi

        printf "Attempt $attempt failed! Retrying in $timeout seconds...\n"
        sleep $timeout
        attempt=$(( attempt + 1 ))
        timeout=$(( timeout * 2 ))
    done

    if [ $exit_code -ne 0 ]; then
        printf "Command $@ failed after $attempt attempts!\n"
    fi

    return $exit_code
}
export -f retry_command

retry_command_lin() {
    local max_attempts=256
    local timeout=2
    local attempt=1
    local exit_code=0

    while [ $attempt -le $max_attempts ]
    do
        "$@"
        exit_code=$?

        if [ $exit_code -eq 0 ]; then
            break
        fi

        printf "Attempt $attempt failed! Retrying in $timeout seconds...\n"
        sleep $timeout
        attempt=$(( attempt + 1 ))
    done

    if [ $exit_code -ne 0 ]; then
        printf "Command $@ failed after $attempt attempts!\n"
    fi

    return $exit_code
}
export -f retry_command_lin
