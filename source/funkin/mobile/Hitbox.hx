package funkin.mobile;

import openfl.display.BitmapData;
import openfl.geom.Rectangle;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class Hitbox extends FlxTypedGroup<TouchButton>
{
	public static final COLORS:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];

	public static var pressedAlpha:Float = 0.6;

	public static var releaseDuration:Float = 0.15;

	public var enabled(default, set):Bool = true;

	final fades:Map<TouchButton, FlxTween> = [];

	public function new(actions:Array<String>)
	{
		super();

		final laneWidth = Math.floor(FlxG.width / actions.length);

		for (i => action in actions)
		{
			final width = i == actions.length - 1 ? FlxG.width - laneWidth * i : laneWidth;

			final lane = new TouchButton(laneWidth * i, 0, [action], 0);
			lane.blocksGestures = true;
			lane.loadGraphic(createLaneGraphic(width, FlxG.height, COLORS[i % COLORS.length]));
			lane.alpha = 0;

			lane.onDown.add(() -> {
				fades.get(lane)?.cancel();
				lane.alpha = ClientPrefs.invisibleHitbox ? 0 : pressedAlpha;
			});

			lane.onUp.add(() -> {
				fades.get(lane)?.cancel();
				fades.set(lane, FlxTween.tween(lane, {alpha: 0}, releaseDuration));
			});

			add(lane);
		}
	}

	public function setCamera(camera:FlxCamera):Hitbox
	{
		for (lane in members)
			lane.cameras = [camera];

		return this;
	}

	function set_enabled(value:Bool):Bool
	{
		for (lane in members)
		{
			lane.touchEnabled = value;

			if (!value)
			{
				fades.get(lane)?.cancel();
				lane.alpha = 0;
			}
		}

		return enabled = value;
	}

	static function createLaneGraphic(width:Int, height:Int, color:FlxColor):BitmapData
	{
		final bitmap = new BitmapData(width, height, true, FlxColor.TRANSPARENT);
		final half = width / 2;
		final border = 4;
		final rect = new Rectangle(0, 0, 1, height);

		for (column in 0...width)
		{
			final distance = Math.min(column, width - 1 - column);
			final ratio = 1 - Math.min(distance / half, 1);

			var fill:FlxColor = color;
			fill.alphaFloat = column < border || column >= width - border ? 1 : ratio * ratio * 0.75;

			rect.x = column;
			bitmap.fillRect(rect, fill);
		}

		return bitmap;
	}

	override function destroy():Void
	{
		for (tween in fades)
			tween?.cancel();
		fades.clear();

		super.destroy();
	}
}
