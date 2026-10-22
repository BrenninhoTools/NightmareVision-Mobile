package funkin.mobile;

import flixel.FlxG;

#if ios
@:cppFileCode('
extern "C" void nmv_native_vibrate(int milliseconds);
extern "C" void nmv_native_vibrate_intensity(int milliseconds, double intensity);
extern "C" void nmv_native_toast(const char *message, int longDuration);
extern "C" void nmv_native_pick_files(const char *extensions, int multiple);
extern "C" const char *nmv_native_pick_state();
extern "C" const char *nmv_native_picked_files();
extern "C" void nmv_native_reset_pick();
extern "C" void nmv_native_share_file(const char *path);
extern "C" void nmv_native_exclude_from_backup(const char *path);
extern "C" void nmv_native_save_file(const char *sourcePath, const char *fileName);
extern "C" const char *nmv_native_save_state();
extern "C" const char *nmv_native_saved_name();
extern "C" void nmv_native_reset_save();
extern "C" long long nmv_native_free_space();
extern "C" int nmv_native_external_input();
')
#end
@:build(funkin.mobile.NativeMacro.build())
class NativeUtil
{
	public static var hapticsEnabled:Bool = true;
	
	#if android
	static inline final ANDROID_CLASS:String = 'org/nightmarevision/NativeHelper';
	
	static final cache:Map<String, Dynamic> = [];
	
	static function jni(name:String, signature:String):Null<Dynamic>
	{
		final key = name + signature;
		if (cache.exists(key)) return cache.get(key);
		
		var func:Null<Dynamic> = null;
		
		try
		{
			func = lime.system.JNI.createStaticMethod(ANDROID_CLASS, name, signature);
		}
		catch (e:Dynamic) {}
		
		cache.set(key, func);
		return func;
	}
	#end
	
	static var pickCallback:Null<Array<String>->Void> = null;
	
	static var pickCancel:Null<Void->Void> = null;
	
	static var polling:Bool = false;
	
	public static function vibrate(milliseconds:Int = 12, intensity:Float = 1):Void
	{
		if (!hapticsEnabled || milliseconds <= 0 || intensity <= 0) return;
		
		final clamped = Math.min(1, intensity);
		
		#if android
		final func = jni('vibrateWith', '(II)V');
		if (func != null) func(milliseconds, Std.int(Math.max(1, Math.round(clamped * 255))));
		#elseif ios
		untyped __cpp__('nmv_native_vibrate_intensity({0}, {1})', milliseconds, clamped);
		#end
	}
	
	public static function toast(message:String, longDuration:Bool = false):Void
	{
		#if android
		final func = jni('toast', '(Ljava/lang/String;Z)V');
		if (func != null) func(message, longDuration);
		#elseif ios
		untyped __cpp__('nmv_native_toast({0}.utf8_str(), {1} ? 1 : 0)', message, longDuration);
		#end
	}
	
	public static function showKeyboard():Void
	{
		final window = lime.app.Application.current?.window;
		if (window != null) window.textInputEnabled = true;
		
		#if android
		final func = jni('showKeyboard', '()V');
		if (func != null) func();
		#end
	}
	
	public static function hideKeyboard():Void
	{
		final window = lime.app.Application.current?.window;
		if (window != null) window.textInputEnabled = false;
		
		#if android
		final func = jni('hideKeyboard', '()V');
		if (func != null) func();
		#end
	}
	
	public static function excludeFromBackup(path:String):Void
	{
		#if ios
		untyped __cpp__('nmv_native_exclude_from_backup({0}.utf8_str())', path);
		#end
	}
	
	public static function getExternalInput():Int
	{
		#if android
		final func = jni('getExternalInput', '()I');
		return func != null ? func() : 0;
		#elseif ios
		return untyped __cpp__('nmv_native_external_input()');
		#else
		return 0;
		#end
	}
	
	public static function getFreeSpaceMB():Int
	{
		#if ios
		final bytes:Float = untyped __cpp__('(double)nmv_native_free_space()');
		return bytes < 0 ? -1 : Std.int(bytes / 1048576);
		#else
		return -1;
		#end
	}
	
	public static function shareFile(path:String):Void
	{
		#if ios
		untyped __cpp__('nmv_native_share_file({0}.utf8_str())', path);
		#end
	}
	
	public static function pickFiles(extensions:Array<String>, multiple:Bool, onSelect:Array<String>->Void, ?onCancel:Void->Void):Bool
	{
		#if (android || ios)
		pickCallback = onSelect;
		pickCancel = onCancel;
		
		#if android
		final func = jni('pickFiles', '(Ljava/lang/String;Z)V');
		if (func == null) return false;
		func(toMimeTypes(extensions).join(','), multiple);
		#else
		untyped __cpp__('nmv_native_pick_files({0}.utf8_str(), {1} ? 1 : 0)', extensions.join(','), multiple);
		#end
		
		if (!polling)
		{
			polling = true;
			FlxG.signals.postUpdate.add(pollPick);
		}
		
		return true;
		#else
		return false;
		#end
	}
	
	static var saveCallback:Null<String->Void> = null;
	
	static var saveCancel:Null<Void->Void> = null;
	
	static var saveError:Null<Void->Void> = null;
	
	static var savePolling:Bool = false;
	
	public static function saveFile(sourcePath:String, fileName:String, onSave:String->Void, ?onCancel:Void->Void, ?onError:Void->Void):Bool
	{
		#if (android || ios)
		saveCallback = onSave;
		saveCancel = onCancel;
		saveError = onError;
		
		#if android
		final func = jni('saveFile', '(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V');
		if (func == null) return false;
		final mimes = toMimeTypes([haxe.io.Path.extension(fileName)]);
		func(sourcePath, fileName, mimes.length > 0 ? mimes[0] : 'application/octet-stream');
		#else
		untyped __cpp__('nmv_native_save_file({0}.utf8_str(), {1}.utf8_str())', sourcePath, fileName);
		#end
		
		if (!savePolling)
		{
			savePolling = true;
			FlxG.signals.postUpdate.add(pollSave);
		}
		
		return true;
		#else
		return false;
		#end
	}
	
	static function pollSave():Void
	{
		#if android
		final stateFunc = jni('getSaveState', '()Ljava/lang/String;');
		final state:String = (stateFunc != null ? stateFunc() : null) ?? 'error';
		#elseif ios
		final state:String = untyped __cpp__('::String::create(nmv_native_save_state())');
		#else
		final state = 'error';
		#end
		
		if (state == 'pending' || state == 'idle') return;
		
		FlxG.signals.postUpdate.remove(pollSave);
		savePolling = false;
		
		#if android
		final nameFunc = jni('getSavedName', '()Ljava/lang/String;');
		final name:String = (nameFunc != null ? nameFunc() : null) ?? '';
		final resetFunc = jni('resetSave', '()V');
		if (resetFunc != null) resetFunc();
		#elseif ios
		final name:String = untyped __cpp__('::String::create(nmv_native_saved_name())');
		untyped __cpp__('nmv_native_reset_save()');
		#else
		final name = '';
		#end
		
		final done = saveCallback;
		final cancel = saveCancel;
		final error = saveError;
		saveCallback = null;
		saveCancel = null;
		saveError = null;
		
		switch (state)
		{
			case 'done':
				if (done != null) done(name);
			case 'cancel':
				if (cancel != null) cancel();
			default:
				if (error != null) error();
				else if (cancel != null) cancel();
		}
	}
	
	static function pollPick():Void
	{
		final state = getPickState();
		if (state == 'pending' || state == 'idle') return;
		
		FlxG.signals.postUpdate.remove(pollPick);
		polling = false;
		
		final files = state == 'done' ? getPickedFiles() : [];
		resetPick();
		
		final select = pickCallback;
		final cancel = pickCancel;
		pickCallback = null;
		pickCancel = null;
		
		if (files.length > 0)
		{
			if (select != null) select(files);
		}
		else if (cancel != null)
		{
			cancel();
		}
	}
	
	static function getPickState():String
	{
		#if android
		final func = jni('getPickState', '()Ljava/lang/String;');
		final state:Null<String> = func != null ? func() : null;
		return state ?? 'cancel';
		#elseif ios
		final state:String = untyped __cpp__('::String::create(nmv_native_pick_state())');
		return state;
		#else
		return 'cancel';
		#end
	}
	
	static function getPickedFiles():Array<String>
	{
		#if android
		final func = jni('getPickedFiles', '()Ljava/lang/String;');
		final files:Null<String> = func != null ? func() : null;
		#elseif ios
		final files:String = untyped __cpp__('::String::create(nmv_native_picked_files())');
		#else
		final files:Null<String> = null;
		#end
		
		if (files == null || files.length == 0) return [];
		return [for (file in files.split('\n')) if (file.length > 0) file];
	}
	
	static function resetPick():Void
	{
		#if android
		final func = jni('resetPick', '()V');
		if (func != null) func();
		#elseif ios
		untyped __cpp__('nmv_native_reset_pick()');
		#end
	}
	
	static function toMimeTypes(extensions:Array<String>):Array<String>
	{
		final types:Array<String> = [];
		
		for (extension in extensions)
		{
			final mime = switch (extension.toLowerCase())
			{
				case 'json': 'application/json';
				case 'xml': 'text/xml';
				case 'txt': 'text/plain';
				case 'png': 'image/png';
				case 'ogg': 'audio/ogg';
				case 'mp3': 'audio/mpeg';
				case 'zip': 'application/zip';
				default: null;
			}
			
			if (mime != null && !types.contains(mime)) types.push(mime);
		}
		
		if (types.length > 0 && !types.contains('application/octet-stream')) types.push('application/octet-stream');
		
		return types;
	}
}
