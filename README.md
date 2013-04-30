HaxeBuilder Copyright (C) 2013 AS3Boyan

Haxe Builder is tool that tries to implement live reloading feature on flash target of Haxe/AS3 projects.

Currently it's working on Windows only.
And currently you can use it only in FlashDevelop.
And currently you can use it only If you have installed Haxe compiler.(Tested on Haxe 3 RC)
Maybe later I will make it work with any text editor.
And maybe it will work in Linux later.

Installation instructions
1)Run setup.exe and install HaxeBuilder.
2)Installer should ask you to install FlashDevelop Templates,
If they not installed, to go HaxeBuilder folder, where you installed it, 
and open folder "templates", it should contain 1 file with ".fdz" file extension. 
Just double click on it and FlashDevelop will ask you to install templates.

Running instructions:
1)Open FlashDevelop
2)Create new project, and use "Haxe - Flash Live Reloading Project" or 
"Haxe - Flash(Starling) Live Reloading Project".
3)Press F5 or F8 or just Build button located on toolbar in FlashDevelop.
Also you can start it using menu Project ->Build Project or Project -> Test Project.
4)Flash Player Content Debugger should start automatically.
5)Code! 
Add your code to onAdded function;
And don't forget to dispose used bitmaps and remove added event listeners in onRemove function!

When you need to add library or add compiler arguments, or just change something
or just stop this program run "stop.bat". It should stop HaxeBuilder.

When you want to build release version, just run "build_release.bat". Don't forget to stop HaxeBuilder first!

If closed Flash Debugger Window, and you want to open it again, run "preview_swf.bat".

Building instructions:
1)You should have Haxe 3 RC(or newer) and Neko 2(or newer).
2)You should have FlashDevelop.
3)Open HaxeBuilder.hxproj with FlashDevelop and build project

If you got ideas/encountered bugs, you can tweet me at @As3Boyan.

Contributions are welcome.

Maybe later program will have a GUI, and I will list all contributors somewhere.