#!/usr/bin/env python3
"""
Surname generator

Say you have a phrase, and you want to find a character name that is
an anagram to this phrase.

Mortality -> Tim Taylor
Jolly trail -> Jill Taylor
I am Lord Voldemort -> Tom Marvolo Riddle

I model this by building a Markov model out of a surname database,
finding all paths that use the letters in the phrase minus a given
name, and sorting them by the fewest bits used.

There are surname databases at
https://github.com/smashew/NameDatabases/tree/master/NamesDatabases/surnames
I use the Britain and America data sets (uk.txt and us.txt).

"""
import sys
from collections import defaultdict, Counter
from math import log2
from heapq import heappush, heappop
import csv

# First run one of these
#     sort(ls): fully sort ls in O(n*log(n)) time
#     heapify(ls): sort ls enough to make heappop() work in O(n) time
# Then you can use these in O(log(n)) time
#     heappush(ls, item): insert item into priority queue
#     item = heap[0]: peek least item
#     item = heappop(ls): remove least item
#     item = heappushpop(heap, item)  # heappush then heappop but faster
#     item = heapreplace(heap, item)  # heappop then heappush but faster

# A Markov model is a map from 2-grams to the information associated
# with each next letter, where information in bits is the negative
# logarithm of probability.  After choosing an initial letter, find
# paths through the remaining letters with lower probability.

CTXSIZE=3  # more context means better behaved results with more failure chance

def rm_nonletters(word):
    return ''.join(c.lower() for c in word if c.isalpha())

def makemarkov(words, ctxsize=CTXSIZE):
    """

words -- an iterable of strings
@return a dictionary from contexts to (letter, millibits) pairs
"""
    print("counting occurrences")
    model = defaultdict(Counter)
    for word in words:
        word = word.strip()
        wordletters = rm_nonletters(word)
        for i in range(len(wordletters)):
            context, letter = wordletters[max(i - ctxsize, 0):i], wordletters[i]
            model[context][letter] += 1
        suffix = wordletters[-ctxsize:]
        model[suffix][None] += 1  # termination
        model['$'][suffix] += 1

    # Strip away the collections members, producing only builtin types
    retmodel = {}
    while model:
        context, letters = model.popitem()
        retmodel[context] = dict(letters)

    return retmodel

def sur(model, letters, ctxsize=CTXSIZE):
    letters = rm_nonletters(sorted(letters))
    endingdenom = sum(model['$'].values())

    # The A Star search algorithm associates with each state
    # a priority value consisting of distance so far plus an
    # underestimate of the remaining distance.  It picks the state
    # with lowest priority from the heap and expands all possible
    # next states into the heap.
    # (millibits + 1000 * len(lettersleft), millibits, word, lettersleft)
    heap = [(1000 * len(letters), 0, '', letters)]
    while heap:
        _, bits, word, lettersleft = heappop(heap)
        context = word[-ctxsize:]
        try:
            allnexts = model[context]
        except KeyError:
            print("%s is a dead end context" % word, file=sys.stderr)
            continue

        # Handle end of word
        if lettersleft == '':
            # Endings are important for flavor.  If the context
            # can end a name, add ending bits.
            if None not in allnexts: continue

            # One out of every endingamt names ends with this context
            # so estimate how many bits of surprisal that represents
            endingamt = endingdenom / model['$'][context]
            endingbits = int(round(1000 * log2(endingamt)))
            yield bits + endingbits, word, ''
            continue

        # Otherwise find next letter.  To allow for a middle
        # initial, include None if only one letter is left.
        nexts = [(k, freq) for k, freq in allnexts.items()
                 if (k is not None and k in lettersleft)
                 or (k is None and len(lettersleft) <= 1)]
        # Word is a dead end into the remaining letters
        if not nexts: continue
        denom = sum(freq for _, freq in nexts)
        if False:
            print("(%4d) %s|%s %d, next %s"
                  % (len(heap), word, lettersleft, bits, repr(nexts)))
        lettersleft = Counter(lettersleft)
        for k, freq in nexts:
            # If this context is allowed to end a name, emit the
            # name with the remaining letter as a middle initial
            if k is None:
                mi = "".join(lettersleft.elements())
                endingamt = endingdenom / model['$'][context]
                endingbits = int(round(1000 * log2(endingamt)))
                yield bits + endingbits, word, mi
                continue

            # Otherwise extend the word with another letter
            newbits = bits + int(round(1000 * log2(denom / freq)))
            newprio = newbits + 1000 * len(lettersleft)
            lettersleft[k] -= 1
            newletters = ''.join(lettersleft.elements())
            lettersleft[k] += 1
            heappush(heap, (newprio, newbits, word + k, newletters))

