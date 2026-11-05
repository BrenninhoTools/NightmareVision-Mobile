package funkin.mobile;

import flixel.FlxG;

enum HapticType
{
	SELECTION;
	LIGHT;
	MEDIUM;
	HEAVY;
}

class Haptics
{
	public static final SENSITIVITIES:Array<String> = ['Low', 'Medium', 'High'];

	static var lastNote:Float = -1000;

	static var lastMenu:Float = -1000;

	static var lastScroll:Float = -1000;

	public static var enabled(get, never):Bool;

	public static var level(get, never):Int;

	public static function play(type:HapticType, scale:Float = 1):Void
	{
		#if mobile
		if (!enabled) return;

		final base = switch (type)
		{
			case SELECTION: 0.35;
			case LIGHT: 0.5;
			case MEDIUM: 0.75;
			case HEAVY: 1.0;
		}

		NativeUtil.haptic(typeId(type), base * scale * ClientPrefs.hapticsIntensity);
		#end
	}

	public static function note():Void
	{
		if (!throttle(NOTE, noteInterval())) return;
		play(MEDIUM);
	}

	public static function noteMiss():Void
	{
		if (level < 1 || !throttle(NOTE, noteInterval())) return;
		play(HEAVY, 0.85);
	}

	public static function select():Void
	{
		if (level < 1 || !throttle(MENU, 40)) return;
		play(LIGHT);
	}

	public static function scroll():Void
	{
		if (level < 2 || !throttle(SCROLL, 30)) return;
		play(SELECTION);
	}

	public static function button():Void
	{
		if (!throttle(MENU, 40)) return;
		play(LIGHT, 1.2);
	}

	public static function preview(intensity:Float):Void
	{
		#if mobile
		if (!ClientPrefs.haptics) return;

		final now = FlxG.game != null ? FlxG.game.ticks : 0;
		if (now - lastMenu < 90) return;
		lastMenu = now;

		NativeUtil.haptic(typeId(MEDIUM), 0.75 * intensity);
		#end
	}

	static function noteInterval():Float
	{
		return switch (level)
		{
			case 0: 90;
			case 2: 25;
			default: 45;
		}
	}

	static function throttle(channel:HapticChannel, interval:Float):Bool
	{
		if (!enabled) return false;

		final now = FlxG.game != null ? FlxG.game.ticks : 0;

		switch (channel)
		{
			case NOTE:
				if (now - lastNote < interval) return false;
				lastNote = now;
			case MENU:
				if (now - lastMenu < interval) return false;
				lastMenu = now;
			case SCROLL:
				if (now - lastScroll < interval) return false;
				lastScroll = now;
		}

		return true;
	}

	static inline function typeId(type:HapticType):Int
	{
		return switch (type)
		{
			case SELECTION: 0;
			case LIGHT: 1;
			case MEDIUM: 2;
			case HEAVY: 3;
		}
	}

	static function get_level():Int
	{
		#if mobile
		final index = SENSITIVITIES.indexOf(ClientPrefs.hapticsSensitivity);
		return index < 0 ? 1 : index;
		#else
		return 1;
		#end
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

private enum HapticChannel
{
	NOTE;
	MENU;
	SCROLL;
}
