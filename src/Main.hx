/*
 * HaxeBuilder is the tool that tries to implement live reloading feature for flash projects written using AS3/Haxe/NME
 * Copyright (C) 2013 AS3Boyan
 * 
 * This file is part of HaxeBuilder.
 * HaxeBuilder is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * HaxeBuilder is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with HaxeBuilder.  If not, see <http://www.gnu.org/licenses/>.
*/

package ;

import haxe.xml.Fast;
import sys.FileStat;

import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.net.Host;
import sys.net.Socket;

#if neko
import neko.vm.Thread;
#elseif cpp
import cpp.vm.Thread;
#end

class Main 
{
	private var haxe_started:Bool;
	private var mytextfile:FileOutput;
	private var build_date:Date;
	private var need_rebuild:Bool;
	private var check_interval:Float;
	private var build_interval:Float;
	private var running_path:String;
	private var program_path:String;
	private var project_file:String;
	
	private var mytextfile_path:String;
	private var mystatfile_path:String;
	private var swf_path:String;
	private var fdbuild_path:String;
	
	private var haxe_started_in_thread:Bool;
	private var client_commands:String;
	var s:Socket;
	var write_complete:Bool;
	var connected:Bool;
	var release_mode:Bool;
	var isNME:Bool;
	var nmml_file:String;
	var hxml_file:String;
	
	public function new()
	{				
		release_mode = false;
		
		var args:Array<String> = Sys.args();
		
		running_path = Sys.getCwd();
		program_path = Sys.getEnv("HAXE_BUILDER");
		
		if (args.length != 0)
		{
			var r:EReg = ~/.hxml/;
			var r_exe:EReg = ~/.exe/;
			
			if (args[0] == "-release")
			{
				release_mode = true;
			}
			else if (args[0] == "-help")
			{
				showHelp();
				terminateHaxeAndQuit();
			}
			else if (r.match(args[0]) && FileSystem.exists(running_path + args[0]))
			{
				hxml_file = args[0];
			}
			else if (r_exe.match(args[0]))
			{
				fdbuild_path = args[0];
			}
		}
		
		if (!release_mode && hxml_file != null)
		{
			checkServer();
		}
		
		mytextfile_path = "bin\\mytext.txt";
		mystatfile_path = "bin\\stats.txt";
		swf_path = "bin\\Simplehaxe.swf";
		
		if (program_path.charAt(program_path.length - 1) != "\\")
		{
			program_path = program_path + "\\";
		}
		
		haxe_started_in_thread = false;
		
		if (hxml_file == null)
		{
			searchProjectFiles();
		}
		
		if (project_file == null && hxml_file == null && nmml_file == null)
		{
			showHelp();
			terminateHaxeAndQuit();
		}
		
		isNME = false;
		
		if (nmml_file != null)
		{
			if (project_file != null)
			{
				isNME = isNMEProject();
			}
			else
			{
				isNME = true;
			}
		}
		
		check_interval = 1;
		
		if (fdbuild_path != null)
		{
			startFDBuild();
		}
		else
		{
			initFastCompilationMode();
		}
		
		if (release_mode)
		{
			if (project_file != null && !isNME)
			{
				build();
			}
			
			terminateHaxeAndQuit();
		}
		
		if (project_file != null || nmml_file != null)
		{
			createServerThread();
		}
		
		need_rebuild = false;
		
		while (true)
		{
			try
			{
				scanFolder(running_path);
			}
			catch (unknown : Dynamic)
			{
				
			}
			
			Sys.sleep(check_interval);
			
			if (need_rebuild)
			{
				if (isNME)
				{
					buildNMEProject();
				}
				else if (fdbuild_path != null)
				{
					startFDBuild();
				}
				else if (project_file != null)
				{
					build();
				}
				else
				{
					buildHaxeBuildFile();
				}
			}
			else
			{
				build_interval = Date.now().getTime() - build_date.getTime();
				
				if (build_interval > 3600000)
				{
					terminateHaxeAndQuit();
				}
				else if (build_interval > 3000000) 
				{
					check_interval = 30;
				}
				else if (build_interval > 1500000) 
				{
					check_interval = 15;
				}
				else if (build_interval > 300000) 
				{
					check_interval = 5;
				}
				else if (build_interval > 100000) 
				{
					check_interval = 3;
				}
				else if (build_interval > 10000)
				{
					check_interval = 1.5;
				}
			}
		}
	}
	
