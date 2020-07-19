#!/bin/bash

mc-monitor status --host localhost --port $SERVER_PORT
exit $?
