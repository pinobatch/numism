#!/usr/bin/env python3
import os
import sys
import html5lib
from xml.etree import ElementTree as ET

"""
If you've found this, then you should help me report a bug in IDLE,
the official Python code editor.  In IDLE 3.8.5 on Python 3.8.5 in
Xubuntu 20.04 LTS, if you open a blank file and edit it, you might
not be able to save it because IDLE couldn't tell at load time
whether it originally used UNIX newlines or CP/M newlines.

touch something.py && idle something.py

Trying to File > Save or File > Save As produces an exception on stderr:

Exception in Tkinter callback
Traceback (most recent call last):
[snip]
  File "/usr/lib/python3.8/idlelib/iomenu.py", line 232, in writefile
    text = self.fixnewlines()
  File "/usr/lib/python3.8/idlelib/iomenu.py", line 252, in fixnewlines
    text = text.replace("\n", self.eol_convention)
TypeError: replace() argument 2 must be str, not None
"""

htmlns = {
    'html': 'http://www.w3.org/1999/xhtml',
}
ET.register_namespace('', "http://www.w3.org/1999/xhtml")

def eldump(el):
    print(ET.tostring(el, encoding="unicode"))

def iterdump(rows):
    print("\n".join(repr(row) for row in rows))

def destructive_iter(ls):
    """Destructive iterator over a mutable sequence.

Return each element of ls before setting it to None (and releasing it
to the garbage collector)."""
    for i in range(len(ls)):
        yield ls[i]
        ls[i] = None

def load_shootout(filename):
    """
Load an HTML file from Daid's Game Boy emulator shootout.

Return a 3-tuple (emunames, testnames, allresults) where
- emunames is [(name, num_tests_passed), ...]
- testnames is [testname, ...]
- allresults is {emuname: {testname: (True if passed, img[src]), ...}, ...}
"""
    with open(filename, "r", encoding="utf-8") as infp:
        doc = html5lib.parse(infp)

    # Find the table in this document with the most rows, where
    # a "row" is a tr child of a thead/tbody child of a table
    tables = (
        el.findall("./*/html:tr", htmlns)
        for el in doc.findall(".//html:table", htmlns)
    )
    table = max(tables, key=len)
    rowit = destructive_iter(table)
    doc = tables = table = None  # drop variables

    emunames = [th.text.split("(", 1) for th in next(rowit)][1:]
    emunames = [(l.rstrip(), int(r.split('/', 1)[0])) for l, r in emunames]
    allresults = {n: {} for n, _ in emunames}
    testnames = []

    for row in rowit:
        row = list(row)
        # To reduce excess width of the name column on the sub-1080p
        # displays in smaller laptops, the name in the table includes
        # a zero-width space after each slash.  It shifts the
        # limiting factor to channel_3_wave_ram_locked_write.gb
        testname = row[0].text.replace("\u200b", "")
        testnames.append(testname)
        for (emuname, _), result in zip(emunames, row[1:]):
            tpass, img = result.text, result.find("./html:img", htmlns)
            ispass = tpass.upper() == 'PASS'
            imsrc = img.get("src") if img is not None else None
            allresults[emuname][testname] = ispass, imsrc
    return emunames, testnames, allresults

def main(argv=None):
    mainshootout = load_shootout(".cache/Daid-shootout.html")
    mgba_extra = load_shootout(".cache/Daid-shootout-mgba.html")
    emunames, testnames, allresults = mainshootout
    emunames = [x for x in emunames if x[0] != 'mGBA']
    emunames.extend(mgba_extra[0])
    allresults.update(mgba_extra[2])
    del mgba_extra

    # Now make our own table based on this
    
if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main(["./htmltotsv.py", ".cache/names1920s.html", "-"])
    else:
        main()
