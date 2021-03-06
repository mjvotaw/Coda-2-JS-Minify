(Please note: this plugin is no longer being actively maintained. I'm not sure whether it works with current versions of Coda, so use at your own risk! If you'd like to make changes/updates, I'm more than happy to merge pull requests)
=========

Coda-2-JS-Minify
====================

A Javascript minifier/parser for Coda 2.5

Based on the node.js minifier [UglifyJS2](https://github.com/mishoo/UglifyJS2)

If you haven't, [check out Coda as well!](http://panic.com/coda/)

Installation
------------
[(Recommended) Install the lastest stable version straight from Panic!](https://panic.com/coda/plugins.php?id=130)

OR

[Download and manually install the plugin from github](https://github.com/mjvotaw/Coda-2-JS-Minify/raw/master/JSMinify.codaplugin.zip)

What does this do?
------------------
This plugin provides javascript parsing/minification straight in Coda. 


How do you use it?
------------------
Once you install the plugin, you can add .js files to be watched by going to Plug-Ins > JS Minify > Site Settings.
You can drag and drop the desired .js file, or hit the folder icon and select it. JSMinify will add it, and watch it for changes.

![File Settings](/stuff/JS file settings.png)

Clicking the cog will show the Advanced settings for the given file:

![Advanced Settings](/stuff/JS file settings advanced.png)
[Check out the Usage section of UglifyJS2 to learn more about what these options do.](https://github.com/mishoo/UglifyJS2#usage)

The preferences menu provides various options for how JSMinify notifies you.
![Preferences](/stuff/JS preferences.png)

Limitations
-----------
If you're still using Coda 2.0.x, the plugin cannot mark the compiled files for publishing. Fortunately, Coda 2.5 takes care of this!

Improvements
------------
If you have any ideas for how this plugin can work better, or any feature requests, please let me know by [opening an issue in the issue tracker](https://github.com/mjvotaw/Coda-2-JS-Minify/issues/new).


Change Log
==========

1.0
---
- Initial release.

0.1
---
- Initial working build.
