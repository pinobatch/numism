#!/bin/sh
set -e
mkdir -p .cache

# Download Erik Norvelle's lists
wget -O .cache/surnames-uk.txt https://github.com/smashew/NameDatabases/raw/master/NamesDatabases/surnames/uk.txt
wget -O .cache/surnames-us.txt https://github.com/smashew/NameDatabases/raw/master/NamesDatabases/surnames/us.txt
wget -O .cache/givennames-us.txt https://github.com/smashew/NameDatabases/raw/master/NamesDatabases/first%20names/us.txt
wget -O .cache/names1920s.html https://www.ssa.gov/oact/babynames/decades/names1920s.html
./htmltotsv.py .cache/names1920s.html .cache/names1920s.tsv
