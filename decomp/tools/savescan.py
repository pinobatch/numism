#!/usr/bin/env python3
"""
Static Automatic Variable Earmarker (S.A.V.E.)

Copyright 2023 Damian Yerrick
[insert zlib license here]
"""
import os, sys, argparse, re, glob

def parse_argv(argv):
    p = argparse.ArgumentParser()
    p.add_argument("asmfile", nargs="+",
                   help="assembly language source file")
    return p.parse_args(argv[1:])

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    print(args)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        import glob
        argv = ['./savescan.py']
        argv.extend(glob.glob("../src/*.asm"))
        main(argv)
    else:
        main()
