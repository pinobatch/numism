#!/usr/bin/env python3
import sys
import csv
import io
import html5lib
from xml.etree import ElementTree as ET

htmlns = {
    'html': 'http://www.w3.org/1999/xhtml',
}
ET.register_namespace('', "http://www.w3.org/1999/xhtml")

def eldump(el):
    print(ET.tostring(el, encoding="unicode"))

def iterdump(rows):
    print("\n".join(repr(row) for row in rows))

def main(argv=None):
    argv = argv or sys.argv
    if len(argv) < 2:
        if len(argv) > 1 and argv[1] in ['-h', '--help', '-?', '/?']:
            print("usage: htmltotsv.py INFILE.html OUTFILE.tsv\n"
                  "extracts the <table> with most rows from HTML and writes out tab-separated")
            return
        print("htmltotsv.py: missing filenames; try htmltotsv.py -h",
              file=sys.stderr)
        exit(1)
        
    infilename = argv[1]
    outfilename = argv[2] if len(argv) > 2 else '-'
    body = open(infilename, "r")
    doc = html5lib.parse(body)

    # Find the table in this document with the most rows, where
    # a "row" is a tr child of a thead/tbody child of a table
    tables = doc.findall(".//html:table", htmlns)
    table = max(tables, key=lambda x: len(x.findall("./*/html:tr", htmlns)))

    # Pull all headings and all data values
    # Prefixes (e.g. "male" for "male count" and "male name") appear
    # in the previous row; can disregard because the full heading
    # with prefix appears in the heading cell's abbr= attribute
    headrows = table.findall("./html:thead/html:tr", htmlns)
    headings = max(headrows, key=len)
    headings = [(td.get("abbr") or td.text).strip().lower()
                for td in headings]

    # eliminate rows that aren't as long as headings, such as a
    # notice that the source is the Social Security Administration
    bodyrows = table.findall("./html:tbody/html:tr", htmlns)
    bodyrows = [[(td.text or "").strip() for td in row]
                for row in bodyrows
                if len(row) == len(headings)]

    # Write them out in Pino's favorite format for tabular data since
    # he started working at a radio control car and tabletop game
    # shop in 2007: tab-separated.
    outfp = (open(outfilename, "w", newline='') if outfilename != ''
             else sys.stdout if 'idlelib' in sys.modules
             else io.TextIOWrapper(sys.stdout.buffer, newline=""))
    writer = csv.writer(outfp, "excel-tab")
    writer.writerow(headings)
    writer.writerows(bodyrows)
    outfp.close()

if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main(["./htmltotsv.py", ".cache/names1920s.html", "-"])
    else:
        main()
