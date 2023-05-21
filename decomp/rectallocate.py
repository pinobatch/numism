#!/usr/bin/env python3
"""
Rectangular RAM allocator
Copyright 2023 Damian Yerrick
(insert zlib license here)
"""
import os, sys, argparse, re, warnings
from collections import namedtuple
from itertools import chain

# The enclosed instruction book and command line parsing ############

helpTop = """Allocates memory in 256-byte spaced arrays."""
version = '%(prog)s 0.01'

exampleFile = """; Example allocation definitions

; this 128 by 16 byte shelf has only a top track
shelf c080-cfff
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

; this 64 by 16 byte shelf has top and bottom tracks
shelf c040[16][64]
  array wRed[12][32]
  array wYellow[8][20]
  array wGreen[6][24]
  array wCyan[4][10]
  array wBlue[3][16]
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
processes records with more state variables.  These include a
character's position, velocity, frame of animation, health, and more.

Random reads and writes of members in a record, such as properties
of an actor in a game's actor pool, are slow on an 8080 processor.
Because the processor lacks an indexed addressing mode, it has to
calculate each member's address in software using add instructions,
which costs cycles and increases register pressure.  (Z80 adds an
indexed mode using a relatively slow prefixed encoding.  This is
absent on the original 8080 and the SM83.)

One workaround involves aligning records to start exactly 256 (0x100)
bytes apart in work RAM.  This means the low byte of the address of
a given property is the same across all records.  Given the high byte
of a record's address, the program can access a property by loading
the low byte of the address into an address register pair (BC, DE,
or HL) and reading or writing that address.

This approach requires work RAM's size to be at least 256 times the
count of records of any given type.  In practice, it works best
with 4 KiB or more work RAM, which is more than in ColecoVision,
SG-1000, or the Pac-Man arcade system.  Fortunately, the systems
that we target (MSX, Master System, Genesis sound, and Game Boy)
all have 8 KiB or more work RAM.
"""),
   ('lang', """Language to define allocations

Allocation is defined by a text file in a domain-specific language.
Indentation is not significant.  Text on each line starting with a
semicolon (`;`) is ignored as a comment.

    shelf c040[16][64]

The `shelf` command defines a rectangular subset of work RAM into
which arrays are placed.  Its argument is a hexadecimal start address
followed by the height in rows and width in bytes in square brackets.
For example, `c040[16][64]` defines a shelf consisting of address
ranges C040-C07F, C140-C17F, C240-C27F, ..., CF40-CF7F, or 16 rows
by 64 bytes per row.

    shelf c040-cf7f

This equivalent form defines a shelf by its top left and bottom right
corner addresses as hexadecimal numbers separated by a hyphen.

    array wActors[12][32]

The `array` command adds a rectangle of 12 rows, each 32 bytes long,
to the most recent shelf.  Arrays are packed along the top and bottom
of a shelf.  Their widths must not exceed twice the width of the
shelf.  If you have more arrays than that, make an additional shelf.

There's no way to align a single array at an address with a given
number of zero least significant bits, such as 5 bits (32-byte
alignment).  The easiest way to do that is to make a separate shelf
for arrays sensitive to alignment.

    words 1, YPos         ;  2 bytes
    words XPos            ;  2 bytes
    bytes 1, YSize        ;  1 byte
    bytes XSize           ;  1 byte
    bytes 6, Name         ;  6 bytes
    alias Money           ;  0 bytes
    words Target          ;  2 bytes
    longs 4, MovementData ; 16 bytes

Optionally, the `bytes`, `words`, and `longs` commands can be used
to define the address of a number of 1-byte, 2-byte, or 4-byte fields
within a row.  (This syntax is inspired by ISSOtm's rgbds-structs
macro pack.)  For example, when a field named `XPos` is added to an
array named `wActors`, the label `wActors_XPos` is defined as the
starting address of the `XPos` field of the first row of the array,
and code can use `ld l, low(wActors_YPos)` to seek to this field.
Each field name may be preceded by a count and a comma.  The `alias`
command allocates a 0-byte field, which can be used as an alias for
the following field or as an end label for the preceding field.
"""),
    ('example', exampleFile),
]

