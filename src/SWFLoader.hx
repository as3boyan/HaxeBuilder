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

import flash.display.Loader;
import flash.display.Sprite;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.errors.Error;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.KeyboardEvent;
import flash.events.TimerEvent;
import flash.Lib;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.system.ApplicationDomain;
import flash.system.LoaderContext;
import flash.system.Security;
import flash.system.System;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.ui.Keyboard;
import haxe.Timer;

class SWFLoader 
{
	public var loaded_movieclip:Sprite;
	private var myloader:Loader;
	private var req:URLRequest;
	private var text_loader:URLLoader;
	private var text_req:URLRequest;
	private var build_date:Date;
	private var date_text:TextField;
	private var debug_text:TextField;
	private var myloadercontext:LoaderContext;
	private var swf_path_loader:URLLoader;
	private var swf_path_req:URLRequest;
	private var swf_path:String;
	private var swf_path_available:Bool;
	var date_valid:Bool;
	var last_build_date:Date;
	
	public function new()
	{				
		Std.random(1);
		Std.string(1.2323);
		Std.int(1.0);
		Std.parseFloat("1");
		Std.parseInt("1");
		Std.is(1, Int);
		
		Timer.delay(function () { }, 1);
		Lib.getTimer();
		
		date_text = new TextField();
		date_text.autoSize = TextFieldAutoSize.LEFT;
		Lib.current.stage.addChild(date_text);
		
		debug_text = new TextField();
		debug_text.text = "";
		debug_text.y = 100;
		debug_text.autoSize = TextFieldAutoSize.LEFT;
		Lib.current.stage.addChild(debug_text);
		//
		//debug_text.text = Security.sandboxType;
		
		swf_path_req = new URLRequest("swfpath.txt");
		swf_path_loader = new URLLoader();
		swf_path_loader.addEventListener(Event.COMPLETE, onLoadSwfPathComplete);
		swf_path_loader.addEventListener(IOErrorEvent.IO_ERROR, function (e) { swf_path_available = false; } );
		
		swf_path_available = false;
		
		var text_loader_timer:Timer = new Timer(500);
		text_loader_timer.run = function ()
		{
			swf_path_available = true;
			
			try
			{
				swf_path_loader.load(swf_path_req);
			}
			catch (e:Error)
			{
				swf_path_available = false;
				//trace(e.message);
				debug_text.appendText(e.getStackTrace());
			}
			
			if (swf_path_available)
			{
				text_loader_timer.stop();
			}
		}
	}
		
	private function onLoadSwfPathComplete(e:Event):Void 
	{
		swf_path = cast(swf_path_loader.data, String);
				
		myloader = new Loader();
		myloader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onError);
		myloader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadComplete);
		myloader.contentLoaderInfo.addEventListener(Event.INIT, onInit);
		//req = new URLRequest("Stage3Dtest.swf");
						
		req = new URLRequest(swf_path);
		
		myloadercontext = new LoaderContext(false, new ApplicationDomain(ApplicationDomain.currentDomain));
		//myloadercontext.allowCodeImport = true;
		//myloadercontext.allowLoadBytesCodeExecution = true;
		
		//updateSWF();
	
		//Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		
		text_req = new URLRequest(swf_path.substr(0, swf_path.lastIndexOf("\\")+1) + "mytext.txt");
		text_loader = new URLLoader();
		text_loader.addEventListener(Event.COMPLETE, onLoadTextComplete);
		text_loader.addEventListener(IOErrorEvent.IO_ERROR, function (e) {  } );
		
		var myTimer:Timer = new Timer(500);
		myTimer.run = function ()
		{
			loadTextFile();
		}	
	}
	
	private function loadTextFile():Void
	{
		try
		{
			text_loader.load(text_req);
		}
		catch (e:Error)
		{
			//debug_text.appendText(Std.string(e.errorID));
			debug_text.appendText(e.getStackTrace());
		}
	}
	
	private function onKeyDown(e:KeyboardEvent):Void 
	{
		if (e.keyCode == Keyboard.C)
		{
			onTick(null);
		}
		else if (e.keyCode == Keyboard.L)
		{
			loadTextFile();
		}
	}
	
	private function onLoadTextComplete(e:Event):Void 
	{
		if (Std.is(text_loader.data, String))
		{
			var loaded_date:String = text_loader.data;
			
			if (loaded_date == "0") 
			{
				if (build_date != null)
				{
					date_text.text = build_date.toString();
				}
			}
			else
			{		
				date_text.text = "";
				
				date_valid = true;
				
				try
				{
					last_build_date = Date.fromString(loaded_date);
				}
				catch (unknown:Dynamic)
				{
					date_valid = false;
				}
				
				if (!date_valid)
				{
					return;
				}
				
				if (build_date != null)
				{
					if ((last_build_date.getTime() - build_date.getTime())>0)
					{
						updateSWF();
					}
				}
				else
				{
					updateSWF();
				}

				build_date = last_build_date;
			}
		}
	}
	
	static function main() 
	{
		var stage = Lib.current.stage;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		// entry point
		
		new SWFLoader();
	}
	
	private function updateSWF()
	{
		onTick(null);
		
		//myloadercontext = new LoaderContext(false, new ApplicationDomain());
		
		try 
		{
			//myloader.load(req, myloadercontext);
			myloader.load(req);
			Lib.current.stage.addChild(debug_text);
		}
		catch (e:Error)
		{
			//trace(e);
			//debug_text.appendText(Std.string(e.errorID));
			debug_text.appendText(e.getStackTrace());
		}
	}
	
	private function onInit(e:Event):Void 
	{
		loaded_movieclip = cast(e.currentTarget.content, Sprite);
		Lib.current.stage.addChild(loaded_movieclip);
	}
	
	private function onTick(object) 
	{
		//Lib.current.stage.removeChild(loaded_movieclip);
		
		//Lib.current.stage.removeChildren(1);
		
		//var c:Array<DisplayObject> = new Array<DisplayObject>();
		//
		//for (i in 1...Lib.current.stage.numChildren)
		//{
			//var sprite:DisplayObject = Lib.current.stage.getChildAt(i);
			//if (sprite != date_text)
			//{
				//c.push(sprite);
			//}
		//}
		//
		//for (item in c)
		//{
			//if (item.parent != null)
			//{
				//item.parent.removeChild(item);
			//}
		//}
		//myloader.unload();
		
		//trace(Lib.current.stage.numChildren);
		
		//if (loaded_movieclip != null)
		//{
			//trace(loaded_movieclip.parent);
			//loaded_movieclip.parent.removeChild(loaded_movieclip);
		//}
		
		if (loaded_movieclip != null)
		{
			//for (i in 0...Lib.current.stage.numChildren)
			//{
				//Lib.current.stage.dispatchEvent(new Event(Event.REMOVED_FROM_STAGE));
				
			//}
			Lib.current.stage.removeChildren(1);
			myloader.unload();
			//myloader.unloadAndStop(true);
			if (Lib.current.stage.stage3Ds[0].context3D != null)
			{
				Lib.current.stage.stage3Ds[0].context3D.dispose();
			}
			
			loaded_movieclip = null;
			//for (i in 0...loaded_movieclip.numChildren)
			//{
				//loaded_movieclip.getChildAt(i).dispatchEvent(new Event(Event.REMOVED_FROM_STAGE));
			//}
		}
		
		//trace(Lib.current.stage.numChildren);
		
		//
		//loaded_movieclip = null;
	}
	
	private function onLoadComplete(e:Event):Void 
	{
		//trace("load complete");
	}
	
	private function onError(e:IOErrorEvent):Void 
	{
		//trace(e.text);
	}
	
}