package funkin.mobile;

import flixel.FlxG;
import flixel.math.FlxPoint;
#if FLX_TOUCH
import flixel.input.touch.FlxTouch;
#end

enum SwipeDirection
{
	NONE;
	UP;
	DOWN;
	LEFT;
	RIGHT;
}

typedef TouchGesture =
{
	var id:Int;
	var startX:Float;
	var startY:Float;
	var anchorX:Float;
	var anchorY:Float;
	var lastX:Float;
	var lastY:Float;
	var startTime:Float;
	var lastMoveTime:Float;
	var lastPulseTime:Float;
	var velocityX:Float;
	var velocityY:Float;
	var direction:SwipeDirection;
	var steps:Int;
	var blocked:Bool;
	var primary:Bool;
}

class TouchInput
{
	public static final PRESS_SUFFIX:String = '-press';
	public static final RELEASE_SUFFIX:String = '-release';

	public static final SINGLE_ACTIONS:Array<String> = [
		'accept',
		'back',
		'pause',
		'reset',
		'fullscreen',
		'switch_debug_display',
		'soft_reload',
		'hard_reload'
	];

	public static var enabled:Bool = #if mobile true #else false #end;

	public static var gesturesEnabled:Bool = true;

	public static var naturalScrolling:Bool = true;

	public static var swipeDistance:Float = 95;

	public static var tapDistance:Float = 28;

	public static var tapTime:Float = 300;

	public static var holdRepeat:Bool = true;

	public static var holdDelay:Float = 520;

	public static var holdInterval:Float = 150;

	public static var flickEnabled:Bool = true;

	public static var flickSpeed:Float = 2.6;

	public static var maxFlickSteps:Int = 2;

	public static var flickInterval:Int = 5;

	public static var twoFingerBack:Bool = true;

	public static var androidBackKey:Bool = true;

	public static var justTapped(default, null):Bool = false;
	
	public static var justDoubleTapped(default, null):Bool = false;
	
	public static var justLongPressed(default, null):Bool = false;
	
	public static var dragging(default, null):Bool = false;
	
	public static var dragX(default, null):Float = 0;
	
	public static var dragY(default, null):Float = 0;
	
	public static var holdTime(default, null):Float = 0;
	
	public static var touchCount(default, null):Int = 0;
	
	public static var longPressTime:Float = 550;
	
	public static var doubleTapTime:Float = 320;
	
	public static final touchPosition:FlxPoint = FlxPoint.get();
	
	static var lastTapTime:Float = -1;
	
	static var longPressFired:Bool = false;

	public static var lastSwipe(default, null):SwipeDirection = NONE;

	public static final tapPosition:FlxPoint = FlxPoint.get();

	static final zones:Array<TouchButton> = [];

	static final gestures:Map<Int, TouchGesture> = [];

	static final seenTouches:Map<Int, Bool> = [];

	static var backKeyDown:Bool = false;

	static final pulses:Array<String> = [];

	static final queued:Array<{action:String, frame:Int}> = [];

	static var current:Map<String, Bool> = [];

	static var previous:Map<String, Bool> = [];

	static var frame:Int = 0;

	static var polledFrame:Int = -1;

	static var initialized:Bool = false;

	static var primaryId:Int = -1;

	static var maxFingers:Int = 0;

	static var multiStartTime:Float = 0;

	public static function init():Void
	{
		if (initialized) return;
		initialized = true;

		FlxG.signals.preUpdate.add(onPreUpdate);
		FlxG.signals.postUpdate.add(poll);
		FlxG.signals.preStateSwitch.add(reset);

		#if android
		final window = lime.app.Application.current?.window;
		if (window != null)
		{
			window.onKeyDown.add(onKeyDown);
			window.onKeyUp.add(onKeyUp);
		}
		#end
	}

	public static function register(zone:TouchButton):Void
	{
		if (!zones.contains(zone)) zones.push(zone);
	}

	public static function unregister(zone:TouchButton):Void
	{
		zones.remove(zone);
	}

	public static function check(name:String):Bool
	{
		if (!enabled) return false;

		poll();

		if (name.endsWith(PRESS_SUFFIX)) return justPressed(name.substr(0, name.length - PRESS_SUFFIX.length));

		if (name.endsWith(RELEASE_SUFFIX)) return justReleased(name.substr(0, name.length - RELEASE_SUFFIX.length));

		if (SINGLE_ACTIONS.contains(name)) return justPressed(name);

		return pressed(name);
	}

	public static inline function pressed(action:String):Bool
	{
		return current.exists(action);
	}

	public static inline function justPressed(action:String):Bool
	{
		return current.exists(action) && !previous.exists(action);
	}

	public static inline function justReleased(action:String):Bool
	{
		return !current.exists(action) && previous.exists(action);
	}

	public static function pulse(action:String, delayFrames:Int = 0):Void
	{
		if (delayFrames > 0)
		{
			queued.push({action: action, frame: frame + delayFrames});
			return;
		}

		if (!pulses.contains(action)) pulses.push(action);
	}

