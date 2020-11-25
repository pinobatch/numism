Estimate graphics
=================

Level backgrounds
-----------------

Terrain

- Ground
- Hill (platform above platform)
- Water
- Bridge

Decs

- Flowers (4+ types)
- Trees
- Bushes
- Coins (5 cels)

Buildings

- One building per NPC
- Possibly more when entering town

Sprite cels
-----------
I'm looking for more smoothness of motion than early NES/SMS games,
closer to Game Boy adaptations of Disney films.
We can assume the 22-pixel-tall player character uses about 6 tiles
per cel on 3bpp platforms or 8 tiles per cel on 4bpp platforms:
128 or 144 bytes per cel.  That's 9-10K just for the cels we know
about, unless some sort of tile sharing is figured out.

PC before meeting bellhop

- Stand (1 cel)
- Walk (8 cels)
- Sudden stop (2 cels)
- Lean forward and back (4 cels)
- Crouch/uncrouch (9 cels)
- Lean forward and back in crouch (4 cels)
- Lift onto ledge from side (6 cels)
- Climb ladder (1 cel turn to face, 3 cels climb)
- Jump (4 cels: rise, peak, drop, drop below start; land may reuse
  crouch cels)
- Lift onto one-way  from front (6 cels)
- Give coins to NPC (3 cels)

PC after meeting bellhop

- Hop (4 cels)
- Long jump (6 cels)
- Swinging (5 cels, 22.5 degrees apart)
- Hovering/flying (5 cels, 22.5 degrees apart)


