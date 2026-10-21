package funkin.mobile;

import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class LogcatUtil
{
	public static final FOLDER:String = 'logcat';
	
	public static final BOOT_FILE:String = 'boot.txt';
	
	public static final PREVIOUS_BOOT_FILE:String = 'boot-previous.txt';
	
	public static var directory(default, null):String = '';
	
	public static function init():Void
	{
		#if android
		try
		{
			final func:Null<Dynamic> = lime.system.JNI.createStaticMethod('org/nightmarevision/CrashLogger', 'getLogDirectory', '()Ljava/lang/String;');
			final path:Null<String> = func != null ? func() : null;
			if (path != null && path.length > 0) directory = path;
		}
		catch (e:Dynamic) {}
		#end
	}
	
	public static function startBoot():Void
	{
		#if mobile
		try
		{
			final base = resolveDirectory();
			final boot = Path.join([base, BOOT_FILE]);
			
			if (FileSystem.exists(boot)) File.copy(boot, Path.join([base, PREVIOUS_BOOT_FILE]));
			File.saveContent(boot, '');
		}
		catch (e:Dynamic) {}
		#end
	}
	
	public static function mark(step:String):Void
	{
		#if mobile
		try
		{
			final output = File.append(Path.join([resolveDirectory(), BOOT_FILE]), false);
			output.writeString(DateTools.format(Date.now(), '%H:%M:%S') + ' ' + step + '\n');
			output.flush();
			output.close();
		}
		catch (e:Dynamic) {}
		#end
	}
	
	static function resolveDirectory():String
	{
		#if sys
		if (directory.length == 0) directory = Path.join([StorageUtil.directory.length > 0 ? StorageUtil.directory : Sys.getCwd(), FOLDER]);
		if (!FileSystem.exists(directory)) FileSystem.createDirectory(directory);
		#end
		
		return directory;
	}
}
