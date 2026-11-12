package funkin.mobile.ui;

import funkin.mobile.native.NativeUtil;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;

class ScreenStyle
{
	public static final STYLES:Array<String> = ['Original', 'Full', 'Stretch'];

	public static var maxRatio:Float = 2.4;

	public static var safeLeft(default, null):Float = 0;

	public static var safeRight(default, null):Float = 0;

	public static var safeTop(default, null):Float = 0;

	public static var safeBottom(default, null):Float = 0;

	static var initialized:Bool = false;

	static final covered:Array<FlxSprite> = [];

	public static var isFull(get, never):Bool;

	public static var contentOffset(get, never):Float;

	public static var isStretch(get, never):Bool;

	public static var usesWholeScreen(get, never):Bool;

	public static var ignoreSafeArea:Bool = false;

	public static var aspectRatio(get, never):Float;

	public static var hasCutout(get, never):Bool;

	public static final onChange:flixel.util.FlxSignal = new flixel.util.FlxSignal();

	static var pendingRefresh:Null<haxe.Timer> = null;

	public static function getSafeRect(?rect:flixel.math.FlxRect, margin:Float = 0):flixel.math.FlxRect
	{
		rect ??= flixel.math.FlxRect.get();
		return rect.set(safeLeft + margin, safeTop + margin, FlxG.width - safeLeft - safeRight - margin * 2, FlxG.height - safeTop - safeBottom - margin * 2);
	}

	public static function scheduleRefresh(delay:Int = 120):Void
	{
		pendingRefresh?.stop();
		pendingRefresh = haxe.Timer.delay(() -> {
			pendingRefresh = null;
			refreshLayout();
		}, delay);
	}

	public static function init():Void
	{
		#if mobile
		if (initialized) return;
		initialized = true;

		FlxG.signals.postStateSwitch.add(onStateSwitch);
		FlxG.signals.preStateSwitch.add(() -> covered.resize(0));
		FlxG.signals.postUpdate.add(keepCovered);
		FlxG.stage.addEventListener(openfl.events.Event.RESIZE, (_) -> {
			refreshLayout();
			scheduleRefresh(250);
		});
		FlxG.signals.gameResized.add((_, _) -> refreshLayout());
		FlxG.signals.focusGained.add(() -> scheduleRefresh(200));

		apply(false);
		#end
	}

	public static function apply(resetState:Bool = true):Void
	{
		#if mobile
		NativeUtil.setScreenStyle(usesWholeScreen);

		resize();
		if (resetState && FlxG.state != null) FlxG.resetState();

		for (delay in settleDelays)
		{
			haxe.Timer.delay(() -> {
				final width = FlxG.width;
				final height = FlxG.height;
				resize();
				if (resetState && (FlxG.width != width || FlxG.height != height) && FlxG.state != null) FlxG.resetState();
			}, delay);
		}
		#end
	}

	public static var settleDelays:Array<Int> = [120, 350, 800];

	public static function resize():Void
	{
		@:privateAccess FlxG.game.onResize(null);
		refreshLayout();
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
		if (!usesWholeScreen || ignoreSafeArea || FlxG.stage == null || FlxG.stage.stageWidth <= 0 || FlxG.stage.stageHeight <= 0) return;

		final insets = NativeUtil.getSafeInsets();
		final scaleX = FlxG.width / FlxG.stage.stageWidth;
		final scaleY = isStretch ? FlxG.height / FlxG.stage.stageHeight : scaleX;

		safeLeft = insets[0] * scaleX;
		safeTop = insets[1] * scaleY;
		safeRight = insets[2] * scaleX;
		safeBottom = insets[3] * scaleY;
		#end
	}

	public static function refreshLayout():Void
	{
		final before = [safeLeft, safeTop, safeRight, safeBottom];

		refreshInsets();
		funkin.backend.DebugDisplay.instance?.reposition();

		if (before[0] != safeLeft || before[1] != safeTop || before[2] != safeRight || before[3] != safeBottom) onChange.dispatch();
	}

	public static function fillsStretched(windowWidth:Float, windowHeight:Float):Bool
	{
		return isStretch && windowWidth > 0 && windowHeight > 0;
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
				if (isBackground(sprite))
				{
					cover(sprite);
					if (!covered.contains(sprite)) covered.push(sprite);
				}
			}
		}
	}

	public static function cover(sprite:FlxSprite):Void
	{
		if (sprite == null || sprite.width <= 0) return;

		final factor = Math.max(FlxG.width / sprite.width, FlxG.height / sprite.height);

		if (factor > 1)
		{
			sprite.scale.set(sprite.scale.x * factor, sprite.scale.y * factor);
			sprite.updateHitbox();
			sprite.screenCenter();
			return;
		}

		if (sprite.x > 0 || sprite.x + sprite.width < FlxG.width) sprite.screenCenter(X);
	}

	static function keepCovered():Void
	{
		if (covered.length == 0) return;

		if (!isFull || FlxG.width <= FlxG.initialWidth)
		{
			covered.resize(0);
			return;
		}

		var index = covered.length;
		while (index-- > 0)
		{
			final sprite = covered[index];
			if (sprite == null || !sprite.exists || sprite.graphic == null)
			{
				covered.splice(index, 1);
				continue;
			}

			if (sprite.width < FlxG.width - 1 || sprite.x > 0.5 || sprite.x + sprite.width < FlxG.width - 0.5) cover(sprite);
		}
	}

	static function isBackground(sprite:FlxSprite):Bool
	{
		if (sprite.graphic == null) return false;

		final initialWidth = FlxG.initialWidth;
		final initialHeight = FlxG.initialHeight;

		if (sprite.width < initialWidth * 0.95 || sprite.width >= FlxG.width) return false;
		if (sprite.height < initialHeight * 0.9) return false;

		final tolerance = initialWidth * 0.05;
		final leftAligned = sprite.x <= tolerance && sprite.x + sprite.width >= initialWidth - tolerance;
		final centered = Math.abs(sprite.x + sprite.width / 2 - FlxG.width / 2) <= tolerance;

		return leftAligned || centered;
	}

	static function onStateSwitch():Void
	{
		refreshLayout();
		if (FlxG.state != null) fitBackgrounds(cast FlxG.state);
	}

	static function get_contentOffset():Float
	{
		#if mobile
		return Math.max(0, (FlxG.width - FlxG.initialWidth) / 2);
		#else
		return 0;
		#end
	}

	static function get_isStretch():Bool
	{
		#if mobile
		return ClientPrefs.screenStyle == 'Stretch';
		#else
		return false;
		#end
	}

	static function get_usesWholeScreen():Bool
	{
		return isFull || isStretch;
	}

	static function get_aspectRatio():Float
	{
		final stage = FlxG.stage;
		return stage != null && stage.stageHeight > 0 ? stage.stageWidth / stage.stageHeight : FlxG.width / FlxG.height;
	}

	static function get_hasCutout():Bool
	{
		return safeLeft > 0 || safeRight > 0 || safeTop > 0 || safeBottom > 0;
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
