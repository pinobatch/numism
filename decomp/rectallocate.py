#!/usr/bin/env python3
"""
Rectangular RAM allocator
Copyright 2023 Damian Yerrick
(insert zlib license here)
"""
import os, sys, argparse, re
from collections import namedtuple
try:
    from PIL import Image
except ImportError:
    Image = None

# The enclosed instruction book #####################################

helpTop = """Allocates memory in 256-byte spaced arrays."""
version = '%(prog)s 0.01'

exampleFile = """; Example configuration file

shelf c040-cfff
  array wActors[12][24]
    bytes class
    bytes frame
    bytes 2, timers
    words dx
    words x
    words dy
    words y
    bytes facing
    bytes health
  array mapVicinity[16][16]
    
"""

manual_pages = [
    ('about8080', """About the 8080

The Zilog Z80 CPU in a Master System console or MSX computer and the
Sharp SM83 CPU in a Game Boy compact video game system are based on
the Intel 8080 CPU.  This early 8-bit microprocessor saw use in 1970s
video terminals, such as the Digital VT102.  The majority of the
8080's instruction set is a rearrangement of that of the Datapoint
2200 programmable terminal.

A terminal deals mostly with a screen's worth of tilemap data.
Each element in a tilemap may have a character ID and an attribute,
not a particularly complex structure.  A real-time game, by contrast,
also processes actors with more state variables.  These include a
character's position, velocity, frame of animation, health, and more.

Random reads and writes of members in a record, such as properties
of an actor in a game's actor pool, are slow on an 8080 processor.
This is because the processor lacks an indexed addressing mode and
thus has to calculate each member's address in software using add
instructions.  (Z80 adds an indexed mode using a relatively slow
prefixed encoding. This is absent on the original 8080 and the SM83.)

One workaround involves aligning the actors to start exactly 256
bytes apart in work RAM.  This means the low byte of the address of
a given property is the same across all actors.  Given the high byte
of an actor's address, the program can access a property by loading
the low byte of the address into an address register pair (BC, DE, or
HL) and reading or writing that address.

This approach requires work RAM's size to be at least 256 times the
entity count.  In practice, it works best with at least 4 KiB of work
RAM, which is more than in ColecoVision, SG-1000, or the Pac-Man
arcade system.)  Fortunately, the systems that we target (Master
System, Genesis sound, and Game Boy) all have 8 KiB of work RAM.
"""),
   ('lang', """Configuration language

Allocation is defined by a text file in a domain-specific language.
Indentation is not significant.  Text on each line starting with a
semicolon (`;`) is ignored as a comment.

    shelf c040-cfff       ; variables to put in unswitched work RAM

The `shelf` command defines a rectangular subset of work RAM into
which arrays are placed.  The following 4-digit hexadecimal numbers
separated by a hyphen specify its top left and bottom right corners.
For example, `shelf c040-cfff` defines a shelf consisting
of address ranges C040-C0FF, C140-C1FF, C240-C2FF, ..., CF40-CFFF.

    array wActors[12][32]

The `array` command adds a rectangle of 12 rows, each 32 bytes long,
to the most recent shelf.

    words 1, YPos         ;  2 bytes
    words XPos            ;  2 bytes
    bytes 1, YSize        ;  1 byte
    bytes XSize           ;  1 byte
    bytes 6, Name         ;  6 bytes
    alias Money           ;  0 bytes
    words Target          ;  2 bytes
    longs 4, MovementData ; 16 bytes

Optionally, the `bytes`, `words`, and `longs` commands can be used
to define the address of 1-byte, 2-byte, or 4-byte fields within a
row.  (This syntax is inspired by ISSOtm's rgbds-structs macro pack.)
For example, when a field named `XPos` is added to an array named
`wActors`, the label `wActors_XPos` is defined as the starting
address of the `XPos` field of the first row of the array, and code
can use `ld l, low(wActors_YPos)` to seek to this field.  Each field
name may be preceded by a count and a comma.  The `alias` command
allocates a 0-byte field, which can be used as an alias for the
following field or as an end label for the preceding field.
"""),
    ('example', exampleFile),
]

class ManualAction(argparse.Action):

    def __init__(self,
                 option_strings,
                 dest=argparse.SUPPRESS,
                 default=argparse.SUPPRESS,
                 choices=[],
                 help="show manual page and exit"):
        super(ManualAction, self).__init__(
            option_strings=option_strings,
            dest=dest,
            default=default,
            nargs='?',
            choices=choices,
            help=help)

    def __call__(self, parser, namespace, values, option_string=None):
        if values is None:
            print("Available manual pages")
            for name, txt in manual_pages:
                txt = txt.split("\n", 1)[0].strip()
                print("    --manual %-20s%s" % (name, txt))
        else:
            candidates = [
                (name, txt) for name, txt in manual_pages
                if name.startswith(values)
            ]
            if len(candidates) == 0:
                parser.error("no such page %(values)s; try %(prog)s --manual"
                             % {'values': values, 'prog': parser._prog})
            if len(candidates) > 1:
                parser.error("ambiguous title %(prog)s matches %(matches)s; try %(prog)s --manual"
                             % {'values': values, 'prog': parser._prog,
                                'matches': ', '.join(name for name, txt in candidates)})
            sys.stdout.write(candidates[0][1])
        parser.exit()

