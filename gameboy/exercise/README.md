Game Boy interactive exerciser
==============================

This is a small ROM used to interactively test behaviors in a
Game Boy emulator, even one without a debugger.  Press Select to
choose an exerciser.

CPU exerciser
-------------
Use this to demonstrate half-carry and DAA behavior differences.

![Screenshot as described below](../../docs/gb_exerciser.png)

Display

* `INST`: Edit up to 6 bytes of Sharp SM83 machine code, one nibble
  at a time. (See [SM83 opcode matrix].)
* `RUN`: Change when the code is run.  Set to `OFF` (don't run),
  `PRESS A` (run when A is pressed and released), or `AUTO` (run
  after each digit change)
* `AF`, `BC`, `DE`, `HL`, `SP`: Set registers before execution at
  left, and see results after execution at right.  After `AF` result
  word are flags `ZNHC`, with space written instead of each flag that
  is clear (0).
* `LAST INT`: First byte is the address of the called IRQ handler.
  Second is the value of `IF` (pending interrupts) at the end.

Controls

* Up, Down: Move cursor among rows (register pairs)
* Left, Right: Change run type or move cursor in row
* A+Up, A+Down: Change nibble value

Execution environment

* The code is run with interrupts disabled.
* `rst xx` loads `(($C7 | x) << 8) | x` into HL.

[SM83 opcode matrix]: https://gbdev.io/gb-opcodes/optables/

Sound exerciser
---------------
Use this to poke at audio registers and see how they read back.

![Screenshot of audio matrix](../../docs/gb_exerciser_sound.png)

Display

Each row represents one or set of control registers as two rows of
digits.  The top row contains values to write; the bottom contains
values continuously read back from the APU.

* `PULSE1`, `PULSE2`, `WAVE`, `NOISE`: The four channels
    * `SW`: Pitch sweep (pulse 1) or playback switch (wave)
    * `LN`: Length counter and pulse duty
    * `VF`: Volume and fade
    * `PP`: Period (middle, low, high)
    * `L`: 4 to use length counter; 0 to hold note
* `CTRL`: Chip-wide control registers
    * `VV`: Overall volume of left and right outputs
    * `CC`: Channels enabled on left and right outputs
    * `P`: APU power switch
    * `S`: Channel status (read-only)

Controls

* Up, Down: Move cursor among rows (channels)
* Left, Right: Move cursor in row
* A+Up, A+Down: Change nibble value
* A: Write all bytes of channel, starting a new note
* B: Overwrite only one byte in the channel

