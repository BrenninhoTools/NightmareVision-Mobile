package funkin.mobile;

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.TouchEvent;

import flixel.FlxG;

typedef CursorPoint =
{
	var x:Float;
	var y:Float;
	var alpha:Float;
	var pressed:Bool;
	var pulse:Float;
}

class TouchCursor extends Sprite
{
	public static var instance(default, null):Null<TouchCursor> = null;

	public static var color:Int = 0xFF2B2B;

	public static var radius:Float = 26;

	public static var fadeSpeed:Float = 4;

	final canvas:Shape;

	final points:Map<Int, CursorPoint> = [];

	var lastTime:Float = 0;

	public static function init():Void
	{
		#if mobile
		if (instance != null || FlxG.game?.parent == null) return;

		instance = new TouchCursor();
		FlxG.game.parent.addChild(instance);
		#end
	}

	public static function bringToFront():Void
	{
		final cursor = instance;
		if (cursor == null || cursor.parent == null) return;
		cursor.parent.setChildIndex(cursor, cursor.parent.numChildren - 1);
	}

	public function new()
	{
		super();

		mouseEnabled = mouseChildren = false;

		canvas = new Shape();
		addChild(canvas);

		addEventListener(Event.ADDED_TO_STAGE, onAdded);
	}

	function onAdded(_:Event):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAdded);

		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onBegin, false, 20000);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onMove, false, 20000);
		stage.addEventListener(TouchEvent.TOUCH_END, onEnd, false, 20000);
		addEventListener(Event.ENTER_FRAME, onFrame);

		lastTime = haxe.Timer.stamp();
	}

	function onBegin(event:TouchEvent):Void
	{
		points.set(event.touchPointID, {x: event.stageX, y: event.stageY, alpha: 1, pressed: true, pulse: 0});
	}

	function onMove(event:TouchEvent):Void
	{
		final point = points.get(event.touchPointID);
		if (point == null) return;

		point.x = event.stageX;
		point.y = event.stageY;
	}

	function onEnd(event:TouchEvent):Void
	{
		final point = points.get(event.touchPointID);
		if (point == null) return;

		point.x = event.stageX;
		point.y = event.stageY;
		point.pressed = false;
	}

	function onFrame(_:Event):Void
	{
		final now = haxe.Timer.stamp();
		final elapsed = Math.min(0.1, now - lastTime);
		lastTime = now;

		final graphics = canvas.graphics;
		graphics.clear();

		final enabled = ClientPrefs.touchCursor && !ExternalInput.active;
		visible = enabled;

		if (!enabled)
		{
			points.clear();
			return;
		}

		final scale = stage != null ? Math.max(1, Math.min(stage.stageWidth / FlxG.width, stage.stageHeight / FlxG.height)) : 1;

		for (id => point in points)
		{
			if (!point.pressed)
			{
				point.alpha -= elapsed * fadeSpeed;
				if (point.alpha <= 0)
				{
					points.remove(id);
					continue;
				}
			}

			point.pulse = Math.min(1, point.pulse + elapsed * 6);

			final size = radius * scale * (point.pressed ? 1 : 1 + (1 - point.alpha) * 0.5);
			final ring = size * (0.6 + 0.4 * point.pulse);

			graphics.beginFill(color, 0.35 * point.alpha);
			graphics.drawCircle(point.x, point.y, size);
			graphics.endFill();

			graphics.lineStyle(3 * scale, color, 0.95 * point.alpha);
			graphics.drawCircle(point.x, point.y, ring);
			graphics.lineStyle();

			graphics.beginFill(color, 0.9 * point.alpha);
			graphics.drawCircle(point.x, point.y, size * 0.22);
			graphics.endFill();
		}
	}
}
