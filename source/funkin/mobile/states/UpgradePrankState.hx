package funkin.mobile.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

import funkin.mobile.haptics.Haptics;
import funkin.mobile.util.TouchUtil;

class UpgradePrankState extends MusicBeatState
{
	public static var closeDelay:Float = 0.45;

	public static var waitTime:Float = 1.2;

	final next:Class<FlxState>;

	var canLeave:Bool = false;

	var leaving:Bool = false;

	var hint:FlxText;

	public static function trigger(item:FlxSprite):Void
	{
		ClientPrefs.upgradePrankPending = true;
		ClientPrefs.flush();

		FlxG.sound.music?.stop();
		FlxG.sound.play(Paths.sound('confirmMenu'));
		Haptics.confirm();

		if (item != null && item.animation.exists('clicked')) item.animation.play('clicked', true);

		new flixel.util.FlxTimer().start(closeDelay, (_) -> closeGame());
	}

	static function closeGame():Void
	{
		#if sys
		Sys.exit(0);
		#else
		lime.system.System.exit(0);
		#end
	}

	public function new(next:Class<FlxState>)
	{
		super();
		this.next = next;
	}

	override function create():Void
	{
		super.create();

		ClientPrefs.upgradePrankPending = false;
		ClientPrefs.flush();

		final bg = new FlxSprite().makeScaledGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		final title = new FlxText(0, 0, FlxG.width, 'GOTCHA!', 72);
		title.setFormat(Paths.DEFAULT_FONT, 72, 0xFFFFD84D, CENTER, OUTLINE, FlxColor.BLACK);
		title.borderSize = 3;
		title.screenCenter(Y);
		title.y -= 150;
		add(title);

		final text = "There is no Upgrade.\nIt was just a prank, the game closed on purpose.\n\nNothing was bought, nothing was charged\nand none of your progress was lost.";
		final message = new FlxText(60, 0, FlxG.width - 120, text, 30);
		message.setFormat(Paths.DEFAULT_FONT, 30, FlxColor.WHITE, CENTER);
		message.screenCenter(Y);
		message.y += 20;
		add(message);

		hint = new FlxText(0, FlxG.height - 110, FlxG.width, #if mobile 'Tap to continue' #else 'Press ENTER to continue' #end, 28);
		hint.setFormat(Paths.DEFAULT_FONT, 28, 0xFFB9B3CC, CENTER);
		hint.alpha = 0;
		add(hint);

		title.scale.set(0.2, 0.2);
		FlxTween.tween(title.scale, {x: 1, y: 1}, 0.6, {ease: FlxEase.elasticOut});
		Haptics.impact(1, 0.5);

		new flixel.util.FlxTimer().start(waitTime, (_) -> {
			canLeave = true;
			FlxTween.tween(hint, {alpha: 1}, 0.4);
		});
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!canLeave || leaving) return;

		if (controls.ACCEPT || controls.BACK #if mobile || TouchUtil.tapped #end)
		{
			leaving = true;
			FlxG.sound.play(Paths.sound('confirmMenu'));
			Haptics.select();
			FlxG.switchState(() -> Type.createInstance(next, []));
		}
	}
}
