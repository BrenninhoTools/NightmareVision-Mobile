package funkin.mobile;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;

import lime.utils.Assets as LimeAssets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef CopyResult =
{
	var copied:Int;
	var failed:Array<String>;
}

class StorageUtil
{
	public static final COPY_FOLDERS:Array<String> = ['assets/', 'content/'];

	public static final ALWAYS_UPDATE_FOLDERS:Array<String> = ['assets/'];

	public static final MANIFEST_FILE:String = '.storage-manifest.json';

	public static final ERROR_FILE:String = 'copy-errors.txt';

	public static final TEMP_SUFFIX:String = '.copying';

	public static var directory(default, null):String = '';

	public static var ready(default, null):Bool = false;

	static var manifest:Map<String, Int> = [];

	static var manifestVersion:String = '';

	public static function init():Void
	{
		#if sys
		for (candidate in getStorageCandidates())
		{
			if (candidate == null || candidate.length == 0) continue;

			final path = Path.addTrailingSlash(Path.normalize(candidate));

			if (prepareDirectory(path))
			{
				directory = path;
				break;
			}
		}

		if (directory.length == 0)
		{
			showError('Could not find a writable storage directory for the game files.');
			return;
		}

		try
		{
			Sys.setCwd(directory);
			ready = true;
		}
		catch (e:Dynamic)
		{
			showError('Could not access the storage directory:\n$directory\n\n$e');
			return;
		}

		loadManifest();
		#end
	}

	public static function getStorageDirectory():String
	{
		for (candidate in getStorageCandidates())
		{
			if (candidate != null && candidate.length > 0) return Path.addTrailingSlash(candidate);
		}

		return '';
	}

	static function getStorageCandidates():Array<Null<String>>
	{
		final candidates:Array<Null<String>> = [];

		#if android
		try
		{
			candidates.push(extension.androidtools.content.Context.getExternalFilesDir());
		}
		catch (e:Dynamic) {}

		try
		{
			candidates.push(extension.androidtools.content.Context.getFilesDir());
		}
		catch (e:Dynamic) {}

		candidates.push(lime.system.System.applicationStorageDirectory);
		#elseif ios
		candidates.push(lime.system.System.documentsDirectory);
		candidates.push(lime.system.System.applicationStorageDirectory);
		#elseif sys
		candidates.push(Sys.getCwd());
		#end

		return candidates;
	}

	static function prepareDirectory(path:String):Bool
	{
		#if sys
		try
		{
			if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
			if (!FileSystem.isDirectory(path)) return false;

			final probe = Path.join([path, '.write-test']);
			File.saveContent(probe, 'ok');
			final valid = File.getContent(probe) == 'ok';
			FileSystem.deleteFile(probe);

			return valid;
		}
		catch (e:Dynamic) {}
		#end

		return false;
	}

	public static function getVersion():String
	{
		return lime.app.Application.current?.meta?.get('version') ?? '0';
	}

	public static function getCopyableAssets():Array<String>
	{
		final ids:Array<String> = [];
		final seen:Map<String, Bool> = [];

		for (id in LimeAssets.list())
		{
			final normalized = normalizeId(id);
			if (normalized == null || seen.exists(normalized)) continue;

			seen.set(normalized, true);
			ids.push(id);
		}

		return ids;
	}

	public static function getPendingFiles():Array<String>
	{
		final files:Array<String> = [];

		#if sys
		if (!ready) return files;

		final updated = manifestVersion != getVersion();

		for (id in getCopyableAssets())
		{
			if (needsCopy(id, updated)) files.push(id);
		}
		#end

		return files;
	}

	static function needsCopy(id:String, updated:Bool):Bool
	{
		#if sys
		final target = normalizeId(id);
		if (target == null) return false;

		try
		{
			if (!FileSystem.exists(target) || FileSystem.isDirectory(target)) return true;

			final size = FileSystem.stat(target).size;
			if (size == 0) return true;

			final recorded = manifest.get(target);

			if (recorded != null && recorded != size)
			{
				return isAlwaysUpdated(target);
			}

			if (updated)
			{
				if (isAlwaysUpdated(target)) return true;
				return recorded != null && recorded == size;
			}
		}
		catch (e:Dynamic)
		{
			return true;
		}
		#end

		return false;
	}

	public static function copyAsset(id:String):Bool
	{
		#if sys
		final target = normalizeId(id);
		if (target == null) return false;

		final bytes = readAssetBytes(id);
		if (bytes == null) return false;

		final temp = target + TEMP_SUFFIX;

		try
		{
			final folder = Path.directory(target);
			if (folder.length > 0 && !FileSystem.exists(folder)) FileSystem.createDirectory(folder);

			File.saveBytes(temp, bytes);

			if (FileSystem.stat(temp).size != bytes.length)
			{
				deleteQuietly(temp);
				return false;
			}

			if (FileSystem.exists(target)) FileSystem.deleteFile(target);
			FileSystem.rename(temp, target);

			if (!FileSystem.exists(target) || FileSystem.stat(target).size != bytes.length) return false;

			manifest.set(target, bytes.length);
			return true;
		}
		catch (e:Dynamic)
		{
			deleteQuietly(temp);
		}
		#end

		return false;
	}

