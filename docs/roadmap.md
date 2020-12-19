Roadmap
=======

Each sprint is 12 items.  Not all are filled in, as some sprints
leave space for splitting up other tasks.  Also there's a fog that
blocks roadmapping several sprints from now, and I expect the fog
to clear once I complete a sprint.

Continue
--------
"Continue" is a conventional test framework.  It runs the 10 tests
that make up a stage and displays their results.  By the end of this
sprint, I expect to fill the majority of stages 1 and 2 with coins.

1. 
2. Define test pattern for APU timer
3. Make instruction timer
4. Make mode 3 length measurer
5. Make OAM bug exerciser: fill OAM, wait for a mode, do inc/dec,
   read OAM.  Repeat for modes 0, 1, 2, and 3.
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
on Twitter.

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
With only an estimated 16 KiB for the game part if we don't want to
test MBC as well, we'll need to store the game's maps efficiently.
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