class ManualAction(argparse.Action):

    def __init__(self, option_strings, dest=argparse.SUPPRESS,
                 default=argparse.SUPPRESS, choices=[],
                 help="show manual page and exit"):
        super(ManualAction, self).__init__(
            option_strings=option_strings, dest=dest, default=default,
            nargs='?', choices=choices, help=help
        )

    def __call__(self, parser, namespace, values, option_string=None):
        if values is None:
            print("Available manual pages")
            for name, txt in manual_pages:
                txt = txt.split("\n", 1)[0].strip()
                print("    --manual %-20s%s" % (name, txt))
        else:
            candidates = [
                row for row in manual_pages if row[0].startswith(values)
            ]
            if len(candidates) == 0:
                parser.error("no such page %s; try %s --manual"
                             % (values, parser._prog))
            if len(candidates) > 1:
                parser.error("ambiguous title %(values)s matches %(matches)s; try %(prog)s --manual"
                             % {'values': values, 'prog': parser._prog,
                                'matches': ', '.join(name for name, txt in candidates)})
            sys.stdout.write(candidates[0][1])
        parser.exit()

def parse_argv(argv):
    manual_page_names = [name for name, contents in manual_pages]
    p = argparse.ArgumentParser(description=helpTop)
    p.add_argument("--manual", action=ManualAction, choices=manual_page_names,
                   help="print a page from the manual or a list of pages and exit")
    p.add_argument("input",
                   help="array definitions file "
                   "(- for stdin, example for test file)")
    p.add_argument("-o", "--output", default="-",
                   help="write assembly language output here "
                   "(default: - for stdout)")
    p.add_argument("-v", "--verbose", action="store_true",
                   help="write intermediate results to stderr")
    return p.parse_args(argv[1:])

# Parsing definitions ###############################################

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
shelfWidthHeightRE = re.compile(r"""
(\$?[0-9a-f]+)                                    # base
\s*\[\s*(0x[0-9a-f]+ | \$[0-9a-f]+ | [0-9]+)\s*]  # height
\s*\[\s*(0x[0-9a-f]+ | \$[0-9a-f]+ | [0-9]+)\s*]  # width
""", re.VERBOSE|re.IGNORECASE)
bytes_sizes = {'bytes': 1, 'words': 2, 'longs': 4, 'alias': 0}

def parse_int(s):
    if s.startswith("0x"): return int(s[2:], 16)
    if s.startswith("$"): return int(s[1:], 16)
    return int(s, 10)

def parse_shelf_rect(s):
    start_end = [x.strip() for x in s.split('-', 1)]
    if len(start_end) == 2:
        start, end = (int(x.lstrip('$'), 16) for x in start_end)
        starthi, startlo = start // 0x100, start % 0x100
        endhi, endlo = end // 0x100, end % 0x100
        if starthi > endhi:
            raise ValueError("shelf start high byte %2x is more than end high byte %2x"
                             % (starthi, endhi))
        if startlo > endlo:
            raise ValueError("shelf start low byte %2x is more than end low byte %2x"
                             % (startlo, endlo))
        width, height = endlo - startlo + 1, endhi - starthi + 1
        return startlo, starthi, width, height

    m = shelfWidthHeightRE.fullmatch(s)
    if m is not None:
        start, height, width = m.groups()
        start = int(start, 16)
        starthi, startlo = start // 0x100, start % 0x100
        height = parse_int(height)
        width = parse_int(width)
        return startlo, starthi, width, height

    raise ValueError("expected addr-addr or addr[height][width]; got %s"
                     % (s,))

