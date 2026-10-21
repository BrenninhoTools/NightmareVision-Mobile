package funkin.mobile;

import haxe.io.Path;

import lime.utils.Assets as LimeAssets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class StorageUtil
{
	public static final COPY_FOLDERS:Array<String> = ['assets/', 'content/'];

	public static final UPDATE_FOLDERS:Array<String> = ['assets/'];

	public static final VERSION_FILE:String = '.storage-version';

	public static final ERROR_FILE:String = 'copy-errors.txt';

	public static var directory(default, null):String = '';

	public static function init():Void
	{
		#if sys
		directory = getStorageDirectory();

		try
		{
			createDirectories(directory);
			Sys.setCwd(directory);
		}
		catch (e:Dynamic)
		{
			lime.app.Application.current?.window?.alert('Could not access the storage directory:\n$directory\n\n$e', 'Storage Error');
		}
		#end
	}

	public static function getStorageDirectory():String
	{
		#if android
		try
		{
			final path = extension.androidtools.content.Context.getExternalFilesDir();
			if (path != null && path.length > 0) return Path.addTrailingSlash(path);
		}
		catch (e:Dynamic) {}
		
		return Path.addTrailingSlash(lime.system.System.applicationStorageDirectory);
		#elseif ios
		return Path.addTrailingSlash(lime.system.System.documentsDirectory);
		#elseif sys
		return Path.addTrailingSlash(Sys.getCwd());
		#else
		return '';
		#end
	}

	public static function getVersion():String
	{
		return lime.app.Application.current?.meta?.get('version') ?? '0';
	}

	public static function getPendingFiles():Array<String>
	{
		final files:Array<String> = [];

		#if sys
		final updated = readStoredVersion() != getVersion();

		for (id in LimeAssets.list())
		{
			if (!isCopyable(id)) continue;

			if (!FileSystem.exists(id) || (updated && isUpdatable(id))) files.push(id);
		}
		#end

		return files;
	}

	public static function copyAsset(id:String):Bool
	{
		#if sys
		try
		{
			final bytes = LimeAssets.getBytes(id);
			if (bytes == null) return false;

			final folder = Path.directory(id);
			if (folder.length > 0) createDirectories(folder);

			File.saveBytes(id, bytes);
			return true;
		}
		catch (e:Dynamic) {}
		#end

		return false;
	}

	public static function finishCopy(failed:Array<String>):Void
	{
		#if sys
		try
		{
			File.saveContent(VERSION_FILE, getVersion());

			if (failed.length > 0) File.saveContent(ERROR_FILE, failed.join('\n'));
			else if (FileSystem.exists(ERROR_FILE)) FileSystem.deleteFile(ERROR_FILE);
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function readStoredVersion():String
	{
		#if sys
		try
		{
			if (FileSystem.exists(VERSION_FILE)) return File.getContent(VERSION_FILE).trim();
		}
		catch (e:Dynamic) {}
		#end

		return '';
	}

	public static function createDirectories(path:String):Void
	{
		#if sys
		if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
		#end
	}

	static function isCopyable(id:String):Bool
	{
		if (id.contains(':')) return false;

		for (folder in COPY_FOLDERS)
		{
			if (id.startsWith(folder)) return true;
		}

		return false;
	}

	static function isUpdatable(id:String):Bool
	{
		for (folder in UPDATE_FOLDERS)
		{
			if (id.startsWith(folder)) return true;
		}

		return false;
	}
}