	private function showHelp() 
	{
		Sys.println("HaxeBuilder  Copyright (C) 2013  AS3Boyan");
		Sys.println("This program comes with ABSOLUTELY NO WARRANTY\n");
			
		Sys.println("Run this program from folder that contain your FlashDevelop Haxe Project file(.hxproj) or NME project file(.nmml) or Haxe build file (.hxml)");
		Sys.println("or run 'HaxeBuilder build.hxml' to enable building specified hxml file");
	}
	
	private function parseNMEProject() 
	{
		var xml_file:FileInput = File.read(running_path + nmml_file);
		var xml_data:Xml = Xml.parse(xml_file.readAll().toString());
		
		var fast:Fast = new Fast(xml_data.firstElement());
		var app:Fast = fast.node.app;
		
		if (app.has.file && app.has.path)
		{
			swf_path = app.att.path + "\\flash\\bin\\" + app.att.file + ".swf";
			mytextfile_path = app.att.path + "\\flash\\bin\\mytext.txt";
			mystatfile_path = app.att.path + "\\flash\\bin\\stats.txt";
		}
	}
	
	function searchProjectFiles() 
	{
		var file_list:Array<String> = FileSystem.readDirectory(running_path);
		
		var r:EReg = ~/.hxproj/;
		var r_nmml:EReg = ~/.nmml/;
		var r_hxml:EReg = ~/.hxml/;
		
		for (file in file_list)
		{
			if (r.match(file))
			{
				project_file = file;
			}
			else if (r_nmml.match(file))
			{
				nmml_file  = file;
			}
			else if (r_hxml.match(file))
			{
				hxml_file = file;
			}
			
			if (project_file != null && nmml_file != null && hxml_file != null)
			{
				break;
			}
		}
	}
	
	function buildNMEProject() 
	{
		parseNMEProject();
		
		checkOutputFolder();
		
		updateTextFile(program_path + "swfpath.txt", running_path + swf_path);
		
		updateTextFile(running_path + mytextfile_path, "0");
		
		cleanProject();
		
		var additional_args:String = "";
		if (!release_mode)
		{
			additional_args = " -debug -Dfdb -prompt";
		}
		
		var n:Int = Sys.command("haxelib run nme build " + running_path + nmml_file + " flash" + additional_args);
		
		build_date = Date.now();
		
		if (n == 0)
		{
			Sys.println("Build complete");
			
			updateTextFile(running_path + mytextfile_path, build_date.toString());
			updateStats();
		}
		else
		{
			Sys.println("Build failed");
		}
		
		need_rebuild = false;
		check_interval = 0.5;
	}
	
	private function buildUsingClient()
	{		
		s = new Socket();
		
		connected = false;
		
		while (!connected)
		{
			connected = true;
			try
			{
				s.connect(new Host("127.0.0.1"), 6000);
			}
			catch (unknown:Dynamic)
			{
				connected = false;
			}
		}
		
		write_complete = false;
		
		while (!write_complete)
		{
			write_complete = true;
			
			try
			{
				s.output.writeString(client_commands);
			}
			catch (unknown:Dynamic)
			{
				write_complete = false;
			}
			
			if (write_complete)
			{
				s.waitForRead();
				
				var eof = false;
				while (!eof)
				{
					try
					{						
						var mystr = s.input.readLine();
						
						if (mystr == "\x02")
						{
							eof = true;
						}
						else
						{
							var n:Int = mystr.indexOf("/");
							
							if (n != -1)
							{
								mystr = mystr.substr(n+1);
							}
							//
							//var r:EReg = new EReg("/","gim");
							//mystr = r.replace(mystr, "\\");
							Sys.println(mystr);
						}
						
					}
					catch (unknown:Dynamic)
					{
						eof = true;
					}
				}
				
				s.close();
			}
		}
	}
	
	private function checkServer()
	{
		var s:Socket = new Socket();
		try
		{
			s.connect(new Host("127.0.0.1"), 6002);
			s.close();
			Sys.println("already running");
			Sys.exit(0);
		}
		catch (unknown:Dynamic)
		{
			
		}
	}
	
	private function terminateHaxeAndQuit()
	{
		if (haxe_started_in_thread)
		{
			Sys.command("taskkill /F /IM haxe.exe");
		}
		Sys.exit(0);
	}
	
	private function createServerThread()
	{
		Thread.create(function ()
		{
			startServer();
		}
		);
	}
	