	static function readAssetBytes(id:String):Null<Bytes>
	{
		try
		{
			final bytes = LimeAssets.getBytes(id);
			if (bytes != null) return bytes;
		}
		catch (e:Dynamic) {}

		#if sys
		try
		{
			final path = LimeAssets.getPath(id);
			if (path != null)
			{
				final bytes = lime.utils.Bytes.fromFile(path);
				if (bytes != null) return bytes;
			}
		}
		catch (e:Dynamic) {}
		#end

		return null;
	}

	public static function copyAll(files:Array<String>):CopyResult
	{
		final failed:Array<String> = [];
		var copied = 0;

		for (id in files)
		{
			if (copyAsset(id) || copyAsset(id)) copied++;
			else failed.push(id);
		}

		return {copied: copied, failed: failed};
	}

	public static function finishCopy(failed:Array<String>):Array<String>
	{
		#if sys
		if (!ready) return [];

		final stillFailed = [for (id in failed) if (!copyAsset(id)) id];

		try
		{
			if (stillFailed.length == 0) manifestVersion = getVersion();
			saveManifest();

			if (stillFailed.length > 0) File.saveContent(ERROR_FILE, stillFailed.join('\n'));
			else deleteQuietly(ERROR_FILE);
		}
		catch (e:Dynamic) {}

		cleanTempFiles();

		return stillFailed;
		#else
		return [];
		#end
	}

	public static function readStoredVersion():String
	{
		return manifestVersion;
	}

	public static function createDirectories(path:String):Void
	{
		#if sys
		if (path.length > 0 && !FileSystem.exists(path)) FileSystem.createDirectory(path);
		#end
	}

	static function loadManifest():Void
	{
		manifest.clear();
		manifestVersion = '';

		#if sys
		try
		{
			if (!FileSystem.exists(MANIFEST_FILE)) return;

			final data:Dynamic = Json.parse(File.getContent(MANIFEST_FILE));
			manifestVersion = Std.string(data.version ?? '');

			final files:Dynamic = data.files;
			if (files != null)
			{
				for (key in Reflect.fields(files))
				{
					final size:Null<Int> = Reflect.field(files, key);
					if (size != null) manifest.set(key, size);
				}
			}
		}
		catch (e:Dynamic)
		{
			manifest.clear();
			manifestVersion = '';
		}
		#end
	}

	static function saveManifest():Void
	{
		#if sys
		final files:Dynamic = {};
		for (key => size in manifest)
			Reflect.setField(files, key, size);

		File.saveContent(MANIFEST_FILE, Json.stringify({version: manifestVersion, files: files}));
		#end
	}

	static function cleanTempFiles():Void
	{
		#if sys
		for (folder in COPY_FOLDERS)
			cleanTempFilesIn(Path.removeTrailingSlashes(folder));
		#end
	}

	static function cleanTempFilesIn(folder:String):Void
	{
		#if sys
		try
		{
			if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return;

			for (entry in FileSystem.readDirectory(folder))
			{
				final path = Path.join([folder, entry]);

				if (FileSystem.isDirectory(path)) cleanTempFilesIn(path);
				else if (entry.endsWith(TEMP_SUFFIX)) deleteQuietly(path);
			}
		}
		catch (e:Dynamic) {}
		#end
	}

	static function deleteQuietly(path:String):Void
	{
		#if sys
		try
		{
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) FileSystem.deleteFile(path);
		}
		catch (e:Dynamic) {}
		#end
	}

	static function normalizeId(id:String):Null<String>
	{
		if (id == null || id.length == 0) return null;

		var path = id;

		final colon = path.indexOf(':');
		if (colon != -1)
		{
			final library = path.substr(0, colon);
			if (library != 'default') return null;
			path = path.substr(colon + 1);
		}

		path = Path.normalize(path);

		while (path.startsWith('./'))
			path = path.substr(2);

		if (path.contains('..')) return null;

		for (folder in COPY_FOLDERS)
		{
			if (path.startsWith(folder) && path.length > folder.length) return path;
		}

		return null;
	}

	static function isAlwaysUpdated(path:String):Bool
	{
		for (folder in ALWAYS_UPDATE_FOLDERS)
		{
			if (path.startsWith(folder)) return true;
		}

		return false;
	}

	static function showError(message:String):Void
	{
		try
		{
			lime.app.Application.current?.window?.alert(message, 'Storage Error');
		}
		catch (e:Dynamic) {}
	}
}
