package funkin.mobile;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;

import lime.utils.Assets as LimeAssets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class StorageUtil
{
	public static final COPY_FOLDERS:Array<String> = ['assets/', 'content/'];

	public static final ALWAYS_UPDATE_FOLDERS:Array<String> = ['assets/'];

	public static final MANIFEST_FILE:String = '.storage-manifest.json';

	public static final ERROR_FILE:String = 'copy-errors.txt';

	public static final TEMP_SUFFIX:String = '.copying';

	public static var saveInterval:Float = 1.5;

	public static var directory(default, null):String = '';

	public static var ready(default, null):Bool = false;

	static var manifest:Map<String, Int> = [];

	static var refresh:Map<String, Bool> = [];

	static var manifestVersion:String = '';

	static var dirty:Bool = false;

	static var lastSave:Float = 0;

	#if android
	static var javaCopy:Null<Dynamic> = null;

	static var javaChecked:Bool = false;
	#end

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
		candidates.push(callStringFrom(NATIVE_EXTRACTOR, 'getGameDirectory'));
		candidates.push(callString('getMediaDirectory'));
		candidates.push(callString('getExternalFilesDirectory'));
		candidates.push(callString('getInternalFilesDirectory'));
		
		candidates.push(lime.system.System.applicationStorageDirectory);
		#elseif ios
		candidates.push(lime.system.System.documentsDirectory);
		candidates.push(lime.system.System.applicationStorageDirectory);
		#elseif sys
		candidates.push(Sys.getCwd());
		#end

		return candidates;
	}

	#if android
	public static final ANDROID_HELPER:String = 'org/nightmarevision/StorageHelper';
	
	public static final NATIVE_EXTRACTOR:String = 'org/nightmarevision/AssetExtractor';
	
	public static final NATIVE_STATUS_FILE:String = '.copy-status';
	
	public static var nativeCopyTimeout:Float = 900;
	
	public static function waitForNativeCopy():Bool
	{
		#if sys
		if (!ready) return false;
		
		final start = haxe.Timer.stamp();
		var lastMark = start;
		
		while (true)
		{
			final status = readNativeStatus();
			
			if (status == null) return false;
			if (status == 'done') return true;
			if (status != 'running') return false;
			
			final now = haxe.Timer.stamp();
			if (now - start > nativeCopyTimeout) return false;
			
			if (now - lastMark > 2)
			{
				lastMark = now;
				LogcatUtil.mark('native copy running');
			}
			
			Sys.sleep(0.05);
		}
		#end
		
		return false;
	}
	
	public static function readNativeStatus():Null<String>
	{
		#if sys
		try
		{
			if (!FileSystem.exists(NATIVE_STATUS_FILE)) return null;
			return File.getContent(NATIVE_STATUS_FILE).trim();
		}
		catch (e:Dynamic) {}
		#end
		
		return null;
	}
	
	public static function callStringFrom(className:String, method:String):Null<String>
	{
		try
		{
			final func:Null<Dynamic> = lime.system.JNI.createStaticMethod(className, method, '()Ljava/lang/String;');
			if (func != null)
			{
				final result:Null<String> = func();
				if (result != null && result.length > 0) return result;
			}
		}
		catch (e:Dynamic) {}
		
		return null;
	}
	
	public static function callString(method:String):Null<String>
	{
		try
		{
			final func:Null<Dynamic> = lime.system.JNI.createStaticMethod(ANDROID_HELPER, method, '()Ljava/lang/String;');
			if (func != null)
			{
				final result:Null<String> = func();
				if (result != null && result.length > 0) return result;
			}
		}
		catch (e:Dynamic) {}
		
		return null;
	}
	
	public static function getSdkVersion():Int
	{
		try
		{
			final func:Null<Dynamic> = lime.system.JNI.createStaticMethod(ANDROID_HELPER, 'getSdkVersion', '()I');
			if (func != null) return func();
		}
		catch (e:Dynamic) {}
		
		return 0;
	}
	
	public static function hasPermission(permission:String):Bool
	{
		try
		{
			final func:Null<Dynamic> = lime.system.JNI.createStaticMethod(ANDROID_HELPER, 'hasPermission', '(Ljava/lang/String;)Z');
			if (func != null) return func(permission);
		}
		catch (e:Dynamic) {}
		
		return false;
	}
	
	public static function hasAllFilesAccess():Bool
	{
		try
		{
			final func:Null<Dynamic> = lime.system.JNI.createStaticMethod(ANDROID_HELPER, 'hasAllFilesAccess', '()Z');
			if (func != null) return func();
		}
		catch (e:Dynamic) {}
		
		return false;
	}
	
	public static function requestPermissions(?permissions:Array<String>):Void
	{
		if (permissions == null)
		{
			permissions = getSdkVersion() >= 33 ? [
				'android.permission.READ_MEDIA_AUDIO',
				'android.permission.READ_MEDIA_VIDEO',
				'android.permission.READ_MEDIA_IMAGES'
			] : [
				'android.permission.READ_EXTERNAL_STORAGE',
				'android.permission.WRITE_EXTERNAL_STORAGE'
			];
		}
		
		try
		{
			final func:Null<Dynamic> = lime.system.JNI.createStaticMethod(ANDROID_HELPER, 'requestPermissions', '(Ljava/lang/String;)V');
			if (func != null) func(permissions.join(','));
		}
		catch (e:Dynamic) {}
	}
	
	public static function requestAllFilesAccess():Void
	{
		try
		{
			final func:Null<Dynamic> = lime.system.JNI.createStaticMethod(ANDROID_HELPER, 'requestAllFilesAccess', '()V');
			if (func != null) func();
		}
		catch (e:Dynamic) {}
	}
	#end
	
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

		for (id in getCopyableAssets())
		{
			if (needsCopy(id)) files.push(id);
		}
		#end

		return files;
	}

	static function needsCopy(id:String):Bool
	{
		#if sys
		final target = normalizeId(id);
		if (target == null) return false;

		try
		{
			if (!FileSystem.exists(target) || FileSystem.isDirectory(target)) return true;

			final size = FileSystem.stat(target).size;
			if (size == 0) return true;

			if (refresh.exists(target)) return true;

			final recorded = manifest.get(target);

			if (isAlwaysUpdated(target)) return recorded == null || recorded != size;

			if (recorded == null) manifest.set(target, size);
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

		var size = -1;

		#if android
		size = copyWithJava(id, target);
		#end

		if (size < 0) size = copyWithBytes(id, target);

		if (size < 0) return false;

		manifest.set(target, size);
		refresh.remove(target);
		dirty = true;

		final now = haxe.Timer.stamp();
		if (now - lastSave >= saveInterval) flush();

		return true;
		#else
		return false;
		#end
	}

	#if android
	static function copyWithJava(id:String, target:String):Int
	{
		if (!javaChecked)
		{
			javaChecked = true;

			try
			{
				javaCopy = lime.system.JNI.createStaticMethod('org/nightmarevision/StorageHelper', 'copyAsset', '(Ljava/lang/String;Ljava/lang/String;)I');
			}
			catch (e:Dynamic)
			{
				javaCopy = null;
			}
		}

		if (javaCopy == null) return -1;

		try
		{
			final assetPath = LimeAssets.getPath(id) ?? target;
			final result:Int = javaCopy(assetPath, Path.join([directory, target]));

			if (result >= 0 && FileSystem.exists(target) && FileSystem.stat(target).size == result) return result;
		}
		catch (e:Dynamic) {}

		return -1;
	}
	#end

	static function copyWithBytes(id:String, target:String):Int
	{
		#if sys
		final bytes = readAssetBytes(id);
		if (bytes == null) return -1;

		final temp = target + TEMP_SUFFIX;

		try
		{
			final folder = Path.directory(target);
			if (folder.length > 0 && !FileSystem.exists(folder)) FileSystem.createDirectory(folder);

			File.saveBytes(temp, bytes);

			if (FileSystem.stat(temp).size != bytes.length)
			{
				deleteQuietly(temp);
				return -1;
			}

			if (FileSystem.exists(target)) FileSystem.deleteFile(target);
			FileSystem.rename(temp, target);

			if (FileSystem.exists(target) && FileSystem.stat(target).size == bytes.length) return bytes.length;
		}
		catch (e:Dynamic)
		{
			deleteQuietly(temp);
		}
		#end

		return -1;
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

	public static function finishCopy(failed:Array<String>):Array<String>
	{
		#if sys
		if (!ready) return [];

		final stillFailed = [for (id in failed) if (!copyAsset(id)) id];

		try
		{
			flush();

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

	public static function flush():Void
	{
		#if sys
		if (!ready || !dirty) return;

		try
		{
			final files:Dynamic = {};
			for (key => size in manifest)
				Reflect.setField(files, key, size);

			final temp = MANIFEST_FILE + TEMP_SUFFIX;
			File.saveContent(temp, Json.stringify({version: manifestVersion, files: files, refresh: [for (key in refresh.keys()) key]}));
			if (FileSystem.exists(MANIFEST_FILE)) FileSystem.deleteFile(MANIFEST_FILE);
			FileSystem.rename(temp, MANIFEST_FILE);

			dirty = false;
			lastSave = haxe.Timer.stamp();
		}
		catch (e:Dynamic) {}
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
		refresh.clear();
		manifestVersion = '';

		#if sys
		try
		{
			if (FileSystem.exists(MANIFEST_FILE))
			{
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

				final pending:Null<Array<String>> = data.refresh;
				if (pending != null)
				{
					for (key in pending)
						refresh.set(key, true);
				}
			}
		}
		catch (e:Dynamic)
		{
			manifest.clear();
			refresh.clear();
			manifestVersion = '';
		}

		final version = getVersion();

		if (manifestVersion != version)
		{
			for (path => size in manifest)
			{
				if (isAlwaysUpdated(path) || isUnmodified(path, size)) refresh.set(path, true);
			}

			manifestVersion = version;
			dirty = true;
			flush();
		}
		#end
	}

	static function isUnmodified(path:String, size:Int):Bool
	{
		#if sys
		try
		{
			return FileSystem.exists(path) && FileSystem.stat(path).size == size;
		}
		catch (e:Dynamic) {}
		#end

		return false;
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
