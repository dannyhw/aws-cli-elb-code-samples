#!/bin/bash
. $(dirname $0)/test.sh $1
deregister_from_all_elbs
reregister_to_all_elbs
