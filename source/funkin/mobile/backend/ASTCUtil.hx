package funkin.mobile.backend;

import openfl.display.BitmapData;
import openfl.utils.ByteArray;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ASTCUtil
{
	public static inline final EXTENSION:String = 'astc';

	public static final MAGIC:Array<Int> = [0x13, 0xAB, 0xA1, 0x5C];

	public static var enabled(get, never):Bool;

	public static var supported(get, never):Bool;

	public static var loaded(default, null):Int = 0;

	static var supportChecked:Bool = false;

	static var supportValue:Bool = false;

	static final failed:Map<String, Bool> = [];

	public static function pathFor(path:String):Null<String>
	{
		if (path == null || path.length == 0) return null;

		final extension = haxe.io.Path.extension(path).toLowerCase();
		if (extension == EXTENSION) return path;
		if (extension != 'png') return null;

		return haxe.io.Path.withExtension(path, EXTENSION);
	}

	public static function exists(path:String):Bool
	{
		final compressed = pathFor(path);
		if (compressed == null) return false;

		#if sys
		if (FileSystem.exists(compressed)) return true;
		#end

		return openfl.utils.Assets.exists(compressed, BINARY);
	}

	public static function load(path:String):Null<BitmapData>
	{
		if (!enabled) return null;

		final compressed = pathFor(path);
		if (compressed == null || failed.exists(compressed)) return null;

		final bytes = readBytes(compressed);
		if (bytes == null) return null;

		if (!isValid(bytes))
		{
			failed.set(compressed, true);
			return null;
		}

		try
		{
			final context = FlxG.stage.context3D;
			final texture = context.createASTCTexture(ByteArray.fromBytes(bytes));
			final bitmap = BitmapData.fromTexture(texture);
			if (bitmap != null) loaded++;
			return bitmap;
		}
		catch (e:Dynamic)
		{
			failed.set(compressed, true);
			return null;
		}
	}

	public static function isValid(bytes:haxe.io.Bytes):Bool
	{
		if (bytes == null || bytes.length <= 16) return false;

		for (index in 0...MAGIC.length)
			if (bytes.get(index) != MAGIC[index]) return false;

		return true;
	}

	static function readBytes(path:String):Null<haxe.io.Bytes>
	{
		try
		{
			#if sys
			if (FileSystem.exists(path)) return File.getBytes(path);
			#end

			if (openfl.utils.Assets.exists(path, BINARY)) return openfl.utils.Assets.getBytes(path);
		}
		catch (e:Dynamic) {}

		return null;
	}

	static function get_supported():Bool
	{
		if (supportChecked) return supportValue;

		final context = FlxG.stage != null ? FlxG.stage.context3D : null;
		if (context == null) return false;

		supportChecked = true;

		try
		{
			supportValue = context.isASTCSupported();
		}
		catch (e:Dynamic)
		{
			supportValue = false;
		}

		return supportValue;
	}

	static function get_enabled():Bool
	{
		#if mobile
		return ClientPrefs.astcTextures && supported;
		#else
		return false;
		#end
	}
}
