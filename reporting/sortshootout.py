#!/usr/bin/env python3
import os
import sys
import html5lib
from xml.etree import ElementTree as ET
import subprocess
from html import escape as H

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

stylesheet = """
table { border-collapse: collapse }
td, th { border: #333 solid 1px; text-align: center; line-height: 1.5}
.PASS { background-color: #6e2 }
.FAIL { background-color: #e44 }
.UNKNOWN { background-color: #fd6 }
td { font-size:80% }
th { background:#eee }
th:first-child { text-align:right; padding-right:4px }
body { font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif }

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

def xdg_open(filename):
    if os.name == 'nt':
        args = ["start", "", filename]
    else:
        args = ["xdg-open", filename]
    subprocess.run(args)

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

def input_emu(prompt, emunames):
    xprompt = "\n".join(
        "%4d: %s (%d)" % (i + 1, n, c) for i, (n, c) in enumerate(emunames)
    )
    xprompt = "\n".join((
        prompt, xprompt, "Enter a number from 1 to %s:" % len(emunames)
    ))
    while True:
        num = input(xprompt).strip()
        if num == '': return None
        try:
            num = int(num)
        except ValueError:
            print("%s: not a whole number" % num)
            continue
        if not 1 <= num <= len(emunames):
            print("%s: not in range 1 to %d" % (num, len(emunames)))
            continue
        return num - 1

def shootoutkey(row, col1=None, coldiff=None):
    """Calculate key for sorting a shootout.

row - a tuple (testname, results) where results is [(passing, ...), ...]
and passing is a truthy or falsy value.
col1 and col2 - indices into results

Return a tuple (col12same, col1fail, failcount) where
- col1fail is 0 if results[col1] passes else 1
- col12same is 1 if passing for results[col1] and results[col2]
  have same truthiness
"""
    testname, results = row
    fails = [0 if x[0] else 1 for x in results]
    col1fail = 0 if col1 is None else fails[col1]
    col2fail = 0 if coldiff is None else fails[coldiff]
    return col2fail == col1fail, col1fail, sum(fails)

def format_row(row, emunames):
    """
row - a tuple (testname, [(passing, imgsrc), ...])
"""
    testname, results = row
    out = ["<tr>\n  <th>", H(testname.replace("/", "/\u200b")), "</th>\n"]
    for (emuname, _), (passing, imgsrc) in zip(emunames, results):
        classname = "PASS" if passing else "FAIL"
        out.append('  <td class="%s">%s<br><img src="%s" title="%s %s"></td>\n'
                   % (classname, classname, imgsrc, emuname, classname))
    out.append("</tr>\n")
    return "".join(out)

def main(argv=None):
    mainshootout = load_shootout(".cache/Daid-shootout.html")
    mgba_extra = load_shootout(".cache/Daid-shootout-mgba.html")
    emunames, testnames, allresults = mainshootout
    emunames = [x for x in emunames if x[0] != 'mGBA']
    emunames.extend(mgba_extra[0])
    allresults.update(mgba_extra[2])
    del mgba_extra

    print("Sorting tests based on decreasing pass rate")
    print("Optional: Choose emulators that one or two pass")
    col1emu = input_emu("Choose an emulator for column 1", emunames)
    col2emu = (input_emu("Choose an emulator for column 2", emunames)
               if col1emu is not None
               else None)
    new_emunames = []
    if col1emu is not None: new_emunames.append(emunames[col1emu])
    if col2emu is not None: new_emunames.append(emunames[col2emu])
    new_emunames.extend(x for i, x in enumerate(emunames)
                        if i != col1emu and i != col2emu)
    emunames = None
    rows = [
        (testname, [allresults[e[0]][testname] for e in new_emunames])
        for testname in testnames
    ]
    col1ok = 0 if col1emu is not None else None
    col2ok = 1 if col2emu is not None else None
    rows.sort(key=lambda row: shootoutkey(row, col1ok, col2ok))
    # rows is of the form
    # [(testname, [(passing, image), ...]), ...]

    # Now make our own table based on this
    title = ("Shootout: %s vs. %s" % (new_emunames[0][0], new_emunames[1][0])
             if col2ok is not None
             else "Shootout: %s vs. other emulators" % (new_emunames[0][0])
             if col1ok is not None
             else "Game Boy emulator shootout")
    out = [
        """<!DOCTYPE HTML><html><head><meta charset="utf-8"><title>""",
        H(title),
        """</title><style type="text/css">""",
        stylesheet,
        """</style></head><body><h1>""",
        H(title),
        """</h1>
<p>
Based on a data set by Daid.
</p><table id="results"><thead>\n<tr><th>Name of test</th>"""
    ]

    out.extend("<th>%s (%d)</th>" % row for row in new_emunames)
    out.append("</tr>\n</thead><tbody>\n")
    print("".join(out))
    out.extend(format_row(row, new_emunames) for row in rows)
    out.append("</tbody></table></body></html>")

    outfilename = "sortshootout.html"
    with open(outfilename, "w", encoding="utf-8") as outfp:
        outfp.writelines(out)
    xdg_open(outfilename)
    
if __name__=='__main__':
    if 'idlelib' in sys.modules:
        main(["./htmltotsv.py", ".cache/names1920s.html", "-"])
    else:
        main()
