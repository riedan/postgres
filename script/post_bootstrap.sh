#!/bin/bash
echo "CREATE DATABASE $POSTGRES_DB;" |  psql "$1" # $1 - connection string to the newly created master.