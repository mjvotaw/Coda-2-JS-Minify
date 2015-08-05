Coda-2-JS-Minify
====================

A Javascript minifier/parser for Coda 2.5

Based on the node.js minifier [UglifyJS2](https://github.com/mishoo/UglifyJS2)

If you haven't, [check out Coda as well!](http://panic.com/coda/)

Installation
------------
[Download and manually install the plugin from github](https://github.com/mjvotaw/Coda-2-LESS-Compiler/raw/master/LESSCompile.codaplugin.zip)
(This will be officially released soon, once it's gotten in the hands of a couple more people).

What does this do?
------------------
This plugin provides javascript parsing/minification straight in Coda.


How do you use it?
------------------
Once you install the plugin, you can add .js files to be watched by going to Plug-Ins > LESS Compiler > Site Settings.
You can drag and drop the desired .js file, or hit the folder icon and select it. LESS Compiler will add it, and watch it for changes.

![File Settings](/stuff/JS file settings.png)

Clicking the cog will show the Advanced settings for the given file:

![Advanced Settings](/stuff/JS file settings advanced.png)

The preferences menu provides various options for how LESS Compiler notifies you.
![Preferences](/stuff/JS preferences.png)

Limitations
-----------
If you're still using Coda 2.0.x, the plugin cannot mark the compiled files for publishing. Fortunately, Coda 2.5 takes care of this!

Improvements
------------
If you have any ideas for how this plugin can work better, or any feature requests, please let me know by [opening an issue in the issue tracker](https://github.com/mjvotaw/Coda-2-LESS-Compiler/issues/new).


Change Log
==========

0.1
---
- Initial working build.
