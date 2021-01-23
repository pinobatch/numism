It's a secret to Windows 9x users
=================================

**tl;dr:** The project isn't quite ready for public forums.

Many emulator developers eventually quit maintaining their emulators.
Sometimes a hobbyist developer quits when they take on unrelated
responsibilities, such as school, a job, or parenting.  Sometimes a
dev quits when it is discovered that one dev paraphrased another's
code too closely.  And sometimes cracks, keygens, and a flood of
novice users unable to follow instructions threaten a dev's revenue
and support channels, as described in "[The X-Rated Nightmare FAQ]". 
Downstream users may not even be aware that an emulator is no longer
maintained or that emulators with better game compatibility exist.

So in fourth quarter 2020, I set out to characterize the behavior of
historic emulators and present this behavior in the form of a game.
The more accurate the emulation, the farther the player can progress.
But I don't want my archaeology to cause discomfort to developers of
featured emulators.  Thus until the game façade is playable through
the third stage, I'm exercising discretion as to where I discuss it.

I choose venues in part based on compatibility with the operating
systems for which historic emulators were built.  Modern websites
are not compatible with web browsers made for Windows 98.
Part of this is because information security influencers have shamed
websites for accommodating historic browsers.  It's as if they see
website operators as [enablers] of users' alleged irresponsibility.

- [Why No HTTPS?] shames websites for not automatically redirecting
  cleartext HTTP to HTTPS (HTTP over TLS).  It is unknown if a server
  can avoid shame by performing redirection only when the user agent
  indicates support for recent TLS through an
  `Upgrade-Insecure-Requests` request header, as ndiddy recommends
  in [nesdev BBS #263204] for public static pages.
- [Qualys SSL Labs] shames websites for using versions of TLS prior
  to 1.2.  TLS 1.2 was published in [RFC 5246] in August 2008.

Mainstream web browsers have long since dropped support for historic
versions of the Windows operating system.  Versions of Google Chrome
later than 49 and Firefox later than 52 require Windows 7 or later.
This has happened close to Microsoft's announced end of extended
support for each Windows version, plus or minus a couple years:

- Windows 98 and Windows Millennium Edition (Windows Me)  
  Extended support ended on July 11, 2006, two years before
  the TLS 1.2 specification was published.
- Windows XP  
  Extended support ended on April 8, 2014.
- Windows Vista  
  Extended support ended on January 14, 2020.

The only remotely modern web browser I'm aware of built for
Windows 98 is [RetroZilla Suite].  This is a backport of what is
now called SeaMonkey.  It's based on Gecko 1.8.1, the engine used
by Firefox version 2.  Per answers to [Pat07's question], this may
still not be new enough for the modern web, as the earliest version
of Firefox to support TLS 1.2 is Firefox 23.

Thus many modern collaboration and communication platforms are
incompatible with historic Windows.

- Discord messaging: TLS 1.0.  Web requires recent JavaScript;
  desktop requires a PC capable of running Google Chrome.
  Third-party client use other than through bridge bots has
  resulted in account termination.
- Element messaging: TLS 1.0.  Uses the Matrix network, to which
  some Discord channels are bridged.  Matrix encourages third-party
  clients, whose system requirements may differ.
- GitHub repository hosting: TLS 1.2.  In [nesdev BBS #263685] and
  elsewhere, one emulator developer has often complained about
  GitHub's use of TLS 1.2 and forced redirection to HTTPS.

Prior to the official announcement, I feel comfortable building
Numism on GitHub and discussing it on Discord and Element.
I'm willing to consider other venues.  I may need to be more
careful now that commit messages are citing Numism by name,
such as [commit 87466ead27] of Gusboy.

`IT'S A SECRET TO EVERYBODY.`  (That's [Moblin] for "Let's keep it
between us, OK?")

[The X-Rated Nightmare FAQ]: https://problemkaputt.de/mailcrap.htm
[enablers]: https://en.wikipedia.org/wiki/Codependency
[Why No HTTPS?]: https://whynohttps.com/
[nesdev BBS #263204]: https://forums.nesdev.com/viewtopic.php?p=263204#p263204
[Qualys SSL Labs]: https://www.ssllabs.com/ssltest/
[RFC 5246]: https://tools.ietf.org/html/rfc5246
[RetroZilla Suite]: https://rn10950.github.io/RetroZillaWeb/
[Pat07's question]: https://support.mozilla.org/en-US/questions/1262427
[nesdev BBS #263685]: https://forums.nesdev.com/viewtopic.php?p=263685#p263685
[commit 87466ead27]: https://github.com/Guspaz/Gusboy/commit/87466ead27677ddabe7e42822aa71425a53b6c3a
[Moblin]: https://zeldauniverse.net/2020/08/18/zeldas-study-its-a-secret-to-nobody/
