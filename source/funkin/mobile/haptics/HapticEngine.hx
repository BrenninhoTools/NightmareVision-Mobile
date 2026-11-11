package funkin.mobile.haptics;

import funkin.mobile.haptics.Haptics.HapticType;
import funkin.mobile.native.NativeUtil;

#if extension_haptics
import extension.haptics.Haptic;
#end

class HapticEngine
{
	public static var coreHaptics(default, null):Bool = false;

	public static var patterns(default, null):Bool = false;

	public static var useCoreHaptics:Bool = true;

	static var initialized:Bool = false;

	public static function init():Void
	{
		if (initialized) return;
		initialized = true;

		#if extension_haptics
		try
		{
			#if ios
			if (NativeUtil.supportsCoreHaptics())
			{
				Haptic.initialize();
				coreHaptics = true;
				patterns = true;
			}
			#elseif android
			Haptic.initialize();
			patterns = true;
			#end
		}
		catch (e:Dynamic)
		{
			coreHaptics = false;
			patterns = false;
		}
		#end
	}

	public static function fire(type:HapticType, intensity:Float, sharpness:Float = -1):Void
	{
		#if mobile
		if (intensity <= 0) return;

		if (coreHaptics && useCoreHaptics && fireCore(type, intensity, sharpness)) return;

		NativeUtil.haptic(typeId(type), intensity);
		#end
	}

	public static function pattern(durations:Array<Float>, amplitudes:Array<Float>, ?sharpnesses:Array<Float>):Bool
	{
		#if extension_haptics
		if (!patterns || durations == null || amplitudes == null || durations.length == 0) return false;

		final count = Std.int(Math.min(durations.length, amplitudes.length));
		final timings = [for (i in 0...count) Math.max(0.01, durations[i])];
		final levels = [for (i in 0...count) Math.max(0, Math.min(1, amplitudes[i]))];
		final sharp = [for (i in 0...count) sharpnesses != null && i < sharpnesses.length ? Math.max(0, Math.min(1, sharpnesses[i])) : 0.5];

		try
		{
			Haptic.vibratePattern(timings, levels, sharp);
			return true;
		}
		catch (e:Dynamic) {}
		#end

		return false;
	}

	static function fireCore(type:HapticType, intensity:Float, sharpness:Float):Bool
	{
		#if extension_haptics
		final amplitude = Math.min(1, intensity);
		final boost = Math.min(3, Math.max(1, intensity));

		try
		{
			switch (type)
			{
				case SELECTION:
					Haptic.vibrateOneShot(0.02, amplitude * 0.7, pick(sharpness, 0.9));
				case LIGHT:
					Haptic.vibrateOneShot(0.03, amplitude * 0.8, pick(sharpness, 0.7));
				case MEDIUM:
					Haptic.vibrateOneShot(0.04, amplitude, pick(sharpness, 0.55));
				case HEAVY:
					Haptic.vibrateOneShot(0.06, amplitude, pick(sharpness, 0.3));
				case DOUBLE:
					final sharp = pick(sharpness, 0.5);
					Haptic.vibratePattern([0.03, 0.06 * boost, 0.03], [amplitude, 0, amplitude * 0.85], [sharp, 0, sharp]);
				case CONFIRM:
					Haptic.vibratePattern([0.07 * boost, 0.045, 0.15 * boost, 0.03, 0.06 * boost], [amplitude, 0, amplitude, 0, amplitude * 0.6], [0.6, 0, 0.35, 0, 0.25]);
				case RUMBLE:
					Haptic.vibrateOneShot(0.12 * boost, amplitude, pick(sharpness, 0.2));
			}
			return true;
		}
		catch (e:Dynamic) {}
		#end

		return false;
	}

	static inline function pick(value:Float, fallback:Float):Float
	{
		return value >= 0 ? value : fallback;
	}

	public static function typeId(type:HapticType):Int
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
}