def parse_argv(argv):
    manual_page_names = [name for name, contents in manual_pages]
    p = argparse.ArgumentParser(description=helpTop)
    p.add_argument("--manual", action=ManualAction, choices=manual_page_names,
                   help="print a page from the manual and exit")
    p.add_argument("input", help="configuration file")
    p.add_argument("-o", "--output", default="-",
                   help="output file in assembly language")
    return p.parse_args(argv[1:])

# File parsing ######################################################

ShelfCmd = namedtuple('ShelfCmd', [
    'linenum', 'left', 'top', 'width', 'height', 'arrays'
])
ArrayCmd = namedtuple('ArrayCmd', [
    'linenum', 'name', 'width', 'height', 'labels'
])
BytesCmd = namedtuple('BytesCmd', [
    'linenum', 'name', 'width'
])
declRE = re.compile(r"""
([a-z_][\w]*)                                     # name
\s*\[\s*(0x[0-9a-f]+ | \$[0-9a-f]+ | [0-9]+)\s*]  # height
\s*\[\s*(0x[0-9a-f]+ | \$[0-9a-f]+ | [0-9]+)\s*]  # width
""", re.VERBOSE|re.IGNORECASE)
bytes_sizes = {'bytes': 1, 'words': 2, 'longs': 4, 'alias': 0}

def parse_int(s):
    if s.startswith("0x"): return int(s[2:], 16)
    if s.startswith("$"): return int(s[1:], 16)
    return int(s, 10)

def load_shelves_file(lines):
    shelves = []
    for linenum, line in enumerate(lines):
        line = line.split(';', 1)[0].split(None, 1)
        if not line: continue
        if line[0] == 'shelf':
            start_end = [x.strip() for x in line[1].split('-', 1)]
            if len(start_end) != 2:
                raise ValueError("%d: expected two addresses separated by -; got %s"
                                 % (linenum + 1, line[1]))
            start, end = (int(x, 16) for x in start_end)
            starthi, startlo = start // 0x100, start % 0x100
            endhi, endlo = end // 0x100, end % 0x100
            if starthi > endhi:
                raise ValueError("%d: shelf start high byte %2x is more than end high byte %2x"
                                 % (linenum + 1, starthi, endhi))
            if startlo > endlo:
                raise ValueError("%d: shelf start low byte %2x is more than end low byte %2x"
                                 % (linenum + 1, startlo, endlo))
            shelves.append(ShelfCmd(
                linenum=linenum, arrays=[], left=startlo, top=starthi,
                width=endlo - startlo + 1, height=endhi - starthi + 1
            ))
            continue

        if line[0] == 'array':
            m = declRE.fullmatch(line[1])
            if m is None:
                raise ValueError("%d: expected name[height][width]; got %s"
                                 % (linenum + 1, line[1]))
            if len(shelves) == 0:
                raise ValueError("%d: no shelf declared" % (linenum + 1,))
            name = m.group(1)
            height = parse_int(m.group(2))
            width = parse_int(m.group(3))
            if height > shelves[-1].height:
                raise ValueError("%d: array %s height %d exceeds shelf height %s"
                                 % (linenum + 1, name,
                                    height, shelves[-1].height))
            shelves[-1].arrays.append(ArrayCmd(
                linenum=linenum, labels=[], name=name,
                height=height, width=width
            ))
            continue

        try:
            bytes_size = bytes_sizes[line[0]]
        except KeyError:
            raise ValueError("%d: unknown command %s" % (linenum + 1, line[0]))
        count_name = [x.strip() for x in line[1].rsplit(',', 1)]
        name = count_name[-1]
        if bytes_size == 0 and len(count_name) > 1:
            raise ValueError("%d: alias does not take a count %s"
                             % (linenum + 1, count_name[0]))
        count = parse_int(count_name[0]) if len(count_name) > 1 else 1
        if count < 0:
            raise ValueError("%d: %s: expected positive count but got %d"
                             % (linenum + 1, name, count))
        width = count * bytes_size

        if len(shelves) == 0:
            raise ValueError("%d: no shelf declared" % (linenum + 1,))
        if len(shelves[-1].arrays) == 0:
            raise ValueError("%d: no array declared in this shelf"
                             % (linenum + 1,))
        arr = shelves[-1].arrays[-1]
        arr.labels.append(BytesCmd(linenum, name, width))
        cumul_width = sum(l.width for l in arr.labels)
        if cumul_width > arr.width:
            raise ValueError("%d: %s: total field width %d exceeds array width %d"
                             % (linenum + 1, cumul_width, arr.width))

    return shelves

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    print("args is", repr(args))
    shelves = load_shelves_file(exampleFile.split("\n"))
    print(shelves)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("""
./rectallocate.py /dev/null
""".split())
    else:
        main()
