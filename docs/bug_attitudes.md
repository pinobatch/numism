Bug reporting attitudes
=======================

Different emulator developers have different attitudes toward
emulation that extend into what sorts of bug reports they prefer.
Some developers prefer **technical** bug reports, such as "Hblank IRQ
fails to trigger on same line as Y position IRQ."  This shows the
reporter's effort in narrowing down the root cause.  Others prefer
**game** bug reports describing in-game effects: "In level 3 of
_Animal Dreams IV_, Princess Piggy can't board the helicopter."
This shows that a behavior's impact is more than academic.

I chose the structure of Numism to remove all excuses.  I made it
a game so that devs focusing on game impact will care, and each
coin shows a technical reason so that technical devs will care.
Thus each report can be expressed in one of two ways:

- Game style: "In Numism stage 1, Mindy can't collect the first coin"
- Technical style: "After add hl,de the N and H flags aren't updated"

Or better yet both:

> **In Numism stage 1, Mindy can't collect the first coin**
> 
> After you start a new game, immediately after the first drop is a
> coin.  If you touch it on a Game Boy, it disappears.  If you touch
> it in the emulator, it just stops spinning.  Pressing Up while in
> front of the coin pops up a subtitle:
> 
> > **add hl flags**  
> > add hl,de; add hl,sp  
> > Z same, N=0, HC=carry  
> > from bits 11 and 15

