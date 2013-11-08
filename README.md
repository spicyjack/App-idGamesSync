# App-idGamesSync #

Create a mirror of the "idGames Archive", using different mirrors hosted at
various places around the Internet.  You can control what gets mirrored, so
that if you only wanted Doom WADs (the files that contain the layout of levels,
as well as the binary data for sounds and graphics), you could just mirror
them, instead of mirroring everything, which can include documentation,
shareware releases of Doom, themes for Windows, sounds, game graphics, and
miscellaneous files.

## What is DOOM? ##

(from http://doomwiki.org/wiki/Doom)

"Doom (officially cased DOOM) is the first release of the Doom series, and one
of the games that consolidated the first-person shooter genre. With a science
fiction and horror style, it gives the players the role of marines who find
themselves in the focal point of an invasion from hell. The game introduced
deathmatch and cooperative play in the explicit sense, and helped further the
practice of allowing and encouraging fan-made modifications of commercial
video games."

## INSTALLATION ##

To install this module, run the following commands:

	perl Makefile.PL
	make
	make test
	make install

To use `cpanm` to install this module from a tarball, unpack the module source
and run the `cpanm` command inside of it;

    cpanm .

## SUPPORT AND DOCUMENTATION ##

After installing, you can find documentation for this application with the
perldoc command.

    perldoc idgames_sync.pl

You can get basic help with the script itself by calling:

    perl idgames_sync.pl --help

The script generates different styles of reports on what files will be
synchronized.  More information on report types, output formats of reports,
and specifying mirror servers to synchronize to can be shown by calling:

    perl idgames_sync.pl --morehelp

Examples of script usage can be seen by calling:

    perl idgames_sync.pl --examples

You can also look for information at:

    GitHub project page
        https://github.com/spicyjack/App-idGamesSync

    GitHub issues page
        https://github.com/spicyjack/App-idGamesSync/issues

COPYRIGHT AND LICENCE

Copyright (C) 2011, 2013 Brian Manning

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