	private function startServer()
	{				
		var s:Socket = new Socket();
		s.bind(new Host("127.0.0.1"), 6002);
		s.listen(1);
		
		while (true)
		{
			var c:Socket = s.accept();
			var input_data:String = c.input.readLine();
			
			if (input_data == "stop")
			{
				break;
			}
			
			c.close();
		}
		
		Sys.println("closed");
		s.close();
		
		terminateHaxeAndQuit();
	}
	
	
	private function startFDBuild()
	{		
		var path = running_path.substr(0, running_path.length - 1) + "\\"; 
		
		var args:Array<String> = new Array<String>();
		args.push(path + project_file);
		
		Sys.command(fdbuild_path, args);
		
		build_date = Date.now();
		
		need_rebuild = false;
	}
	
	private function initFastCompilationMode()
	{
		if (!isNME && project_file != null)
		{
			parseFlashDevelopHxProj();
			
			haxe_started = true;
			
			try
			{
				var socket:Socket = new Socket();
				socket.connect(new Host("localhost"), 6000);
				socket.close();
			}
			catch (unknown : Dynamic)
			{
				haxe_started = false;
			}
			
			if (!haxe_started)
			{
				Sys.println("Starting haxe compilation server...");
				
				Thread.create(function ()
				{
					Sys.command("haxe --wait 6000");
				}
				);
				
				haxe_started_in_thread = true;
			}
			else
			{
				Sys.println("Haxe compilation server already running...");
			}
		}
		
		loadBuildDate();
		
		if (build_date == null || !FileSystem.exists(running_path + swf_path))
		{
			if (isNME)
			{
				buildNMEProject();
			}
			else if (project_file != null)
			{
				build();
			}
			else
			{
				buildHaxeBuildFile();
			}
		}
		
		build_date = Date.now();
		
		if (project_file != null || isNME)
		{
			startSWFLoader();
		}
	}
	
	private function buildHaxeBuildFile() 
	{		
		var n:Int = Sys.command("haxe " + running_path + hxml_file);
		if (n == 0)
		{
			Sys.println("Build complete");
			
			updateStats();
		}
		else
		{
			Sys.println("Build failed");
		}
		
		build_date = Date.now();
		
		need_rebuild = false;
		check_interval = 0.5;
	}
	
	private function loadBuildDate() 
	{
		var mytextfile2_data:String = "0";
		
		if (FileSystem.exists(running_path + mytextfile_path))
		{
			var mytextfile2:FileInput = File.read(running_path + mytextfile_path, false);
			mytextfile2_data = mytextfile2.readAll().toString();
			mytextfile2.close();
		}
		
		if (mytextfile2_data == "0")
		{
			if (FileSystem.exists(running_path + swf_path))
			{
				build_date = FileSystem.stat(running_path + swf_path).mtime;
			}
		}
		else
		{
			try 
			{
				build_date = Date.fromString(mytextfile2_data);
			}
			catch (unknown : Dynamic)
			{
				build_date = null;
			}
		}
	}
	
	private function startSWFLoader() 
	{
		if (!release_mode)
		{
			Sys.command("start " + program_path + "SWFLoaderhaxe.swf");
		}
	}
	
	private function isNMEProject():Bool
	{
		var nme:Bool = false;
		
		var xml_file:FileInput = File.read(running_path + project_file);
		var xml_data:Xml = Xml.parse(xml_file.readAll().toString());
		
		var fast:Fast = new Fast(xml_data.firstElement());
		
		var output_data:Fast = fast.node.output;
		
		for (movie in output_data.elements)
		{
			if (movie.has.platform)
			{
				nme = (movie.att.platform == "NME");
				break;
			}
		}
		
		return nme;
	}
	
