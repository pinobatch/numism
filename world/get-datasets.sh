#!/bin/sh
set -e
mkdir -p .cache

# Download Erik Norvelle's lists
wget -O .cache/surnames-uk.txt https://github.com/smashew/NameDatabases/raw/master/NamesDatabases/surnames/uk.txt
wget -O .cache/surnames-us.txt https://github.com/smashew/NameDatabases/raw/master/NamesDatabases/surnames/us.txt
wget -O .cache/givennames-us.txt https://github.com/smashew/NameDatabases/raw/master/NamesDatabases/first%20names/us.txt

