#!/bin/sh
set -e
mkdir -p .cache

# Daid's Game Boy emulator shootout
wget -O .cache/Daid-shootout.html https://daid.github.io/GBEmulatorShootout/

# Because of an unresolved incompatibility with GitHub Actions, mGBA
# is tested in a separate process
# 2021-01-02: Daid resolved this while adding KiGB
##wget -O .cache/Daid-shootout-mgba.html https://cdn.discordapp.com/attachments/327738013239083010/792385480766914600/results.html

