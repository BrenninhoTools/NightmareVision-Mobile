package funkin.utils;

import haxe.io.Bytes as HaxeBytes;

import lime.ui.FileDialog;
import lime.utils.Bytes;

import openfl.utils.ByteArray;
import openfl.net.FileFilter;
import openfl.filesystem.File;

typedef BrowseOptions =
{
	var ?typeFilter:Array<FileFilter>;
	var ?title:String;
	var ?defaultSearch:String;
}

/**
 * Utility class to make browsing and saving files a little bit more convenient
 */
@:nullSafety
class FileUtil
{
	#if mobile
	public static inline final EXPORT_FOLDER:String = 'exports';
	
	static function filterExtensions(?filters:Array<FileFilter>):Array<String>
	{
		final extensions:Array<String> = [];
		if (filters == null) return extensions;
		
		for (filter in filters)
		{
			if (filter == null || filter.extension == null) continue;
			
			for (part in filter.extension.split(';'))
			{
				final clean = part.trim().replace('*.', '').replace('.', '');
				if (clean.length > 0 && clean != '*' && !extensions.contains(clean)) extensions.push(clean);
			}
		}
		
		return extensions;
	}
	
	static function saveToExports(data:Dynamic, fileName:String):Null<String>
	{
		final name = fileName.withoutDirectory();
		final path = haxe.io.Path.join([EXPORT_FOLDER, name.length > 0 ? name : 'file']);
		
		if (!saveFileToPath(data, path)) return null;
		
		#if sys
		return sys.FileSystem.absolutePath(path);
		#else
		return path;
		#end
	}
	#end
	
	public static function browseForFile(options:BrowseOptions, ?onSelect:String->Void, ?onCancel:Void->Void)
	{
		#if mobile
		final started = funkin.mobile.NativeUtil.pickFiles(filterExtensions(options.typeFilter), false, (files) -> {
			if (onSelect != null) onSelect(files[0]);
		}, onCancel);
		
		if (!started && onCancel != null) onCancel();
		return;
		#end
		
final title = options.title;
		final filters = options.typeFilter;
		final startPath = options.defaultSearch;
		
		FileDialog.openFile(FlxG.stage.window, title, (files, filter) -> {
			if (files != null && files.length > 0)
			{
				if (onSelect != null) onSelect(files[0]);
			}
			else
			{
				if (onCancel != null) onCancel();
			}
		}, @:privateAccess @:nullSafety(Off) File.__getFilterTypes(filters), startPath);
	}
	
	public static function browseForMultipleFiles(options:BrowseOptions, ?onSelect:Array<String>->Void, ?onCancel:Void->Void)
	{
		#if mobile
		final started = funkin.mobile.NativeUtil.pickFiles(filterExtensions(options.typeFilter), true, (files) -> {
			if (onSelect != null) onSelect(files);
		}, onCancel);
		
		if (!started && onCancel != null) onCancel();
		return;
		#end
		
final title = options.title;
		final filters = options.typeFilter;
		final startPath = options.defaultSearch;
		
		FileDialog.openFile(FlxG.stage.window, title, (files, filter) -> {
			if (files != null && files.length > 0)
			{
				if (onSelect != null) onSelect(files);
			}
			else
			{
				if (onCancel != null) onCancel();
			}
		}, @:privateAccess @:nullSafety(Off) File.__getFilterTypes(filters), startPath, true);
	}
	
	public static function saveFile(data:Dynamic, ?fileName:String, ?onSelect:String->Void, ?onCancel:Void->Void)
	{
		if (data == null) return;
		
		#if mobile
		final name = (fileName ?? 'file').withoutDirectory();
		final safeName = name.length > 0 ? name : 'file';
		final staging = haxe.io.Path.join([funkin.mobile.StorageUtil.getPath('.cache'), safeName]);
		
		if (saveFileToPath(data, staging))
		{
			final started = funkin.mobile.NativeUtil.saveFile(staging, safeName, (savedName) -> {
				final shown = savedName.length > 0 ? savedName : safeName;
				funkin.mobile.NativeUtil.toast('Saved ' + shown, false);
				if (onSelect != null) onSelect(shown);
			}, () -> {
				if (onCancel != null) onCancel();
			}, () -> saveFallback(data, safeName, onSelect, onCancel));
			
			if (started) return;
		}
		
		saveFallback(data, safeName, onSelect, onCancel);
		#else
		var filters = null;
		if (fileName != null && fileName.extension().length > 0)
		{
			final ext:String = fileName.extension();
			filters = [new lime.ui.FileDialogFilter('*.$ext', ext)];
		}
		
		FileDialog.saveFile(FlxG.stage.window, 'Save', (file, filter) -> {
			if (file != null && file.length > 0)
			{
				Bytes.toFile(file, dynamicToBytes(data));
				
				if (onSelect != null) onSelect(file);
			}
			else
			{
				if (onCancel != null) onCancel();
			}
		}, filters, fileName);
		#end
	}
	
	#if mobile
	static function saveFallback(data:Dynamic, fileName:String, ?onSelect:String->Void, ?onCancel:Void->Void):Void
	{
		final saved = saveToExports(data, fileName);
		
		if (saved != null)
		{
			funkin.mobile.NativeUtil.toast('Saved to ' + EXPORT_FOLDER + '/' + saved.withoutDirectory(), true);
			if (onSelect != null) onSelect(saved);
		}
		else
		{
			funkin.mobile.NativeUtil.toast('Could not save ' + fileName, true);
			if (onCancel != null) onCancel();
		}
	}
	#end
	
	public static function saveFileToPath(data:Dynamic, path:String, ensureDirectory:Bool = true):Bool
	{
		try
		{
			if (ensureDirectory && path.directory() != '' && !FunkinAssets.isDirectory(path.directory()))
			{
				FileSystem.createDirectory(path.directory());
			}
			
			Bytes.toFile(path, dynamicToBytes(data));
			return true;
		}
		catch (e)
		{
			Logger.log('Failed to save to $path\nException: $e', ERROR);
			return false;
		}
	}
	
	static function dynamicToBytes(input:Dynamic):Bytes
	{
		if (input is ByteArrayData || input is HaxeBytes) return input;
		
		final bytes = new ByteArray();
		bytes.writeUTFBytes(Std.string(input));
		
		return bytes;
	}
}
