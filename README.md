Coda-2-LESS-Compiler
====================

A LESS compiler for Coda 2/2.5

[Check out Less at lesscss.org](http://lesscss.org/)

If you haven't, [check out Coda as well!](http://panic.com/coda/)

Installation
------------
[(RECOMMENDED) Install the latest stable version straight from Panic! (Look for LESSCompile)](http://panic.com/coda/plugins.php#Plugins)

Or, [Download and manually install the plugin from github](https://github.com/mjvotaw/Coda-2-LESS-Compiler/raw/master/LESSCompile.codaplugin.zip)


What does this do?
------------------
This plugin provides LESS compilation straight in Coda--no more having to remember to open a second app just to sit there and compile your less for you.


How do you use it?
------------------
Once you install the plugin, you can add .less files to be watched by going to Plug-Ins > LESS Compiler > Site Settings.
You can drag and drop the desired .less file, or hit the folder icon and select it. LESS Compiler will add it, and watch it *AND* any @imported files for changes.

![File Settings](/stuff/Less file settings.png)

Clicking the cog will show the Advanced settings for the given file:

![Advanced Settings](/stuff/Less file settings advanced.png)

The preferences menu provides various options for how LESS Compiler notifies you.
![Preferences](/stuff/Less preferences.png)

Limitations
-----------
If you're still using Coda 2.0.x, the plugin cannot mark the compiled files for publishing. Fortunately, Coda 2.5 takes care of this!

This compiler does not have its own log, but it DOES barf a lot of stuff into system.log. Lines from this plugin start with 'LESS::'.

Improvements
------------
If you have any ideas for how this plugin can work better, or any feature requests, please let me know by [opening an issue in the issue tracker](https://github.com/mjvotaw/Coda-2-LESS-Compiler/issues/new).


Change Log
==========

1.1.1
-----
- Fixed issue #15 (--depends creates extraneous file, now creating it in a less conspicuous place)
- Finally changed dependency sql to not recreate each dependency row on every compilation

1.1.0
-----
- Updated Less to 2.2.0
- Updated Node to latest release
- Refactored NSTask code to separate class (which will hopefully make it less tempermental)
- Cleaned up some of the compile code
- Modified Lessc to make --depends more consistently output to stdout before appearing to end (see issue #13)

1.0.0
-----
- Added many more compiler options
- Setup database to no longer nuke older versions
- Cleaned up code a bunch
- Updated Less to 2.1.0

0.5
---
- Updated Less to 1.7.0
- Added drag and drop capability to the Site Settings window.
- Added a missing Less dependency when @import'ing remote url's.
- ESC key now closes windows.
- Added a Strict Math compilation option in Preferences.

0.4.2
-----
- Now it actually works with older versions of Coda (2.0.1+)
- Site Settings menu only opens when a Site is open, and shows only .less files from that Site (instead of everything).

0.4
---
- Fixed some issues with depenencies sometimes getting deleted from the database
- Added 'Strict Math' compilation option (defaults to on)

0.3
---
- Setup database to live in NSHomeDirectory(), to prevent it from being overwritten on new plugin versions.
- Setup NsOpen/NSSave dialogs to default to current site directory (as best as it can determine);
- A couple little ui things, too.
