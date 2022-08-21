What makes a good coin?
=======================

Many free or freeware console emulators fail accuracy test ROMs
due to behavior differences from authentic hardware.  I seek
to survey current and notable historic emulators, research the
precise behaviors underlying test failures, and produce "coins",
or minimal test routines to highlight these differences.

Each of up to 10 stages has 10 coins.  Each coin represents testing
one hardware behavior that at least one stable emulator fails.
Behaviors needed just to start popular games need not be tested.

Coins should quickly demonstrate a difference, preferably within
50 milliseconds and a handful of ROM bytes.  They should not be
exhaustive, though exhaustive tests outside the main suite can help
characterize each emulator's corner-case behavior as if it were a
"fantasy console."

Coins should not be opaque, obscure, cryptic, or inscrutable.  They
should state what they test and test what they state.  This way, the
maintainer of an emulator can quickly find differences and fix them,
and users of historic or specialized emulators can become aware of
the extent of their behavior differences.

Coin choice
-----------
I'd like to rank each tested behavior by a combination of three
factors: impact, ease of fixing, and ease of testing.

### Impact

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

Behaviors affecting more popular games rank earlier than those
affecting only some obscure Japanese release.  Things causing
games not to boot rank earlier than (say) noticeable scoring or
RNG differences, in turn earlier than things causing only visual
glitches.  Cases where an emulated game might write out of bounds
to host memory should also rank early. Areas where an emulator is
too lenient, causing homebrew games to appear to work but fail on
hardware, generally rank later.  Things not used by any licensed
game or notable homebrew game, such as the PCM reflection registers
in the Game Boy Color, might be too obscure for inclusion.

### Ease of fixing

Expected programmer time and impact on emulation speed from fixing
an inaccuracy.  For example, behaviors requiring mid-scanline cycle
accuracy would be later on the list, as they're less practical to
achieve in emulators for microcontrollers or retro PCs or consoles.
Things only best-of-breed emulators (Mesen, higan, SameBoy, and
Emulicious) get right can rank near the end.

### Ease of testing

Three classes of behaviors cannot be tested in this sort of
framework: behaviors not visible to the CPU, behaviors of potentially
hardware-damaging "killer pokes," and behaviors not testable in a
single ROM image.

All tested behaviors must be visible to the CPU.  It cannot measure
video output (such as palettes, priority, pixel response time, and
LCD desyncs) and audio output (such as noise LFSR lockup, as few
systems have PCM reflection).  Some CPU-visible behaviors can be
used as a proxy for an invisible one, such as measuring the effect
of the 10 sprites limit on GB mode 3 time.

Most tests should finish within a few frames.  Longer tests should
be used sparingly, as the player will grow tired of overuse of
time-wasting game mechanics to give time for the test to complete.

Several consoles use a variety of "mappers," or configurations of
support hardware on each cartridge's circuit board.  With very few
exceptions (such as _R.C. Pro-Am_ for NES), a single game released
in a region uses a single mapper.  Thus without enough content to
make multiple games, we can test only one mapper's behavior.

Stage by stage
--------------
The player progresses by collecting coins and buying a mobility
upgrade with which to clear a barrier that blocks the next stage.
Stage 1 can be cleared if up to 5 coins are missed.  Later stages
allow missing up to 10 coins from it and previous stages combined.

Early stage coins should focus on behaviors that affect compatibility
with released software and overly permissive behaviors that cause
common homebrew programming gotchas.

Tests in one stage should not assume results from a later
stage, so as not to end up passing for the wrong reasons.

### Stage 1

Stage 1 should showcase one historic emulator's behavior differences.
This can be one of the Nocash emulators or another emulator iconic
in the console's early scene.  Choose ten behaviors where modern
emulators match hardware and this emulator does not, even when its
leniency settings are set to "emulate as in reality."  This emulator
should let the player collect no cash, whereas "decent" emulators
score seven or more.

It shouldn't cost coins to collect coins.  If the stage 1 emulator is
freemium, where a license file, online activation, or in-app purchase
unlocks major features, stage 1 should not test behaviors that depend
on premium features.  For example, if a Game Boy emulator allows
full monochrome use and puts Game Boy Color functionality behind
the paywall, stage 1 should test only behaviors identical between
monochrome and color systems.

### Stage 2

Good coins for stage 2 fall in two major classes.  Some cover
misbehaviors of other notable early emulators, so that they score
less than 10 between the first two stages.  Others cover behaviors
on which several later stage coins rely as a benchmark against
which to test other behaviors.

### Emulator choice

Preliminary suggestions:

- GB: Stage 1 covers NO$GMB; stage 2 covers VisualBoyAdvance and rew. with a side of KiGB and Goomba Color
- NES: Stage 1 covers NO$NES; stage 2 covers NESticle X.XX
- SMS: Stage 1 covers Massage; stage 2 covers MEKA
- GBA: Stage 1 covers NO$GBA, which might be tricky because it's still actively maintained; stage 2 covers VBA

Other resources
---------------
Existing emulator tests may be too comprehensive and opaque to make
good coins.  ZEXALL, with its runtime of several minutes per test
and CRC-driven pass/fail grading, is something to avoid.  Others may
assume too many behaviors that differ from those of the emulators
under test.  Nevertheless, others' tests are good for researching
the existence and nature of behavior differences.

- NES: ["Emulator tests" on NESdev Wiki](https://wiki.nesdev.com/w/index.php/Emulator_tests)
- SMS: _To be decided_
- GB: ["Testing" on awesome-gbdev](https://gbdev.io/list.html#testing)
- GBA: [mGBA Suite](https://github.com/mgba-emu/suite) and [jsmolka/gba-suite](https://github.com/jsmolka/gba-suite)

