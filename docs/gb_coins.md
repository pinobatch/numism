Game Boy coin ideas
===================

Many free or freeware console emulators fail accuracy test ROMs due
to behavior differences from authentic hardware.  I plan to research
the precise behaviors underlying test failures and then produce
"coins", or minimal test routines to highlight these differences.

See [What makes a good coin?] for what I'm aiming at.

[What makes a good coin?]: ./good_coin.md

Coin list
---------
All this is preliminary:

1. `add hl` flags
2. `add sp` flags
3. APU off clears registers and doesn't honor writes till turned on
4. Filling APU with zeroes causes OR mask to be read back
5. Upward sweep turns off NR52 status and downward sweep doesn't
6. APU length counter expiry and envelope $00 turn off NR52 status
7. 
8. 
9. 
10. 
11. `di halt inc d halt inc e` double-increments only E (halt bug)
12. `di halt inc d halt inc e` calls no handler (VBA halt bug)
13. `inc hl` in mode 2 corrupts OAM only on DMG, and GBC palette can
    be written and read back during vblank only on GBC
14. `daa` with $9A00 and a few other key values of AF
15. 
16. 
17. 
18. 
19. 
20. 

