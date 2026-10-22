package funkin.mobile;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxState;
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
	
	public static var doubleTapped(get, never):Bool;
	
	public static var longPressed(get, never):Bool;
	
	public static var dragging(get, never):Bool;
	
	public static var dragX(get, never):Float;
	
	public static var dragY(get, never):Float;
	
	public static var holdTime(get, never):Float;
	
	public static var count(get, never):Int;

	public static var pinching(get, never):Bool;

	public static var pinchDelta(get, never):Float;

	public static var pinchScale(get, never):Float;

	public static function overlapsPadded(object:FlxBasic, padding:Float, ?camera:FlxCamera):Bool
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
			if (touch.pressed && pointOverlaps(touch.gameX, touch.gameY, object, camera, padding)) return true;
		#end

		return false;
	}

	public static function pressedCount(object:FlxBasic, ?camera:FlxCamera):Int
	{
		var total = 0;

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
			if (touch.pressed && pointOverlaps(touch.gameX, touch.gameY, object, camera)) total++;
		#end

		return total;
	}

	public static function tappedOnAny(objects:Array<FlxBasic>, ?camera:FlxCamera):Int
	{
		TouchInput.poll();
		if (!TouchInput.justTapped || objects == null) return -1;

		for (index => object in objects)
			if (object != null && object.exists && pointOverlaps(TouchInput.tapPosition.x, TouchInput.tapPosition.y, object, camera)) return index;

		return -1;
	}

	public static function justPressedOnAny(objects:Array<FlxBasic>, ?camera:FlxCamera):Int
	{
		if (objects == null) return -1;

		for (index => object in objects)
			if (object != null && object.exists && justPressedOn(object, camera)) return index;

		return -1;
	}

	public static function pressedOnAny(objects:Array<FlxBasic>, ?camera:FlxCamera):Int
	{
		if (objects == null) return -1;

		for (index => object in objects)
			if (object != null && object.exists && overlaps(object, camera)) return index;

		return -1;
	}

	public static function swipedOn(object:FlxBasic, ?direction:SwipeDirection, ?camera:FlxCamera):Bool
	{
		TouchInput.poll();
		if (TouchInput.lastSwipe == NONE) return false;
		if (direction != null && direction != NONE && TouchInput.lastSwipe != direction) return false;

		return pointOverlaps(TouchInput.touchPosition.x, TouchInput.touchPosition.y, object, camera);
	}

	public static function getWorldPosition(?camera:FlxCamera, ?point:flixel.math.FlxPoint):flixel.math.FlxPoint
	{
		TouchInput.poll();
		point ??= flixel.math.FlxPoint.get();

		final cam = camera ?? FlxG.camera;
		point.set((TouchInput.touchPosition.x - cam.x) / cam.zoom + cam.viewMarginX + cam.scroll.x, (TouchInput.touchPosition.y - cam.y) / cam.zoom + cam.viewMarginY + cam.scroll.y);

		return point;
	}

	#if FLX_TOUCH
	public static function getTouchById(id:Int):Null<FlxTouch>
	{
		for (touch in FlxG.touches.list)
			if (touch.touchPointID == id) return touch;

		return null;
	}
	#end
	
	public static function holding(object:FlxBasic, minTime:Float = 0, ?camera:FlxCamera):Bool
	{
		TouchInput.poll();
		return TouchInput.holdTime >= minTime && overlaps(object, camera);
	}
	
	public static function longPressedOn(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		TouchInput.poll();
		return TouchInput.justLongPressed && pointOverlaps(TouchInput.touchPosition.x, TouchInput.touchPosition.y, object, camera);
	}
	
	public static function doubleTappedOn(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		TouchInput.poll();
		return TouchInput.justDoubleTapped && pointOverlaps(TouchInput.tapPosition.x, TouchInput.tapPosition.y, object, camera);
	}
	
	public static function pointOverlaps(gameX:Float, gameY:Float, object:FlxBasic, ?camera:FlxCamera, padding:Float = 0):Bool
	{
		if (object == null || !Std.isOfType(object, FlxObject)) return false;
		
		final target:FlxObject = cast object;
		if (!target.exists || !target.visible) return false;
		
		final cam = camera ?? getCamera(object);
		
		var x = (gameX - cam.x) / cam.zoom + cam.viewMarginX;
		var y = (gameY - cam.y) / cam.zoom + cam.viewMarginY;
		
		if (cam.angle != 0)
		{
			final radians = -cam.angle * Math.PI / 180;
			final centerX = cam.viewMarginX + cam.width / cam.zoom / 2;
			final centerY = cam.viewMarginY + cam.height / cam.zoom / 2;
			final dx = x - centerX;
			final dy = y - centerY;
			x = centerX + dx * Math.cos(radians) - dy * Math.sin(radians);
			y = centerY + dx * Math.sin(radians) + dy * Math.cos(radians);
		}
		
		x += cam.scroll.x * target.scrollFactor.x;
		y += cam.scroll.y * target.scrollFactor.y;
		
		return x >= target.x - padding && x < target.x + target.width + padding && y >= target.y - padding && y < target.y + target.height + padding;
	}

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
		TouchInput.poll();
		return TouchInput.justTapped && pointOverlaps(TouchInput.tapPosition.x, TouchInput.tapPosition.y, object, camera);
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

	public static inline final NO_TAP:Int = -1;

	public static inline final MISSED_TAP:Int = -2;

	public static var rowPadding:Float = 14;

	public static function getActiveState():Null<FlxState>
	{
		var state:Null<FlxState> = FlxG.state;
		while (state != null && state.subState != null)
			state = state.subState;
		return state;
	}

	public static function getOwnerState(object:FlxBasic):Null<FlxState>
	{
		var current:Null<FlxBasic> = object.container;
		while (current != null)
		{
			if (Std.isOfType(current, FlxState)) return cast current;
			current = current.container;
		}
		return null;
	}

	public static function getCamera(object:FlxBasic):FlxCamera
	{
		@:privateAccess
		{
			if (object._cameras != null && object._cameras.length > 0) return object._cameras[0];

			var current:Null<FlxBasic> = object.container;
			while (current != null)
			{
				if (current._cameras != null && current._cameras.length > 0) return current._cameras[0];
				current = current.container;
			}

			final active = getActiveState();
			if (active != null && active._cameras != null && active._cameras.length > 0) return active._cameras[0];
		}

		@:privateAccess final defaults = FlxCamera._defaultCameras;
		return defaults != null && defaults.length > 0 ? defaults[0] : FlxG.camera;
	}

	public static function getMenuTap(items:Array<Dynamic>, ?camera:FlxCamera):Int
	{
		TouchInput.poll();
		if (!TouchInput.justTapped || items == null) return NO_TAP;

		var best = MISSED_TAP;
		var bestDistance = Math.POSITIVE_INFINITY;

		for (index => entry in items)
		{
			if (entry == null || !Std.isOfType(entry, FlxObject)) continue;

			final item:FlxObject = cast entry;
			if (!item.exists || !item.visible) continue;

			final cam = camera ?? getCamera(item);
			final y = (TouchInput.tapPosition.y - cam.y) / cam.zoom + cam.viewMarginY + cam.scroll.y * item.scrollFactor.y;

			final top = item.y - rowPadding;
			final bottom = item.y + item.height + rowPadding;
			if (y < top || y > bottom) continue;

			final distance = Math.abs(y - (item.y + item.height / 2));
			if (distance < bestDistance)
			{
				bestDistance = distance;
				best = index;
			}
		}

		return best;
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
	
	static function get_doubleTapped():Bool
	{
		TouchInput.poll();
		return TouchInput.justDoubleTapped;
	}
	
	static function get_longPressed():Bool
	{
		TouchInput.poll();
		return TouchInput.justLongPressed;
	}
	
	static function get_dragging():Bool
	{
		TouchInput.poll();
		return TouchInput.dragging;
	}
	
	static function get_dragX():Float
	{
		TouchInput.poll();
		return TouchInput.dragX;
	}
	
	static function get_dragY():Float
	{
		TouchInput.poll();
		return TouchInput.dragY;
	}
	
	static function get_holdTime():Float
	{
		TouchInput.poll();
		return TouchInput.holdTime;
	}
	
	static function get_pinching():Bool
	{
		TouchInput.poll();
		return TouchInput.pinching;
	}

	static function get_pinchDelta():Float
	{
		TouchInput.poll();
		return TouchInput.pinchDelta;
	}

	static function get_pinchScale():Float
	{
		TouchInput.poll();
		final previous = TouchInput.pinchDistance - TouchInput.pinchDelta;
		return TouchInput.pinching && previous > 0 ? TouchInput.pinchDistance / previous : 1;
	}

	static function get_count():Int
	{
		TouchInput.poll();
		return TouchInput.touchCount;
	}
}
