Roadmap
=======

Each sprint is 12 items.  Not all are filled in, as some sprints
leave space for splitting up other tasks.  Also there's a fog that
blocks roadmapping several sprints from now, and I expect the fog
to clear once I complete a sprint.

All work items apply to the Game Boy port unless otherwise specified.

Continue
--------
"Continue" is a conventional test framework.  It runs the 10 tests
that make up a stage and displays their results.  I set out during
this sprint to fill the majority of stages 1 and 2 with coins, and
with 19 out of 20 complete, I believe I succeeded.

1. GB: Make instruction timer
2. NES: Design title and continue screens
3. 
4. 
5. 
6. 
7. 
8. 
9. 
10. 
11. 
12. 

Cels
----
Animate the character to the point where I can start teasing things
on Twitter.  This is blocked on reference video for rotoscoping.

1. Walk
2. Sudden stop
3. Lean forward and back in crouch
4. Lift onto ledge from side
5. Lift onto ledge from front
6. Jump
7. 
8. 
9. 
10. 
11. 
12. 

Background
----------
Based on the coins implemented so far, I expect coin code and
descriptions to fill about 12 KiB, and menu code and data to take
another 4 KiB.  If we don't test MBC, this leaves 16 KiB for the
game.

Thus we'll need to store the game's maps efficiently.
Nintendo's _Super Mario Bros._ uses an object paradigm, organizing
level data as a list of (X, Y, thing) elements.  Later games in
the series, such as _Super Mario Bros. 3_ and _Super Mario World_,
extend the "thing" part to 2 bytes to let some things vary in size.

I might be able to get away with considering only width in size.
Each object then becomes with metatile IDs for isolated, left,
middle, and right.  To allow bidirectional scrolling with a sliding
window instead of a map-sized buffer, the left and right can join
to horizontally adjacent counterpart tiles, turning them middle.

We combine this with a Markov chain to autotile downward.  Each
metatile has a value with which to fill an empty space below it, and
there are special-case pairs for combining specific pairs of top and
bottom metatiles.

1. Sketch map for stage 1 using very programmer-art tile set
2. Encode this map using dX, Y, W, thing format
3. Make displayer for this format on PC in Pillow
4. Join left and right to adjacent tiles
5. Add Markov chain for empty cells
6. Add Markov chain for cell pairs
7. Convert to sliding window logic in Pygame
8. 
9. Make displayer for this format on GB
10. GB join left and right to adjacent tiles
11. GB add Markov chain for empty cells
12. GB add Markov chain for cell pairs

Worldbuilding
-------------
To continue to fulfill [DRW's request] for games for retro consoles
with female characters as well as promote [Bechdel-positive] works
in general, I'm doing a lot of heroine for this project.  I plan
to have the player characters in all editions present as female.

1. Run surname anagram solver with multiple given names
2. 
3. 
4. 
5. Name NES/FC player character (thinking Emily)
6. Name GB player character (thinking Mindy)
7. Name SMS player character
8. Name GBA player character
9. Name NPCs
10. 
11. 
12. 

[DRW's request]: https://forums.nesdev.com/viewtopic.php?f=5&t=12966
[Bechdel-positive]: https://allthetropes.org/wiki/The_Bechdel_Test