	public static function gesturesActive():Bool
	{
		if (!gesturesEnabled) return false;

		for (zone in zones)
		{
			if (zone.blocksGestures && zone.isTouchable()) return false;
		}

		return true;
	}

	public static function releaseAll():Void
	{
		for (zone in zones)
		{
			zone.beginPoll();
			zone.endPoll();
		}

		current.clear();
		previous.clear();
		reset();
	}

	public static function reset():Void
	{
		dragging = false;
		holdTime = 0;
		longPressFired = false;
		lastTapTime = -1;
		gestures.clear();
		pulses.resize(0);
		queued.resize(0);
		primaryId = -1;
		maxFingers = 0;
		justTapped = false;
		lastSwipe = NONE;
	}

	public static function poll():Void
	{
		if (!enabled || polledFrame == frame) return;
		polledFrame = frame;

		final swap = previous;
		previous = current;
		current = swap;
		current.clear();

		justTapped = false;
		justDoubleTapped = false;
		justLongPressed = false;
		lastSwipe = NONE;
		dragX = dragY = 0;
		
		var i = queued.length;
		while (i-- > 0)
		{
			if (queued[i].frame <= frame)
			{
				pulse(queued[i].action);
				queued.splice(i, 1);
			}
		}

		for (zone in zones)
			zone.beginPoll();

		#if FLX_TOUCH
		final allowGestures = gesturesActive();

		var activeFingers = 0;
		for (touch in FlxG.touches.list)
			if (touch.pressed) activeFingers++;
		
		touchCount = activeFingers;

		updateMultiTouch(activeFingers, allowGestures);

		for (touch in FlxG.touches.list)
		{
			final quick = touch.justReleased && !seenTouches.exists(touch.touchPointID);
			final zone = touch.pressed || quick ? findZone(touch) : null;
			if (zone != null) zone.capture();

			handleGesture(touch, zone, allowGestures, quick);
		}
		#end

		for (zone in zones)
		{
			zone.endPoll();

			if (zone.touchPressed)
			{
				for (action in zone.actions)
					current.set(action, true);
			}
		}

		for (action in pulses)
			current.set(action, true);
		pulses.resize(0);
	}

	static function updateMultiTouch(activeFingers:Int, allowGestures:Bool):Void
	{
		final now = FlxG.game.ticks;

		if (activeFingers >= 2 && maxFingers < 2) multiStartTime = now;
		if (activeFingers > maxFingers) maxFingers = activeFingers;

		if (activeFingers == 0)
		{
			if (maxFingers == 2 && twoFingerBack && allowGestures && now - multiStartTime <= tapTime * 1.5) pulse('back');
			maxFingers = 0;
		}
	}

	#if FLX_TOUCH
	static function findZone(touch:FlxTouch):Null<TouchButton>
	{
		var found:Null<TouchButton> = null;

		var i = zones.length;
		while (i-- > 0)
		{
			final zone = zones[i];
			if (!zone.isTouchable() || !zone.containsTouch(touch)) continue;

			if (found == null || zone.priority > found.priority) found = zone;
		}

		return found;
	}