def sur_given(model, word, given, notendswith=None, tracename=None):
    # At one point, the model was a bit too permissive as it ran
    # out of options near the end of a name, producing a lot of
    # names not fitting the desired aesthetic for ending in
    # "ong", "ebo", "ngo", and the like.  The endingdenom mechanism
    # mostly solved this.  Let the caller reject suffixes anyway.
    if notendswith:
        notendswith = tuple(set(s.lower() for s in notendswith))
    else:
        notendswith = tuple()
    tracename = tracename.lower() if tracename else None

    lettersleft = Counter(rm_nonletters(sorted(word)))
    for c in rm_nonletters(given):
        if lettersleft[c] <= 0:
##            print("can't remove %s from %s" % (word, given))
            return
        lettersleft[c] -= 1
    lettersleft = ''.join(lettersleft.elements())
    print("Given name %s followed by surname made of %s" % (given, lettersleft))

    lines = []
    mi_penalty = 5000
    for bits, last, mi in sur(model, lettersleft):
        if last.endswith(notendswith): continue
        parts = [given]
        if mi:
            parts.append(mi.upper() + ".")
            bits += mi_penalty
        lastcap = last[0].upper() + last[1:]
        parts.append(lastcap)
        parts = " ".join(parts)

        # The name Mindy Beageonton (Bee-jin-tun) was found manually
        # and is a benchmark of how well the algorithm fits the
        # desired aesthetic.  Pass tracename="beageonton" to activate
        if last == tracename:
            print("special name %s has %d.%03d bits"
                  % (parts, bits // 1000, bits % 1000))

        lines.append((bits, parts))
        if len(lines) % 10000 == 0: print(len(lines))

    lines.sort()
    del lines[200:]
    print("\n".join(
        "%4d.%3d.%03d %s" % (i + 1, bits // 1000, bits % 1000, name)
        for i, (bits, name) in enumerate(lines)
    ))

def sur_multigiven(model, word, givens, **kwargs):
    for given in givens:
        sur_given(model, word, given, **kwargs)

def find_mindy(surmodel):
    sur_multigiven(surmodel, "nintendogameboy",
                   ["Mindy", "Amy", "Amie", "Toni"],
                   tracename="Beageonton")
    sur_multigiven(surmodel, "familycomputer",
                   ["Emily", "Amy", "Amie"],
                   tracename="MacProut")

othergivens = """
Tess Tessa 
""".split()

def main():
    with open(".cache/surnames-uk.txt", "r") as infp:
        surnames = list(infp)
    with open(".cache/surnames-us.txt", "r") as infp:
        surnames.extend(infp)

    givens = set(othergivens)
    for filename in [".cache/names1920s.tsv"]:
        with open(filename, "r", newline="") as infp:
            reader = csv.reader(infp, "excel-tab")
            headings = next(reader)
            colid = headings.index("female name")
            givens.update(row[colid] for row in reader)
    givens = sorted(givens)
        
    surmodel = makemarkov(surnames)
    find_mindy(surmodel)

    # This produces gems like
    # Mary Messetts, Tess Strammey, and Tessa Symmert
    sur_multigiven(surmodel, "mastersystem", givens)
    # Tried "segagamegear" but too many G's for the givens I have.
    # Even the boy's name "Greg" gives less-than-natural results


if __name__=='__main__':
    main()
