package funkin.mobile.haptics;

import flixel.FlxG;
import flixel.sound.FlxSound;
import openfl.media.Sound;

enum StageEffect
{
	TRAIN;
	CAR;
	THUNDER;
}

typedef TrackedSound =
{
	var sound:Sound;
	var effect:StageEffect;
}

class StageHaptics
{
	public static final SOUNDS:Array<{key:String, effect:StageEffect}> = [
		{key: 'train_passes', effect: TRAIN},
		{key: 'carPass0', effect: CAR},
		{key: 'carPass1', effect: CAR},
		{key: 'thunder_1', effect: THUNDER},
		{key: 'thunder_2', effect: THUNDER}
	];

	public static var trainArrive:Float = 4700;

	public static var trainApproach:Float = 2400;

	public static var trainClack:Float = 140;

	public static var thunderDecay:Float = 450;

	final tracked:Array<TrackedSound> = [];

	final lastTimes:Map<FlxSound, Float> = [];

	final fired:Map<FlxSound, Bool> = [];

	var lastClack:Float = -1000;

	public function new()
	{
		for (entry in SOUNDS)
		{
			final sound = resolve(entry.key);
			if (sound != null) tracked.push({sound: sound, effect: entry.effect});
		}
	}

	static function resolve(key:String):Null<Sound>
	{
		try
		{
			final path = Paths.findFileWithExts('sounds/' + key, ['ogg', 'wav']);
			if (path != null && FunkinAssets.exists(path)) return FunkinAssets.getSound(path);
		}
		catch (e:Dynamic) {}

		return null;
	}

	public function update():Void
	{
		if (tracked.length == 0 || !Haptics.enabled || Haptics.notesOnly) return;

		for (entry in FlxG.sound.list)
		{
			if (entry == null || !entry.playing) continue;

			final effect = effectFor(entry);
			if (effect == null) continue;

			final time = entry.time;
			final previous = lastTimes.get(entry) ?? -1;
			if (previous < 0 || time < previous) fired.remove(entry);
			lastTimes.set(entry, time);

			switch (effect)
			{
				case TRAIN:
					train(entry, time);
				case CAR:
					car(entry, time);
				case THUNDER:
					thunder(entry, time);
			}
		}
	}

	function effectFor(entry:FlxSound):Null<StageEffect>
	{
		@:privateAccess final sound = entry._sound;
		if (sound == null) return null;

		for (item in tracked)
			if (item.sound == sound) return item.effect;

		return null;
	}

	function train(entry:FlxSound, time:Float):Void
	{
		final end = entry.length > 0 ? entry.length - 250 : trainArrive + 2500;
		if (time < trainApproach || time > end) return;

		if (time < trainArrive)
		{
			final progress = (time - trainApproach) / (trainArrive - trainApproach);
			Haptics.rumble(0.15 + progress * 0.55, 80);
			return;
		}

		final fade = Math.min(1, Math.max(0.35, (end - time) / 700));
		Haptics.rumble(fade, 50);

		if (time - lastClack >= trainClack || time < lastClack)
		{
			lastClack = time;
			Haptics.impact(fade);
		}
	}

	function car(entry:FlxSound, time:Float):Void
	{
		final length = entry.length > 0 ? entry.length : 1500;
		final progress = time / length;
		if (progress >= 0.95) return;

		final envelope = Math.pow(Math.sin(Math.PI * Math.min(1, progress / 0.9)), 1.5);
		Haptics.rumble(0.2 + envelope * 0.9, 45);

		if (!fired.exists(entry) && progress >= 0.4)
		{
			fired.set(entry, true);
			Haptics.impact(1.1);
		}
	}

	function thunder(entry:FlxSound, time:Float):Void
	{
		if (!fired.exists(entry))
		{
			fired.set(entry, true);
			Haptics.impact(1.4);
			return;
		}

		final strength = Math.exp(-time / thunderDecay);
		if (strength < 0.12) return;

		Haptics.rumble(strength * 1.1, 55);
	}
}
