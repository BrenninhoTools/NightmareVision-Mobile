package funkin.mobile;

import flixel.FlxG;
import flixel.sound.FlxSound;
import openfl.media.Sound;

class TrainHaptics
{
	public static inline final SOUND_KEY:String = 'train_passes';

	public static var arriveTime:Float = 4700;

	public static var approachTime:Float = 2400;

	public static var clackInterval:Float = 140;

	var sound:Null<Sound> = null;

	var lastClack:Float = -1000;

	public function new()
	{
		try
		{
			final key = Paths.findFileWithExts('sounds/' + SOUND_KEY, ['ogg', 'wav']);
			if (key != null && FunkinAssets.exists(key)) sound = FunkinAssets.getSound(key);
		}
		catch (e:Dynamic)
		{
			sound = null;
		}
	}

	public function update():Void
	{
		if (sound == null || !Haptics.enabled || Haptics.notesOnly) return;

		final playing = findPlaying();
		if (playing == null) return;

		final time = playing.time;
		final end = playing.length > 0 ? playing.length - 250 : arriveTime + 2500;

		if (time < approachTime || time > end) return;

		if (time < arriveTime)
		{
			final progress = (time - approachTime) / (arriveTime - approachTime);
			Haptics.rumble(0.15 + progress * 0.55, 80);
			return;
		}

		final fade = Math.min(1, Math.max(0.35, (end - time) / 700));
		Haptics.rumble(fade, 50);

		if (time - lastClack >= clackInterval || time < lastClack)
		{
			lastClack = time;
			Haptics.impact(fade);
		}
	}

	function findPlaying():Null<FlxSound>
	{
		for (entry in FlxG.sound.list)
		{
			if (entry == null || !entry.playing) continue;
			@:privateAccess if (entry._sound == sound) return entry;
		}

		return null;
	}
}
