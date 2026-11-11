package funkin.mobile.haptics;

import flixel.FlxG;

import funkin.mobile.NativeUtil;

enum HapticType
{
	SELECTION;
	LIGHT;
	MEDIUM;
	HEAVY;
	DOUBLE;
	CONFIRM;
	RUMBLE;
}

class Haptics
{
	public static final SENSITIVITIES:Array<String> = ['Low', 'Medium', 'High'];

	public static final TYPES:Array<String> = ['All', 'Notes'];

	public static var notesOnly(get, never):Bool;

	static var lastConfirm:Float = -1000;

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
			case DOUBLE: 0.6;
			case CONFIRM: 1.0;
			case RUMBLE: 1.0;
		}

		NativeUtil.haptic(typeId(type), base * scale * ClientPrefs.hapticsIntensity);
		#end
	}

	public static function note(ratingMod:Float = 1):Void
	{
		if (!throttle(NOTE, noteInterval())) return;

		if (ratingMod < 0 || ratingMod >= 1) play(MEDIUM, 1.05);
		else if (ratingMod >= 0.75) play(MEDIUM, 0.8);
		else if (ratingMod >= 0.5) play(LIGHT, 0.75);
		else play(DOUBLE, 0.55);
	}

	public static var milestoneStep:Int = 100;

	public static function combo(value:Int):Void
	{
		if (milestoneStep <= 0 || value <= 0 || value % milestoneStep != 0) return;

		#if mobile
		if (!enabled) return;
		lastNote = FlxG.game != null ? FlxG.game.ticks : 0;
		NativeUtil.haptic(typeId(DOUBLE), ClientPrefs.hapticsIntensity * 1.3);
		#end
	}

	public static function noteMiss():Void
	{
		if (level < 1 || !throttle(NOTE, noteInterval())) return;
		play(HEAVY, 0.85);
	}

	static var sustainStart:Float = -1000;

	static var lastSustain:Float = -1000;

	public static function sustain():Void
	{
		#if mobile
		if (!enabled) return;

		final now = FlxG.game != null ? FlxG.game.ticks : 0;
		if (now - lastSustain < 45) return;
		if (now - lastSustain > 250) sustainStart = now;
		lastSustain = now;

		final held = now - sustainStart;
		final build = Math.min(1, 0.55 + held / 900);
		final tug = 0.82 + Math.sin(held * 0.022) * 0.18;

		NativeUtil.haptic(typeId(RUMBLE), build * tug * ClientPrefs.hapticsIntensity * 1.4);
		#end
	}

	static var lastAmbient:Float = -1000;

	public static function rumble(strength:Float, interval:Float = 60):Void
	{
		#if mobile
		if (!enabled || notesOnly || strength <= 0) return;

		final now = FlxG.game != null ? FlxG.game.ticks : 0;
		if (now - lastAmbient < interval) return;
		lastAmbient = now;

		NativeUtil.haptic(typeId(RUMBLE), strength * ClientPrefs.hapticsIntensity * 1.4);
		#end
	}

	public static function impact(strength:Float = 1):Void
	{
		#if mobile
		if (!enabled || notesOnly || strength <= 0) return;
		NativeUtil.haptic(typeId(HEAVY), strength * ClientPrefs.hapticsIntensity * 1.4);
		#end
	}

	public static function confirm():Void
	{
		#if mobile
		if (!enabled || notesOnly) return;

		final now = FlxG.game != null ? FlxG.game.ticks : 0;
		if (now - lastConfirm < 400) return;
		lastConfirm = now;
		lastMenu = now;

		NativeUtil.haptic(typeId(CONFIRM), Math.max(0.55, 1.6 * ClientPrefs.hapticsIntensity));
		#end
	}

	public static function denied():Void
	{
		if (notesOnly || !throttle(MENU, 120)) return;
		play(DOUBLE);
	}

	public static function select():Void
	{
		if (notesOnly || level < 1 || !throttle(MENU, 40)) return;
		play(LIGHT);
	}

	public static function scroll():Void
	{
		if (notesOnly || level < 2 || !throttle(SCROLL, 30)) return;
		play(SELECTION);
	}

	public static function button():Void
	{
		if (notesOnly || !throttle(MENU, 40)) return;
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
			case DOUBLE: 4;
			case CONFIRM: 5;
			case RUMBLE: 6;
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

	static function get_notesOnly():Bool
	{
		#if mobile
		return ClientPrefs.hapticsType == 'Notes';
		#else
		return false;
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
