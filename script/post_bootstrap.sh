#!/bin/bash
echo "\c template1
CREATE DATABASE $POSTGRES_DB;" \
|  psql -d $1 # $1 - connection string to the newly created master.