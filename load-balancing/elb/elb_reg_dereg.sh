#!/bin/bash
. $(dirname $0)/common_functions.sh
if [ "$#" -ne 1 ]; then
  error_exit "no instance ip provided"
fi

INSTANCE_IP_ADDRESS="$1"
INSTANCE_ID=$(get_instance_id_from_ip "$INSTANCE_IP_ADDRESS")
# if get id method didn't return successfully the ip was incorrect.
if [ $? != 0 ]; then
  error_exit "invalid ip address provided"
fi

msg "$INSTANCE_ID"
get_elb_list "$INSTANCE_ID"

deregister_from_all_elbs() {
  for elb in $ELB_LIST; do
    validate_elb "$INSTANCE_ID" "$elb"
    if [ $? != 0 ]; then
      msg "Error validating $elb; cannot continue with this LB"
      continue
    fi
    msg "Deregistering $INSTANCE_ID from $elb"
    deregister_instance $INSTANCE_ID $elb

    if [ $? != 0 ]; then
      error_exit "Failed to deregister instance $INSTANCE_ID from ELB $elb"
    fi
  done
  # Wait for all deregistrations to finish
  msg "Waiting for instance to de-register from its load balancers"
  for elb in $ELB_LIST; do
    wait_for_state $INSTANCE_ID "OutOfService" $elb
    if [ $? != 0 ]; then
      error_exit "Failed waiting for $INSTANCE_ID to leave $elb"
    fi
  done
  msg "Instance un-registered from all LB's in list."
}

reregister_to_all_elbs() {

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
  msg "Instance registered on all LB's in list."
}
