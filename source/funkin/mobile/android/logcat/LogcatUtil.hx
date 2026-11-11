package funkin.mobile.android.logcat;

import funkin.mobile.backend.StorageUtil;

import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

enum abstract LogLevel(String) to String
{
	var DEBUG = 'D';
	var INFO = 'I';
	var WARN = 'W';
	var ERROR = 'E';
}

class LogcatUtil
{
	public static final FOLDER:String = 'logcat';

	public static final BOOT_FILE:String = 'boot.txt';

	public static final PREVIOUS_BOOT_FILE:String = 'boot-previous.txt';

	public static final SESSION_PREFIX:String = 'game-';

	public static var directory(default, null):String = '';

	public static var sessionFile(default, null):String = '';

	public static var captureTraces:Bool = true;

	public static var debugEnabled:Bool = true;

	public static var maxSessionFiles:Int = 10;

	public static var flushSize:Int = 4096;

	public static var flushInterval:Float = 2;

	static var buffer:StringBuf = new StringBuf();

	static var bufferLength:Int = 0;

	static var lastFlush:Float = 0;

	static var started:Bool = false;

	static var hooked:Bool = false;

	#if target.threaded
	static final lock:sys.thread.Mutex = new sys.thread.Mutex();
	#end

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
		#if (mobile && sys)
		try
		{
			final base = resolveDirectory();
			final boot = Path.join([base, BOOT_FILE]);

			if (FileSystem.exists(boot)) File.copy(boot, Path.join([base, PREVIOUS_BOOT_FILE]));
			File.saveContent(boot, '');

			sessionFile = Path.join([base, SESSION_PREFIX + DateTools.format(Date.now(), '%Y-%m-%d_%H-%M-%S') + '.txt']);
			File.saveContent(sessionFile, header());
			started = true;
			lastFlush = haxe.Timer.stamp();

			pruneSessions();
			hookTraces();
			hookApplication();
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function mark(step:String):Void
	{
		#if (mobile && sys)
		try
		{
			final output = File.append(Path.join([resolveDirectory(), BOOT_FILE]), false);
			output.writeString(stamp() + ' ' + step + '\n');
			output.flush();
			output.close();
		}
		catch (e:Dynamic) {}

		log(INFO, step);
		flush();
		#end
	}

	public static inline function debug(message:String):Void
	{
		if (debugEnabled) log(DEBUG, message);
	}

	public static inline function info(message:String):Void
	{
		log(INFO, message);
	}

	public static inline function warn(message:String):Void
	{
		log(WARN, message);
	}

	public static function error(message:String):Void
	{
		log(ERROR, message);
		flush();
	}

	public static function log(level:LogLevel, message:String):Void
	{
		#if (mobile && sys)
		if (!started) return;

		final line = stamp() + ' ' + level + ' ' + message + '\n';

		#if target.threaded
		lock.acquire();
		#end
		buffer.add(line);
		bufferLength += line.length;
		final full = bufferLength >= flushSize || haxe.Timer.stamp() - lastFlush >= flushInterval;
		#if target.threaded
		lock.release();
		#end

		if (full) flush();
		#end
	}

	public static function flush():Void
	{
		#if (mobile && sys)
		if (!started) return;

		#if target.threaded
		lock.acquire();
		#end
		final text = buffer.toString();
		buffer = new StringBuf();
		bufferLength = 0;
		lastFlush = haxe.Timer.stamp();
		#if target.threaded
		lock.release();
		#end

		if (text.length == 0) return;

		try
		{
			final output = File.append(sessionFile, false);
			output.writeString(text);
			output.flush();
			output.close();
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function getSessionLog():String
	{
		#if sys
		flush();
		try
		{
			if (sessionFile.length > 0 && FileSystem.exists(sessionFile)) return File.getContent(sessionFile);
		}
		catch (e:Dynamic) {}
		#end

		return '';
	}

	static function header():String
	{
		final lines = [
			'NightmareVision session log',
			'Started: ' + DateTools.format(Date.now(), '%Y-%m-%d %H:%M:%S'),
			'Version: ' + (lime.app.Application.current?.meta.get('version') ?? 'unknown'),
			'Device: ' + safe(() -> funkin.mobile.native.NativeUtil.getDeviceSummary()),
			'Storage: ' + StorageUtil.directory,
			''
		];
		return lines.join('\n') + '\n';
	}

	static function safe(read:Void->String):String
	{
		try
		{
			return read();
		}
		catch (e:Dynamic)
		{
			return 'unknown';
		}
	}

	static function hookTraces():Void
	{
		if (hooked || !captureTraces) return;
		hooked = true;

		final original = haxe.Log.trace;
		haxe.Log.trace = (value:Dynamic, ?infos:haxe.PosInfos) -> {
			original(value, infos);
			log(DEBUG, haxe.Log.formatOutput(value, infos));
		};
	}

	static function hookApplication():Void
	{
		final application = lime.app.Application.current;
		if (application == null) return;

		application.onExit.add((_) -> flush());

		final window = application.window;
		if (window != null)
		{
			window.onDeactivate.add(flush);
			window.onFocusOut.add(flush);
		}
	}

	static function pruneSessions():Void
	{
		#if sys
		try
		{
			final base = resolveDirectory();
			final sessions = [for (name in FileSystem.readDirectory(base)) if (name.startsWith(SESSION_PREFIX)) name];
			sessions.sort((a, b) -> a > b ? -1 : (a < b ? 1 : 0));

			for (index in maxSessionFiles...sessions.length)
				FileSystem.deleteFile(Path.join([base, sessions[index]]));
		}
		catch (e:Dynamic) {}
		#end
	}

	static inline function stamp():String
	{
		return DateTools.format(Date.now(), '%H:%M:%S');
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
