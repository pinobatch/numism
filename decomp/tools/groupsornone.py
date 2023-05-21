#!/usr/bin/env python
import re

class GroupsOrNone(object):
    """Allows safely calling group() and groups() on None.

Useful with regular expression matching in a generator expression.

Rationale:

ECMAScript provides a `?.` operator to perform a substitute operation
on an undefined or null object within an expression. So does PHP,
with the `@` that returns NULL instead of raising a diagnostic error.
Python lacks a direct counterpart.  When a proposal to catch
exceptions within a generator expression was proposed in 2014,
Guido rejected it on grounds that the "look before you leap" (LBYL)
paradigm isn't inferior enough to an exception-driven "easier to ask
forgiveness than permission" (EAFP) paradigm to justify a change to
the language.
<https://peps.python.org/pep-0463/>

I happen to disagree with this decision.  In some cases, looking
and leaping involve side effects that would be repeated, expensive
computations that would be repeated, or conditions that may change
from time of check to time of use (TOCTTOU).  Using EAFP requires
creating and naming a function to catch exception, and using
non-double-calculating LBYL in an expression requires creating and
naming a function to hold the variable to hold the result of looking.
Nevertheless, because Python was chosen as the implementation
language, I must work around what is given to me and accept
this inconvenience.
"""

    def __init__(self, match_object):
        self.match_object = match_object

    def group(self, *p, **k):
        """Forwards calls to match_object.group() if exists; otherwise returns None."""
        if self.match_object is None: return None
        return self.match_object.group(*p, **k)

    def groups(self, *p, **k):
        """Forwards calls to match_object.groups() if exists; otherwise returns None."""
        if self.match_object is None: return None
        return self.match_object.groups(*p, **k)