	static function handleGesture(touch:FlxTouch, zone:Null<TouchButton>, allowGestures:Bool, quick:Bool):Void
	{
		final id = touch.touchPointID;
		final now = FlxG.game.ticks;

		if (touch.justPressed || quick)
		{
			final primary = primaryId == -1;
			if (primary)
			{
				primaryId = id;
				touchPosition.set(touch.gameX, touch.gameY);
			}

			gestures.set(id,
				{
					id: id,
					startX: touch.gameX,
					startY: touch.gameY,
					anchorX: touch.gameX,
					anchorY: touch.gameY,
					lastX: touch.gameX,
					lastY: touch.gameY,
					startTime: now,
					lastMoveTime: now,
					lastPulseTime: now,
					velocityX: 0,
					velocityY: 0,
					direction: NONE,
					steps: 0,
					blocked: zone != null,
					primary: primary
				});

			if (!quick)
			{
				seenTouches.set(id, true);
				return;
			}
		}

		final gesture = gestures.get(id);
		if (gesture == null) return;

		if (gesture.primary)
		{
			dragX = touch.gameX - gesture.lastX;
			dragY = touch.gameY - gesture.lastY;
			touchPosition.set(touch.gameX, touch.gameY);
			holdTime = now - gesture.startTime;
			
			final moved = Math.abs(touch.gameX - gesture.startX) + Math.abs(touch.gameY - gesture.startY);
			if (moved > tapDistance) dragging = true;
			
			if (!longPressFired && !dragging && !gesture.blocked && touch.pressed && holdTime >= longPressTime)
			{
				longPressFired = true;
				justLongPressed = true;
			}
		}
		
		trackVelocity(gesture, touch.gameX, touch.gameY, now);
		
		if (touch.justReleased)
		{
			gestures.remove(id);
			seenTouches.remove(id);
			
			if (id == primaryId)
			{
				primaryId = -1;
				dragging = false;
				holdTime = 0;
				
				if (longPressFired)
				{
					longPressFired = false;
					return;
				}
			}

			if (!allowGestures || gesture.blocked || !gesture.primary || maxFingers > 1) return;

			if (gesture.direction != NONE)
			{
				flick(gesture);
				return;
			}

			final distance = Math.sqrt(Math.pow(touch.gameX - gesture.startX, 2) + Math.pow(touch.gameY - gesture.startY, 2));

			if (distance <= tapDistance && now - gesture.startTime <= tapTime)
			{
				justTapped = true;
				
				if (lastTapTime >= 0 && now - lastTapTime <= doubleTapTime && Math.abs(touch.gameX - tapPosition.x) + Math.abs(touch.gameY - tapPosition.y) <= tapDistance * 2)
				{
					justDoubleTapped = true;
					lastTapTime = -1;
				}
				else
				{
					lastTapTime = now;
				}
				
				tapPosition.set(touch.gameX, touch.gameY);
				pulse('accept');
				Haptics.select();
			}

			return;
		}

		if (!allowGestures || gesture.blocked || !gesture.primary || maxFingers > 1) return;

		final deltaX = touch.gameX - gesture.anchorX;
		final deltaY = touch.gameY - gesture.anchorY;

		var direction:SwipeDirection = NONE;

		if (Math.abs(deltaY) >= swipeDistance && Math.abs(deltaY) >= Math.abs(deltaX))
		{
			direction = resolveDirection(0, deltaY);
		}
		else if (Math.abs(deltaX) >= swipeDistance)
		{
			direction = resolveDirection(deltaX, 0);
		}

		if (direction != NONE)
		{
			emitSwipe(gesture, direction, now);
			gesture.anchorX = touch.gameX;
			gesture.anchorY = touch.gameY;
			return;
		}

		if (holdRepeat && gesture.direction != NONE && now - gesture.lastMoveTime >= holdDelay && now - gesture.lastPulseTime >= holdInterval)
		{
			emitSwipe(gesture, gesture.direction, now);
		}
	}

	static function trackVelocity(gesture:TouchGesture, x:Float, y:Float, now:Float):Void
	{
		final elapsed = Math.max(1, now - gesture.lastMoveTime);
		final movedX = x - gesture.lastX;
		final movedY = y - gesture.lastY;

		if (Math.abs(movedX) + Math.abs(movedY) > 2)
		{
			gesture.velocityX = gesture.velocityX * 0.4 + (movedX / elapsed) * 0.6;
			gesture.velocityY = gesture.velocityY * 0.4 + (movedY / elapsed) * 0.6;
			gesture.lastMoveTime = now;
		}

		gesture.lastX = x;
		gesture.lastY = y;
	}

	static function emitSwipe(gesture:TouchGesture, direction:SwipeDirection, now:Float):Void
	{
		gesture.direction = direction;
		gesture.lastPulseTime = now;
		gesture.steps++;
		lastSwipe = direction;
		pulse(actionFor(direction));
		Haptics.scroll();
	}

	static function flick(gesture:TouchGesture):Void
	{
		if (!flickEnabled || FlxG.game.ticks - gesture.lastMoveTime > 80) return;

		final speed = switch (gesture.direction)
		{
			case UP | DOWN: Math.abs(gesture.velocityY);
			case LEFT | RIGHT: Math.abs(gesture.velocityX);
			default: 0;
		}

		if (speed < flickSpeed) return;

		final extra = Std.int(Math.min(maxFlickSteps, Math.floor(speed / flickSpeed)));
		final action = actionFor(gesture.direction);

		for (step in 1...extra + 1)
			pulse(action, step * flickInterval);
	}

	static function resolveDirection(deltaX:Float, deltaY:Float):SwipeDirection
	{
		final sign:Float = naturalScrolling ? -1 : 1;

		if (deltaY != 0) return deltaY * sign > 0 ? DOWN : UP;
		if (deltaX != 0) return deltaX > 0 ? RIGHT : LEFT;
		return NONE;
	}
	#end

	static function actionFor(direction:SwipeDirection):String
	{
		return switch (direction)
		{
			case UP: 'ui_up';
			case DOWN: 'ui_down';
			case LEFT: 'ui_left';
			case RIGHT: 'ui_right';
			default: '';
		}
	}

	#if android
	static function onKeyDown(key:lime.ui.KeyCode, modifier:lime.ui.KeyModifier):Void
	{
		if (!androidBackKey || key != lime.ui.KeyCode.APP_CONTROL_BACK) return;

		if (backKeyDown) return;
		backKeyDown = true;

		pulse('back');
		pulse('pause');
	}

	static function onKeyUp(key:lime.ui.KeyCode, modifier:lime.ui.KeyModifier):Void
	{
		if (!androidBackKey || key != lime.ui.KeyCode.APP_CONTROL_BACK) return;

		backKeyDown = false;
		lime.app.Application.current?.window?.onKeyUp.cancel();
	}
	#end

	static function onPreUpdate():Void
	{
		frame++;
	}
}
