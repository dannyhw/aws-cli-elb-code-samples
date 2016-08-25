#!/bin/bash
#
# Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#  http://aws.amazon.com/apache2.0
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.

. $(dirname $0)/common_functions.sh

# Get current time
msg "Started $(basename $0) at $(/bin/date "+%F %T")"
start_sec=$(/bin/date +%s.%N)

if [ -z "$ELB_LIST" ]; then
    error_exit "ELB_LIST is empty. Must have at least one load balancer to register to, or \"_all_\", \"_any_\" values."
elif [ "${ELB_LIST}" = "_all_" ]; then
    if [ "$(get_flag "dereg")" = "true" ]; then
        msg "Finding all the ELBs that this instance was previously registered to"
        if ! ELB_LIST=$(get_flag "ELBs"); then
          error_exit "$FLAGFILE doesn't exist or is unreadble"
        elif [ -z $ELB_LIST ]; then
          error_exit "Couldn't find any. Must have at least one load balancer to register to."
        fi
    else
        msg "Assuming this is the first deployment and ELB_LIST=_all_ so finishing successfully without registering."
        finish_msg
        exit 0
    fi
elif [ "${ELB_LIST}" = "_any_" ]; then
    if [ "$(get_flag "dereg")" = "true" ]; then
        msg "Finding all the ELBs that this instance was previously registered to"
        if ! ELB_LIST=$(get_flag "ELBs"); then
            error_exit "$FLAGFILE doesn't exist or is unreadble"
        elif [ -z $ELB_LIST ]; then
            msg "Couldn't find any, but ELB_LIST=_any_ so finishing successfully without registering."
            remove_flagfile
            finish_msg
            exit 0
        fi
    else
        msg "Assuming this is the first deployment and ELB_LIST=_any_ so finishing successfully without registering."
        finish_msg
        exit 0
    fi
fi

# Loop through all LBs the user set, and attempt to register this instance to them.
for elb in $ELB_LIST; do
    msg "Checking validity of load balancer named '$elb'"
    validate_elb $INSTANCE_ID $elb
    if [ $? != 0 ]; then
        msg "Error validating $elb; cannot continue with this LB"
        continue
    fi

    msg "Registering $INSTANCE_ID to $elb"
    register_instance $INSTANCE_ID $elb

    if [ $? != 0 ]; then
        error_exit "Failed to register instance $INSTANCE_ID from ELB $elb"
    fi
done

# Wait for all registrations to finish
msg "Waiting for instance to register to its load balancers"
for elb in $ELB_LIST; do
    wait_for_state $INSTANCE_ID "InService" $elb
    if [ $? != 0 ]; then
        error_exit "Failed waiting for $INSTANCE_ID to return to $elb"
    fi
done

remove_flagfile

finish_msg