def load_shelves_file(lines):
    shelves = []
    for linenum, line in enumerate(lines):
        line = line.split(';', 1)[0].strip().split(None, 1)
        if not line: continue
        if line[0] == 'shelf':
            try:
                result = parse_shelf_rect(line[1])
                startlo, starthi, width, height = result
            except Exception as e:
                raise ValueError("%d: %s" % (linenum + 1, str(e)))
            shelves.append(ShelfCmd(
                linenum=linenum, arrays=[], left=startlo, top=starthi,
                width=width, height=height
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

# Packing the rectangles ############################################
#
# Based on the algorithm that David Colson calls PackRectsNaiveRows:
# sort the rectangles by decreasing height then pack each onto the
# first row with room.
# https://www.david-colson.com/2020/03/10/exploring-rect-packing.html
#
# This "ridiculously simple" algorithm makes rows roughly trapezoidal
# in shape, with three rectilinear sides and the fourth with stairs.
# Packing a second row upside down lets us mate the rows' stairs
# together, and then we push the two together until they touch.
#
# Want more rows? Add more shelves!

PackShelfResult = namedtuple("PackShelfResult", [
    "top_arrays", "bottom_arrays", "min_gap", "closest_pair"
])
PackShelfArray = namedtuple("PackShelfArray", [
    "array", "left", "top", "right", "bottom"
])

def pack_shelf(shelf):
    # sort arrays in this shelf by decreasing height
    arrays = sorted(shelf.arrays,
                    key=lambda x: (x.height, x.width), reverse=True)
    if len(arrays) == 0:
        return PackShelfResult([], [], shelf.height, (None, None))

    # pack the arrays into the top or bottom track, first fit
    # top track is pressed against the top left of the shelf
    # bottom track is pressed against the bottom right of the shelf
    top_arrays, top_width, bottom_arrays, bottom_width = [], 0, [], 0
    for array in arrays:
        if array.width + top_width <= shelf.width:
            l, t, b = top_width, 0, array.height
            top_width += array.width
            r = top_width
            top_arrays.append(PackShelfArray(array, l, t, r, b))
        elif array.width + bottom_width <= shelf.width:
            r, b = shelf.width - bottom_width, shelf.height
            l, t = r - array.width, b - array.height
            bottom_arrays.append(PackShelfArray(array, l, t, r, b))
            bottom_width += array.width
        else:
            raise ValueError("%d: array size %d does not fit on shelf's top (%d/%d used) or bottom (%d/%d used)"
                             % (array.linenum, array.width, top_width, shelf_width, bottom_width, shelf_width))

    # find the smallest gap between the tracks
    closest_top = max(top_arrays, key=lambda x: x.array.height)
    min_gap, closest_bottom = shelf.height - closest_top.array.height, None
    for bottom in bottom_arrays:
        for top in top_arrays:
            if bottom.right <= top.left or top.right <= bottom.left:
                continue  # not vertically aligned
            gap = bottom.top - top.bottom
            if gap < min_gap:
                closest_top, closest_bottom, min_gap = top, bottom, gap

    # if there's room, push them together to give RGBLINK more room
    # to automatically place 1D arrays
    if min_gap > 0:
        bottom_arrays = [
            PackShelfArray(a, l, t - min_gap, r, b - min_gap)
            for a, l, t, r, b in bottom_arrays
        ]

    return PackShelfResult(
        top_arrays, bottom_arrays, min_gap, (closest_top, closest_bottom)
    )

# Output ############################################################

def print_packing(arrays, file=sys.stdout):
    print("\n".join(
        "    %s: (%d, %d)-(%d, %d)" % (a.name, l, t, r, b)
        for a, l, t, r, b in arrays
    ), file=file)

def print_pack_shelf_result(packing, file=sys.stdout):
    print("top track:", file=file)
    print_packing(packing.top_arrays, file=file)
    if packing.bottom_arrays:
        print("bottom track:", file=file)
        print_packing(packing.bottom_arrays, file=file)
    print("slack rows: %d\nclosest pair:"
          % (packing.min_gap,), file=file)
    print_packing((x for x in packing.closest_pair if x), file=file)

def emit_packing(shelf, packing):
    lines = []
    shelf_base = shelf.top * 0x100 + shelf.left
    lines.append(
        "; shelf %04x-%04x"
        % (shelf_base,
           shelf_base + (shelf.height - 1) * 0x100 + shelf.width - 1)
    )
    if packing.min_gap > 0:
        rows_pl = "rows of slack" if packing.min_gap > 1 else "row of slack"
        lines.append(
            "; actual: %04x-%04x after removing %d %s"
            % (shelf_base,
               shelf_base + (shelf.height - packing.min_gap - 1) * 0x100
                          + shelf.width - 1,
               packing.min_gap, rows_pl)
        )

    # Form diagram comment
    dots = b'.' * shelf.width
    diagram = [bytearray(dots) for b in range(shelf.height - packing.min_gap)]
    for el in chain(packing.top_arrays, packing.bottom_arrays):
        # Draw side borders
        for y in range(el.top + 1, el.bottom - 1):
            diagram[y][el.right - 1] = diagram[y][el.left] = b'|'[0]
        # Format top and bottom borders
        if el.right - el.left > 2:
            bottomline = (b'-' * (el.right - el.left - 2))
            bottomline = bottomline.join((b"+", b"+"))
            topline = bytearray(bottomline)
            bname = el.array.name.encode("ascii", errors="ignore")
            bname = bname[:el.right - el.left - 2]
            topline[1:1 + len(bname)] = bname
            topline = bytes(topline)
        else:
            topline = bottomline = '+' * (el.right - el.left)
        assert len(topline) == len(bottomline) == el.array.width
        diagram[el.bottom - 1][el.left:el.right] = bottomline
        diagram[el.top][el.left:el.right] = topline
    lines.extend("; " + line.decode("ascii") for line in diagram)

    # Allocate rows and write labels associated with each array
    for el in chain(packing.top_arrays, packing.bottom_arrays):
        base_addr = shelf_base + el.top * 0x100 + el.left
        sect_name = "WRAMX" if base_addr >= 0xD000 else "WRAM0"
        sect_suffix = ", BANK[1]" if base_addr >= 0xD000 else ""
        for i in range(el.array.height):
            lines.append('SECTION "%s_row%02x", %s[$%04x]%s'
                         % (el.array.name, i,
                            sect_name, base_addr + i * 0x100, sect_suffix))
            if i == 0: lines.append("%s::" % (el.array.name,))
            lines.append(" ds %d" % (el.array.width,))
        cumul_width = 0
        for label in el.array.labels:
            labelname = "%s_%s" % (el.array.name, label.name)
            lines.append("def %s equ $%04x"
                         % (labelname, base_addr + cumul_width))
            lines.append("export %s" % labelname)
            cumul_width += label.width
    return lines

def main(argv=None):
    args = parse_argv(argv or sys.argv)
    if args.input == '-':
        shelves = load_shelves_file(stdin)
    elif args.input == 'example':
        shelves = load_shelves_file(exampleFile.split("\n"))
    else:
        with open(args.input, "r", encoding="utf-8") as infp:
            shelves = load_shelves_file(infp)

    # Pack each shelf
    lines = []
    for shelf in shelves:
        packing = pack_shelf(shelf)
        if args.verbose:
            print("shelf at line %d" % (shelf.linenum + 1,), file=sys.stderr)
            print_pack_shelf_result(packing, file=sys.stderr)
        if packing.min_gap < 0:
            raise ValueError("top track overlaps bottom track by %d; add more rows"
                             % (-packing.min_gap,))
        lines.extend(emit_packing(shelf, packing))

    linesn = (line + "\n" for line in lines)
    if args.output == '-':
        sys.stdout.writelines(linesn)
    else:
        with open(args.output, "w", encoding="utf-8") as outfp:
            outfp.writelines(linesn)

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main("""
./rectallocate.py -v example
""".split())
    else:
        main()
