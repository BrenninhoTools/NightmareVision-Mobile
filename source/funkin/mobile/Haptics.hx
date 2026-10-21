package funkin.mobile;

import flixel.FlxG;

enum HapticType
{
	LIGHT;
	MEDIUM;
	HEAVY;
}

class Haptics
{
	public static var noteInterval:Float = 45;

	public static var menuInterval:Float = 35;

	static var lastNote:Float = -1000;

	static var lastMenu:Float = -1000;

	public static var enabled(get, never):Bool;

	public static function play(type:HapticType, scale:Float = 1):Void
	{
		#if mobile
		if (!enabled) return;

		final duration = switch (type)
		{
			case LIGHT: 10;
			case MEDIUM: 22;
			case HEAVY: 45;
		}

		final base = switch (type)
		{
			case LIGHT: 0.45;
			case MEDIUM: 0.7;
			case HEAVY: 1.0;
		}

		NativeUtil.vibrate(duration, base * scale * ClientPrefs.hapticsIntensity);
		#end
	}

	public static function note():Void
	{
		if (!throttle(true)) return;
		play(MEDIUM);
	}

	public static function noteMiss():Void
	{
		if (!throttle(true)) return;
		play(HEAVY, 0.8);
	}

	public static function select():Void
	{
		if (!throttle(false)) return;
		play(LIGHT, 1.2);
	}

	public static function scroll():Void
	{
		if (!throttle(false)) return;
		play(LIGHT);
	}

	public static function button():Void
	{
		if (!throttle(false)) return;
		play(LIGHT, 1.4);
	}

	public static function preview(intensity:Float):Void
	{
		#if mobile
		if (!ClientPrefs.haptics) return;

		final now = FlxG.game != null ? FlxG.game.ticks : 0;
		if (now - lastMenu < 90) return;
		lastMenu = now;

		NativeUtil.vibrate(22, 0.7 * intensity);
		#end
	}

	static function throttle(note:Bool):Bool
	{
		if (!enabled) return false;

		final now = FlxG.game != null ? FlxG.game.ticks : 0;

		if (note)
		{
			if (now - lastNote < noteInterval) return false;
			lastNote = now;
		}
		else
		{
			if (now - lastMenu < menuInterval) return false;
			lastMenu = now;
		}

		return true;
	}

	static function get_enabled():Bool
	{
		#if mobile
		return ClientPrefs.haptics && ClientPrefs.hapticsIntensity > 0;
		#else
		return false;
		#end
	}
}
