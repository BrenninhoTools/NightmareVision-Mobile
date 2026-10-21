package funkin.mobile;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
#if FLX_TOUCH
import flixel.input.touch.FlxTouch;
#end

import funkin.mobile.TouchInput.SwipeDirection;

class TouchUtil
{
	public static var pressed(get, never):Bool;

	public static var justPressed(get, never):Bool;

	public static var justReleased(get, never):Bool;

	public static var tapped(get, never):Bool;

	public static var swipe(get, never):SwipeDirection;

	public static function overlaps(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (touch.pressed && touchOverlaps(touch, object, camera)) return true;
		}
		#end

		return false;
	}

	public static function justPressedOn(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.justStarted())
		{
			if (touchOverlaps(touch, object, camera)) return true;
		}
		#end

		return false;
	}

	public static function justReleasedOn(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.justReleased())
		{
			if (touchOverlaps(touch, object, camera)) return true;
		}
		#end

		return false;
	}

	public static function tappedOn(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		if (!TouchInput.justTapped || object == null) return false;

		final cam = camera ?? getCamera(object);
		if (cam == null || !Std.isOfType(object, FlxObject)) return false;

		final target:FlxObject = cast object;
		final x = (TouchInput.tapPosition.x - cam.x) / cam.zoom + cam.viewMarginX + cam.scroll.x * target.scrollFactor.x;
		final y = (TouchInput.tapPosition.y - cam.y) / cam.zoom + cam.viewMarginY + cam.scroll.y * target.scrollFactor.y;

		return x >= target.x && x < target.x + target.width && y >= target.y && y < target.y + target.height;
	}

	#if FLX_TOUCH
	public static function getFirst():Null<FlxTouch>
	{
		for (touch in FlxG.touches.list)
		{
			if (touch.pressed || touch.justReleased) return touch;
		}

		return null;
	}

	static function touchOverlaps(touch:FlxTouch, object:FlxBasic, ?camera:FlxCamera):Bool
	{
		if (object == null) return false;
		return touch.overlaps(object, camera ?? getCamera(object));
	}
	#end

	static function getCamera(object:FlxBasic):Null<FlxCamera>
	{
		final cameras = object.getCameras();
		return cameras != null && cameras.length > 0 ? cameras[0] : FlxG.camera;
	}

	static function get_pressed():Bool
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
			if (touch.pressed) return true;
		#end

		return false;
	}

	static function get_justPressed():Bool
	{
		#if FLX_TOUCH
		return FlxG.touches.justStarted().length > 0;
		#else
		return false;
		#end
	}

	static function get_justReleased():Bool
	{
		#if FLX_TOUCH
		return FlxG.touches.justReleased().length > 0;
		#else
		return false;
		#end
	}

	static function get_tapped():Bool
	{
		TouchInput.poll();
		return TouchInput.justTapped;
	}

	static function get_swipe():SwipeDirection
	{
		TouchInput.poll();
		return TouchInput.lastSwipe;
	}
}
