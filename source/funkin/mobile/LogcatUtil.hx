package funkin.mobile;

import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

class LogcatUtil
{
	public static final FOLDER:String = 'logcat';

	public static final SESSION_FILE:String = 'session.txt';

	public static final MARKER_FILE:String = '.running';
	
	public static final BOOT_FILE:String = 'boot.txt';

	public static var maxFiles:Int = 10;

	public static var maxLines:Int = 8000;

	public static var directory(default, null):String = '';

	#if android
	static var liveProcess:Null<Process> = null;
	#end

	public static function init():Void
	{
		#if android
		try
		{
			directory = Path.join([StorageUtil.directory.length > 0 ? StorageUtil.directory : Sys.getCwd(), FOLDER]);
			if (!FileSystem.exists(directory)) FileSystem.createDirectory(directory);

			archivePreviousSession();
			startLiveCapture();

			File.saveContent(Path.join([directory, MARKER_FILE]), Std.string(Date.now()));

			lime.app.Application.current?.onExit.add(_ -> stop());
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function mark(step:String):Void
	{
		#if mobile
		try
		{
			final base = directory.length > 0 ? directory : Path.join([StorageUtil.directory.length > 0 ? StorageUtil.directory : Sys.getCwd(), FOLDER]);
			if (!FileSystem.exists(base)) FileSystem.createDirectory(base);
			
			final output = File.append(Path.join([base, BOOT_FILE]), false);
			output.writeString(DateTools.format(Date.now(), '%H:%M:%S') + ' ' + step + '\n');
			output.flush();
			output.close();
		}
		catch (e:Dynamic) {}
		#end
	}
	
	public static function startBoot():Void
	{
		#if mobile
		try
		{
			final base = Path.join([StorageUtil.directory.length > 0 ? StorageUtil.directory : Sys.getCwd(), FOLDER]);
			if (!FileSystem.exists(base)) FileSystem.createDirectory(base);
			
			final boot = Path.join([base, BOOT_FILE]);
			if (FileSystem.exists(boot)) File.copy(boot, Path.join([base, 'boot-previous.txt']));
			File.saveContent(boot, '');
		}
		catch (e:Dynamic) {}
		#end
	}
	
	public static function stop():Void
	{
		#if android
		try
		{
			final marker = Path.join([directory, MARKER_FILE]);
			if (FileSystem.exists(marker)) FileSystem.deleteFile(marker);
		}
		catch (e:Dynamic) {}

		try
		{
			liveProcess?.kill();
			liveProcess?.close();
		}
		catch (e:Dynamic) {}

		liveProcess = null;
		#end
	}

	#if android
	static function archivePreviousSession():Void
	{
		final session = Path.join([directory, SESSION_FILE]);
		final marker = Path.join([directory, MARKER_FILE]);
		final crashed = FileSystem.exists(marker);
		final stamp = DateTools.format(Date.now(), '%Y-%m-%d_%H-%M-%S');

		if (FileSystem.exists(session) && FileSystem.stat(session).size > 0)
		{
			final name = (crashed ? 'crash-session-' : 'session-') + stamp + '.txt';
			FileSystem.rename(session, Path.join([directory, name]));
		}

		if (crashed)
		{
			final dump = runLogcat(['-d', '-v', 'threadtime', '-t', Std.string(maxLines), '-b', 'main', '-b', 'system', '-b', 'crash']);
			if (dump.length > 0) File.saveContent(Path.join([directory, 'crash-buffer-' + stamp + '.txt']), dump);
		}

		pruneOldFiles();
	}

	static function startLiveCapture():Void
	{
		final session = Path.join([directory, SESSION_FILE]);

		try
		{
			liveProcess = new Process('logcat', [
				'-v', 'threadtime',
				'-b', 'main',
				'-b', 'system',
				'-b', 'crash',
				'-T', '1',
				'-f', session
			]);
		}
		catch (e:Dynamic)
		{
			liveProcess = null;
		}
	}

	static function runLogcat(args:Array<String>):String
	{
		try
		{
			final process = new Process('logcat', args);
			final output = process.stdout.readAll().toString();
			process.close();
			return output;
		}
		catch (e:Dynamic) {}

		return '';
	}

	static function pruneOldFiles():Void
	{
		try
		{
			final files = [
				for (entry in FileSystem.readDirectory(directory))
					if (entry.endsWith('.txt') && entry != SESSION_FILE && entry != BOOT_FILE && entry != 'boot-previous.txt') entry
			];

			files.sort((a, b) -> {
				final timeA = FileSystem.stat(Path.join([directory, a])).mtime.getTime();
				final timeB = FileSystem.stat(Path.join([directory, b])).mtime.getTime();
				return timeA < timeB ? -1 : (timeA > timeB ? 1 : 0);
			});

			while (files.length > maxFiles)
				FileSystem.deleteFile(Path.join([directory, files.shift()]));
		}
		catch (e:Dynamic) {}
	}
	#end
}
