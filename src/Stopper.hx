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

import sys.net.Host;
import sys.net.Socket;

class Stopper 
{
	
	static function main() 
	{
		Sys.println("HaxeBuilder  Copyright (C) 2013  AS3Boyan");
		Sys.println("This program comes with ABSOLUTELY NO WARRANTY\n");
		
		var s:Socket = new Socket();
		
		var connected:Bool = false;
		
		while (!connected)
		{
			connected = true;
			try
			{
				s.connect(new Host("127.0.0.1"), 6002);
			}
			catch (unknown:Dynamic)
			{
				trace(unknown);
				connected = false;
			}
			
			Sys.sleep(0.5);
		}
		
		if (connected)
		{
			var successful_write:Bool = false;
		
			while (!successful_write)
			{
				successful_write = true;
				
				try
				{
					s.output.writeString("stop");
				}
				catch (unknown:Dynamic)
				{
					successful_write = false;
				}
			}
			
			s.close();
		}
		
		Sys.println("Builder tool was stopped");
	}
	
}