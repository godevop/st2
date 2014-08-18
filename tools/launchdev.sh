#!/bin/bash

if [ "$#" -ne 1 ] || ([ ${1} != "start" ] && [ ${1} != "stop" ]) ; then
  echo "Usage: $0 [start|stop]" >&2
  exit 1
fi

if [[ ${1} == "start" ]]; then

    echo "Starting all st2 servers..."

    # Determine where the stanley repo is located. Some assumption is made here
    # that this script is located under stanley/tools.

    COMMAND_PATH=${0%/*}
    CURRENT_DIR=`pwd`

    if [[ (${COMMAND_PATH} == /*) ]] ;
    then
        ST2_REPO=${COMMAND_PATH}/..
    else
        ST2_REPO=${CURRENT_DIR}/${COMMAND_PATH}/..
    fi

    # Change working directory to the root of the repo.
    ST2_REPO=`realpath ${ST2_REPO}`
    echo "Changing working directory to ${ST2_REPO}..."
    cd ${ST2_REPO}

    # Copy and overwrite the action contents
    mkdir -p /opt/stackstorm
    cp -Rp ./contrib/core/actions /opt/stackstorm 

    # activate virtualenv to set PYTHONPATH
    source ./virtualenv/bin/activate

    # Kill existing st2 screens
    screen -ls | grep st2 &> /dev/null
    if [ $? == 0 ]; then
        echo 'Killing existing st2 screen sessions...'
        screen -ls | grep st2 | cut -d. -f1 | awk '{print $1}' | xargs kill
    fi

    # Run the datastore API server
    echo 'Starting screen session st2-datastore...'
    screen -d -m -S st2-datastore ./virtualenv/bin/python \
        ./st2datastore/bin/datastore_controller \
        --config-file ./conf/stanley.conf

    # Run the action runner API server
    echo 'Starting screen session st2-actionrunner...'
    screen -d -m -S st2-actionrunner ./virtualenv/bin/python \
        ./st2actionrunnercontroller/bin/actionrunner_controller \
        --config-file ./conf/stanley.conf

    # Run the action API server
    echo 'Starting screen session st2-action...'
    screen -d -m -S st2-action ./virtualenv/bin/python \
        ./st2actioncontroller/bin/action_controller \
        --config-file ./conf/stanley.conf

    # Run the reactor server
    echo 'Starting screen session st2-reactor...'
    screen -d -m -S st2-reactor ./virtualenv/bin/python \
        ./st2reactor/bin/sensor_container \
        --config-file ./conf/stanley.conf

    # Run the reactor API server
    echo 'Starting screen session st2-reactorcontroller...'
    screen -d -m -S st2-reactorcontroller ./virtualenv/bin/python \
        ./st2reactorcontroller/bin/reactor_controller \
        --config-file ./conf/stanley.conf

    # Check whether screen sessions are started
    screens=(
        "st2-datastore"
        "st2-action"
        "st2-actionrunner"
        "st2-reactor"
        "st2-reactorcontroller"
    )

    echo
    for s in "${screens[@]}"
    do
        screen -ls | grep "${s}[[:space:]]" &> /dev/null
        if [ $? != 0 ]; then
            echo "ERROR: Unable to start screen session for $s."
        fi
    done

    # List screen sessions
    screen -ls

elif [[ ${1} == "stop" ]]; then

    screen -ls | grep st2 &> /dev/null
    if [ $? == 0 ]; then
        echo 'Killing existing st2 screen sessions...'
        screen -ls | grep st2 | cut -d. -f1 | awk '{print $1}' | xargs kill
    fi

fi