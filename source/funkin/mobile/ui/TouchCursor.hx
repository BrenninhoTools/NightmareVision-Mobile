package funkin.mobile.ui;

import funkin.mobile.input.ExternalInput;

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
	var color:Int;
	var start:Float;
	var trail:Array<Float>;
}

typedef CursorRipple =
{
	var x:Float;
	var y:Float;
	var color:Int;
	var life:Float;
}

class TouchCursor extends Sprite
{
	public static var instance(default, null):Null<TouchCursor> = null;

	public static var color:Int = 0xFF2B2B;

	public static var palette:Array<Int> = [0xFF2B2B, 0x2BB8FF, 0x4CFF6A, 0xFFD02B, 0xC24BFF];

	public static var multiColor:Bool = true;

	public static var radius:Float = 13;

	public static var fadeSpeed:Float = 4;

	public static var trailLength:Int = 6;

	public static var trails:Bool = true;

	public static var ripples:Bool = true;

	public static var rippleTime:Float = 0.35;

	public static var tapTime:Float = 0.25;

	public static var hidden:Bool = false;

	final canvas:Shape;

	final points:Map<Int, CursorPoint> = [];

	final rippleList:Array<CursorRipple> = [];

	var lastTime:Float = 0;

	var drawn:Bool = false;

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

	function nextColor():Int
	{
		if (!multiColor || palette == null || palette.length == 0) return color;

		final used = [for (point in points) if (point.pressed) point.color];
		for (entry in palette)
			if (!used.contains(entry)) return entry;

		return palette[Lambda.count(points) % palette.length];
	}

	function onBegin(event:TouchEvent):Void
	{
		points.set(event.touchPointID, {
			x: event.stageX,
			y: event.stageY,
			alpha: 1,
			pressed: true,
			pulse: 0,
			color: nextColor(),
			start: haxe.Timer.stamp(),
			trail: [event.stageX, event.stageY]
		});
	}

	function onMove(event:TouchEvent):Void
	{
		final point = points.get(event.touchPointID);
		if (point == null) return;

		point.x = event.stageX;
		point.y = event.stageY;

		if (!trails) return;

		point.trail.push(point.x);
		point.trail.push(point.y);
		while (point.trail.length > trailLength * 2)
			point.trail.splice(0, 2);
	}

	function onEnd(event:TouchEvent):Void
	{
		final point = points.get(event.touchPointID);
		if (point == null) return;

		point.x = event.stageX;
		point.y = event.stageY;
		point.pressed = false;

		if (ripples && haxe.Timer.stamp() - point.start <= tapTime) rippleList.push({x: point.x, y: point.y, color: point.color, life: 1});
	}

	function onFrame(_:Event):Void
	{
		final now = haxe.Timer.stamp();
		final elapsed = Math.min(0.1, now - lastTime);
		lastTime = now;

		final enabled = ClientPrefs.touchCursor && !ExternalInput.active;
		visible = enabled && !hidden;

		if (!enabled)
		{
			points.clear();
			rippleList.resize(0);
			if (drawn) canvas.graphics.clear();
			drawn = false;
			return;
		}

		if (!points.iterator().hasNext() && rippleList.length == 0)
		{
			if (drawn) canvas.graphics.clear();
			drawn = false;
			return;
		}

		final graphics = canvas.graphics;
		graphics.clear();
		drawn = true;

		final scale = stage != null ? Math.max(1, Math.min(stage.stageWidth / FlxG.width, stage.stageHeight / FlxG.height)) : 1;

		var index = rippleList.length;
		while (index-- > 0)
		{
			final ripple = rippleList[index];
			ripple.life -= elapsed / rippleTime;
			if (ripple.life <= 0)
			{
				rippleList.splice(index, 1);
				continue;
			}

			final size = radius * scale * (1 + (1 - ripple.life) * 1.4);
			graphics.lineStyle(1.8 * scale, ripple.color, 0.8 * ripple.life);
			graphics.drawCircle(ripple.x, ripple.y, size);
			graphics.lineStyle();
		}

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

			if (trails && point.trail.length >= 4)
			{
				final segments = Std.int(point.trail.length / 2);
				for (segment in 1...segments)
				{
					final strength = segment / segments;
					graphics.lineStyle(radius * scale * 0.35 * strength, point.color, 0.35 * strength * point.alpha);
					graphics.moveTo(point.trail[(segment - 1) * 2], point.trail[(segment - 1) * 2 + 1]);
					graphics.lineTo(point.trail[segment * 2], point.trail[segment * 2 + 1]);
				}
				graphics.lineStyle();

				if (point.pressed && point.trail.length > 2)
				{
					point.trail.splice(0, 2);
				}
			}

			final size = radius * scale * (point.pressed ? 1 : 1 + (1 - point.alpha) * 0.5);
			final ring = size * (0.6 + 0.4 * point.pulse);

			graphics.beginFill(point.color, 0.35 * point.alpha);
			graphics.drawCircle(point.x, point.y, size);
			graphics.endFill();

			graphics.lineStyle(2 * scale, point.color, 0.95 * point.alpha);
			graphics.drawCircle(point.x, point.y, ring);
			graphics.lineStyle();

			graphics.beginFill(point.color, 0.9 * point.alpha);
			graphics.drawCircle(point.x, point.y, size * 0.22);
			graphics.endFill();
		}
	}
}
