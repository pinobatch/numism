Purpose
=======

There are two sides to every coin.

The game
--------
On the surface, Numism is a simple platformer game.  The object
is to proceed through the levels, collect all 100 coins, and buy the
Product.  A lot of coins will be out of reach until you pay the
characters you meet to teach you moves.

You only collect coins that you know are authentic.  If you grab a
coin and it just stops spinning, that means it's fake.  Stand in
front of a coin and press Up to view a description of what's wrong
with it.  Retrieving some coins requires digging by crouching on an
actuator and then standing back up.

### Movement upgrades

Early on, you can't die.  If you cannot cross an obstacle, you'll
just stop.  Buying upgrades helps you cross more obstacles and reach
more coins.

- **Before the first upgrade**  
  Move on ground, crouch, ascend one cell, descend two cells, ascend
  and descend ladders, collect coins, and view fake coins.
- **Court shoes** sold by (name missing) for 5 coins  
  Cross gaps of one cell, ascend two cells, and descend three cells.
  Ascend to hills behind you.
- **Hoop buoy** sold by (name missing) for 5 coins  
  Float across the surface of water and ascend one cell from water.

At this point, if you haven't hit any fakes, you'll have collected 30
coins and spent 10.  This leads into a big change for the game feel.

- **Clapper** sold by a kangaroo dressed as Spirou outside the hotel for 10 coins  
  A boot that covers both feet. After buying it, you are no longer
  as closely bound to the cell grid.  You can grab a bar and swing
  from it, either to get a boost or to emit a tone (I'm still looking
  for what that does).  In exchange, you can no longer walk.  Instead
  you hop like a kangaroo.  You can also fall, after which you are
  placed at the previous checkpoint.
- **Ground effect hovering** sold by (name missing) for 10 coins  
  Hover a couple pixels above the ground or water.  Jump height from
  ground increases as well to cross gaps of more cells.
- **Flight** sold by (name missing) for 10 coins

### Continue

The title screen has "Start" and "Continue" option.  "Continue" looks
for fake coins and lets you choose to start at any section with no
fake coins or the first section with at least one fake coin, having
all coins and upgrades from previous sections.

The tests
---------
Flip the coin over, and Numism is a test ROM.  Each coin represents
a behavior of a console visible to a running program, and each fake
coin represents an emulator's failure to accurately reproduce that
behavior.

See [What makes a good coin?] for what I'm aiming at.

I intend to choose behaviors to test through a survey of how current
emulators and important historic emulators respond to well-known
test ROMs.  In some versions, the ten coins reachable without an
upgrade represent fairly easy tests that a notable historic emulator
fails.  This would keep the player from proceeding past the initial
section of the map, which requires at least 5 out of 10 coins to
complete, allowing the player to collect no cash.

### Ranking behaviors

I'd like to rank each tested behavior by a combination of factors:

#### Impact

Behaviors affecting more popular games rank earlier than those
affecting only some obscure Japanese release.  Things causing games
to fail to boot rank earlier than (say) noticeable scoring or
RNG differences, in turn earlier than things causing only visual
glitches.  Cases where an emulated game might write out of bounds
to host memory should also rank early. Areas where an emulator is
too lenient, causing homebrew games to appear to work but fail on
hardware, generally rank later.  Things not used by any licensed
game or notable homebrew game, such as the GBC PCM registers, might
rank after the top 100.

The target audience is maintainers and users of stable emulators, as
an example of a game that doesn't work. Some behaviors have so much
impact that they're hard to test in anything resembling a game. Thus
we can treat any behavior needed to progress through the boot ROM,
menu, and early in-game scenes of iconic games as a prerequisite.
For example, a Game Boy test would depend on ability to get in-game
in _Tetris_, _Super Mario Land_, and _Pokémon Blue Version_. We're
looking for things that widely used emulators get wrong, not things
that block typical users from even considering using an emulator.
There are other, more focused tests for early emulator development. 

#### Ease of fixing

Expected programmer time and impact on emulation speed from fixing
an inaccuracy.  For example, behaviors requiring mid-scanline cycle
accuracy would be later on the list, as they're less practical to
achieve in emulators for MCUs or retro PCs or consoles.  Things only
best-of-breed emulators (Mesen, higan, SameBoy) get right can rank
near the end.

#### Ease of testing

The test shows whether each test passed or failed by either
collecting a coin or stopping its spinning.  For this reason, we
cannot test behaviors not visible to the CPU.  This includes video
output (such as palettes, priority, pixel response time, and LCD
desyncs) and audio output (such as noise LFSR lockup, as few systems
have PCM reflection registers).  Sometimes a CPU-visible behavior
can be used as a proxy for an invisible one, such as measuring
the effect of the 10 sprites limit on GB mode 3 time.

In addition, I'd prefer tests that complete within one or two frames
(about 35,000 M-cycles), not minutes-long exhaustive tests like those
in ZEXALL.  Slightly longer tests can be justified as "digging" for
coins by crouching on an actuator, standing back up, and waiting for
the coin to spawn.

Behaviors that a CPU can't observe, such as purely visual priority
problems, cannot be included. Things that take several seconds to
observe might need to use "digging" or other time-wasting mechanics.

The test is one ROM, as if one game was released.  Testing variant
cartridge hardware behavior, such as mappers on 8-bit systems, may
not be practical unless the test is worked as a game and its sequel.


### Existing test ROMs