	private function parseFlashDevelopHxProj():String
	{		
		var haxe_compiler_args:String = "";
		var additional_arguments:String = "";
		
		var xml_file:FileInput = File.read(running_path + project_file);
		var xml_data:Xml = Xml.parse(xml_file.readAll().toString());
		
		var fast:Fast = new Fast(xml_data.firstElement());
		
		var build_xml_data:Fast = fast.node.build;
		
		for (option in build_xml_data.elements)
		{
			if (option.has.mainClass)
			{
				haxe_compiler_args += "-main " + option.att.mainClass;
			}
		}
		
		var haxelib_xml_data:Fast = fast.node.haxelib;
		
		for (library in haxelib_xml_data.elements)
		{
			if (library.att.name != "" && haxe_compiler_args.indexOf(" -lib " + library.att.name) == -1)
			{
				haxe_compiler_args += " -lib " + library.att.name;
			}
		}
		
		for (option in build_xml_data.elements)
		{
			if (option.has.additional && option.att.additional != "")
			{
				additional_arguments = option.att.additional;
				
				var n = additional_arguments.indexOf(" -swf-lib ");
				
				if (n != -1)
				{
					n += " -swf-lib ".length;
					additional_arguments = additional_arguments.substr(0, n) + running_path + additional_arguments.substr(additional_arguments.indexOf(" ", n));
				}
				
				haxe_compiler_args += " " + additional_arguments;
			}
		}
		
		var classpaths:Fast = fast.node.classpaths;
		
		for (class_element in classpaths.elements)
		{
			if (class_element.has.path)
			{
				if (class_element.att.path.indexOf(":\\") != -1)
				{
					haxe_compiler_args += " -cp " + class_element.att.path;
				}
				else
				{				
					haxe_compiler_args += running_path + "\\" + class_element.att.path;
				}
			}
		}
		
		if (fast.hasNode.library)
		{
			var libraries = fast.node.library;
			for (asset in libraries.elements)
			{
				if (asset.att.path != "")
				{
					var path = running_path.substr(0, running_path.length - 1) + "\\"; 
					
					haxe_compiler_args += " -swf-lib " + path +  asset.att.path;
				}
			}
		}
		
		var r:EReg = ~/starling.swc/;
		var r2:EReg = new EReg("--macro patchTypes('starling.patch')", "");
		
		if (r.match(haxe_compiler_args) && !r2.match(haxe_compiler_args))
		{
			haxe_compiler_args += " --macro patchTypes('starling.patch')";
		}
				
		haxe_compiler_args += " -cp " + "\"" + running_path + "src\"";
		
		var output_xml:Fast = fast.node.output;
		
		var width:String = "640";
		var height:String = "480";
		var fps:String = "60";
		var version:String = "11";
		var minorVersion:String = "1";
		var background:String = "FFFFFF";
		
		for (m in output_xml.nodes.movie)
		{
			if (m.has.path)
			{
				haxe_compiler_args += " -swf " + "\"" + running_path + m.att.path + "\"";
				swf_path = m.att.path;
			}
			else if (m.has.width)
			{
				width = m.att.width;
			}
			else if (m.has.height)
			{
				height = m.att.height;
			}
			else if (m.has.fps)
			{
				fps = m.att.fps;
			}
			else if (m.has.version)
			{
				version = m.att.version;
			}
			else if (m.has.minorVersion)
			{
				minorVersion = m.att.minorVersion;
			}
			else if (m.has.background)
			{
				background = m.att.background;
			}
		}
		
		var r:EReg = ~/ -swf-header /;
		if (!r.match(haxe_compiler_args))
		{
			haxe_compiler_args += " -swf-header " + width + ":" + height + ":" + fps + ":" + background.substr(1);
		}
		
		r = ~/ -swf-version /;
		if (!r.match(haxe_compiler_args))
		{
			haxe_compiler_args += " -swf-version " + version;
			
			if (minorVersion != "0")
			{
				 haxe_compiler_args += "." + minorVersion;
			}
		}
		
		if (!release_mode)
		{
			haxe_compiler_args += " -debug";
		}
		//trace(haxe_compiler_args);
		
		checkOutputFolder();
				
		updateTextFile(program_path + "swfpath.txt", running_path + swf_path);
		
		return haxe_compiler_args;
	}
	
	private function checkOutputFolder() 
	{
		if (swf_path.indexOf("\\") != -1)
		{
			var folders:Array<String> = swf_path.split("\\");
			folders.pop();
			
			var folders_path:String = "";
			
			for (folder in folders)
			{
				folders_path += folder + "\\";
				if (!FileSystem.exists(running_path + folders_path))
				{
					FileSystem.createDirectory(running_path + folders_path);
				}
			}
		}
	}
	
	private function isFileModified(file_path:String):Bool
	{		
		var modified:Bool = false;
		
		var filestat:FileStat = FileSystem.stat(file_path);
		
		var delta:Float = filestat.mtime.getTime() - build_date.getTime();
		if ((delta / 1000) > 0)
		{
			modified = true;
		}
		
		return modified;
	}
	
