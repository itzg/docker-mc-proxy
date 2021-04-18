#!/bin/bash

mc-monitor status --host ${HEALTH_HOST:-localhost} --port $SERVER_PORT
exit $?
