package funkin.mobile;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;

class ScreenStyle
{
	public static final STYLES:Array<String> = ['Original', 'Full'];

	public static var maxRatio:Float = 2.4;

	public static var safeLeft(default, null):Float = 0;

	public static var safeRight(default, null):Float = 0;

	public static var safeTop(default, null):Float = 0;

	public static var safeBottom(default, null):Float = 0;

	static var initialized:Bool = false;

	public static var isFull(get, never):Bool;

	public static function init():Void
	{
		#if mobile
		if (initialized) return;
		initialized = true;

		FlxG.signals.postStateSwitch.add(onStateSwitch);
		FlxG.stage.addEventListener(openfl.events.Event.RESIZE, (_) -> refreshInsets());

		apply(false);
		#end
	}

	public static function apply(resetState:Bool = true):Void
	{
		#if mobile
		NativeUtil.setScreenStyle(isFull);

		@:privateAccess FlxG.game.onResize(null);
		refreshInsets();

		if (resetState && FlxG.state != null) FlxG.resetState();
		#end
	}

	public static function getGameWidth(windowWidth:Float, windowHeight:Float):Int
	{
		if (!isFull || windowWidth <= 0 || windowHeight <= 0) return FlxG.initialWidth;

		final baseRatio = FlxG.initialWidth / FlxG.initialHeight;
		final ratio = Math.min(maxRatio, windowWidth / windowHeight);
		if (ratio <= baseRatio + 0.01) return FlxG.initialWidth;

		var width = Math.round(FlxG.initialHeight * ratio);
		if (width % 2 != 0) width++;
		return width;
	}

	public static function refreshInsets():Void
	{
		safeLeft = safeRight = safeTop = safeBottom = 0;

		#if mobile
		if (!isFull || FlxG.stage == null || FlxG.stage.stageWidth <= 0) return;

		final insets = NativeUtil.getSafeInsets();
		final scale = FlxG.width / FlxG.stage.stageWidth;

		safeLeft = insets[0] * scale;
		safeTop = insets[1] * scale;
		safeRight = insets[2] * scale;
		safeBottom = insets[3] * scale;
		#end
	}

	public static function fitBackgrounds(group:FlxTypedGroup<FlxBasic>):Void
	{
		if (!isFull || FlxG.width <= FlxG.initialWidth || group == null) return;

		for (member in group.members)
		{
			if (member == null) continue;

			if (Std.isOfType(member, FlxSprite))
			{
				final sprite:FlxSprite = cast member;
				if (isBackground(sprite)) cover(sprite);
			}
		}
	}

	public static function cover(sprite:FlxSprite):Void
	{
		if (sprite == null || sprite.width <= 0) return;

		final factor = Math.max(FlxG.width / sprite.width, FlxG.height / sprite.height);
		if (factor <= 1) return;

		sprite.scale.set(sprite.scale.x * factor, sprite.scale.y * factor);
		sprite.updateHitbox();
		sprite.screenCenter();
	}

	static function isBackground(sprite:FlxSprite):Bool
	{
		if (sprite.graphic == null) return false;

		final initialWidth = FlxG.initialWidth;
		final initialHeight = FlxG.initialHeight;

		if (sprite.width < initialWidth * 0.95 || sprite.width >= FlxG.width) return false;
		if (sprite.height < initialHeight * 0.9) return false;
		if (sprite.x > initialWidth * 0.05 || sprite.x + sprite.width < initialWidth * 0.95) return false;

		return true;
	}

	static function onStateSwitch():Void
	{
		refreshInsets();
		if (FlxG.state != null) fitBackgrounds(cast FlxG.state);
	}

	static function get_isFull():Bool
	{
		#if mobile
		return ClientPrefs.screenStyle == 'Full';
		#else
		return false;
		#end
	}
}