	public function scanFolder(folder_path:String)
	{
		if (need_rebuild)
		{
			return;
		}
		
		var folder_contents:Array<String> = FileSystem.readDirectory(folder_path);
		
		for (item in folder_contents)
		{
			var path:String = folder_path + "\\" + item;
			
			if (!FileSystem.isDirectory(path))
			{
				var file_path:String = folder_path + "\\" + item;
				
				if (isFileModified(file_path))
				{
					need_rebuild = true;
					break;
				}
			}
			else
			{
				scanFolder(folder_path + "\\" + item); 
			}
		}
	}
	
	private function updateStats()
	{
		var build_count:Int = 0;
		
		if (FileSystem.exists(running_path + mystatfile_path))
		{
			var mystatfile:FileInput = File.read(running_path + mystatfile_path, false);
		
			if (mystatfile != null)
			{
				build_count = Std.parseInt(mystatfile.readAll().toString());
				mystatfile.close();
			}
		}
		
		build_count++;
		
		var updatedstatfile:FileOutput = File.write(running_path + mystatfile_path, false);
		updatedstatfile.writeString(Std.string(build_count));
		updatedstatfile.close();
	}
		
	private function parseCompilerArgs(args_str:String):String
	{
		var str:String = args_str;
		
		var path_positions:Array<Array<Int>> = getPathPositions(str);
				
		var i = 0;
		
		while (i < str.length)
		{
			var p:Array<Int> = isInPath(i, path_positions);
			
			if (p == null)
			{
				var n:Int = str.indexOf(" ", i);
				if (n != -1)
				{
					str = str.substr(0, n) + "\n" + str.substr(n + 1);
				}
				else
				{
					break;
				}
				
				i = n + 1;
			}
			else
			{
				i = p[1];
			}
		}
		
		return str;
	}
	
	private function isInPath(n:Int, path_positions:Array<Array<Int>>) 
	{
		var path_pos:Array<Int> = null;
		
		for (p in path_positions)
		{
			if (n >= p[0] && n < p[1])
			{
				path_pos = p;
				break;
			}
		}
		
		return path_pos;
	}
	
	private function getPathPositions(str:String) 
	{
		var path_pos:Array<Array<Int>> = new Array<Array<Int>>();
		
		var i = 0;
		while (i < str.length)
		{
			var n1:Int = str.indexOf("\"", i+1);
			if (n1 == -1)
			{
				break;
			}
			
			var n2:Int = str.indexOf("\"", n1+1);
			
			i = n2;
			
			var path:Array<Int> = new Array<Int>();
			path.push(n1);
			path.push(n2+1);
			path_pos.push(path);
		}
		
		return path_pos;
	}
	
	public function build()
	{							
		updateTextFile(running_path + mytextfile_path, "0");
		
		cleanProject();
		
		//Sys.command("haxe --connect 6000 -prompt " + parseFlashDevelopHxProj());
		var haxe_compiler_arguments:String = parseFlashDevelopHxProj();
		var r:EReg = ~/[\s]/g;
		client_commands = " " + parseCompilerArgs(haxe_compiler_arguments +" -prompt") + "\n\000";
		var r2:EReg = ~/"/gm;
		r2.replace(client_commands, "");
		//var r2:EReg = ~/"(.+)[\n](.+)"/gm;
		//r.match(client_commands);
		//trace(r.matched(0));
		//trace(client_commands);
		buildUsingClient();
		
		build_date = Date.now();
		
		checkBuild();
		
		need_rebuild = false;
		check_interval = 0.5;
	}
	
	function checkBuild() 
	{
		if (!FileSystem.exists(running_path + swf_path))
		{			
			Sys.println("Build failed");			
		}
		else
		{			
			Sys.println("Build complete");
			
			updateTextFile(running_path + mytextfile_path, build_date.toString());
			updateStats();
		}
	}
	
	function cleanProject() 
	{
		if (FileSystem.exists(running_path + swf_path))
		{
			try
			{
				FileSystem.deleteFile(running_path + swf_path);
			}
			catch (unknown:Dynamic)
			{
				
			}
		}
	}
	
	private function updateTextFile(path:String, s:String)
	{
		var file_updated:Bool = false;
		
		while (!file_updated)
		{
			file_updated = true;
			
			try
			{
				mytextfile = File.write(path, false);
			}
			catch (unknown : Dynamic)
			{
				file_updated = false;
			}
			
			if (file_updated)
			{
				mytextfile.writeString(s);
				mytextfile.close();
			}
			else
			{
				Sys.sleep(0.1);
			}
		}
	}
	
	static function main() 
	{
		new Main();
	}
	
}