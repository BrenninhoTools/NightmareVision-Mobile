package funkin.mobile;

import flixel.FlxG;
#if FLX_TOUCH
import flixel.input.touch.FlxTouch;
#end

typedef TouchGesture =
{
	var startX:Float;
	var startY:Float;
	var anchorX:Float;
	var anchorY:Float;
	var startTime:Float;
	var swiped:Bool;
	var blocked:Bool;
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

	public static var swipeDistance:Float = 70;

	public static var tapDistance:Float = 30;

	public static var tapTime:Float = 350;

	static final zones:Array<TouchButton> = [];

	static final gestures:Map<Int, TouchGesture> = [];

	static final pulses:Array<String> = [];

	static var current:Map<String, Bool> = [];

	static var previous:Map<String, Bool> = [];

	static var frame:Int = 0;

	static var polledFrame:Int = -1;

	static var initialized:Bool = false;

	public static function init():Void
	{
		if (initialized) return;
		initialized = true;

		FlxG.signals.preUpdate.add(onPreUpdate);
		FlxG.signals.postUpdate.add(poll);
		FlxG.signals.preStateSwitch.add(onStateSwitch);
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

	public static function pulse(action:String):Void
	{
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

	public static function poll():Void
	{
		if (!enabled || polledFrame == frame) return;
		polledFrame = frame;

		final swap = previous;
		previous = current;
		current = swap;
		current.clear();

		for (zone in zones)
			zone.beginPoll();

		#if FLX_TOUCH
		final allowGestures = gesturesActive();

		for (touch in FlxG.touches.list)
		{
			final zone = touch.pressed ? findZone(touch) : null;
			if (zone != null) zone.capture();

			handleGesture(touch, zone, allowGestures);
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

	static function handleGesture(touch:FlxTouch, zone:Null<TouchButton>, allowGestures:Bool):Void
	{
		final id = touch.touchPointID;

		if (touch.justPressed)
		{
			gestures.set(id,
				{
					startX: touch.gameX,
					startY: touch.gameY,
					anchorX: touch.gameX,
					anchorY: touch.gameY,
					startTime: FlxG.game.ticks,
					swiped: false,
					blocked: zone != null
				});
			return;
		}

		final gesture = gestures.get(id);
		if (gesture == null) return;

		if (touch.justReleased)
		{
			gestures.remove(id);

			if (!allowGestures || gesture.blocked || gesture.swiped) return;

			final distance = Math.sqrt(Math.pow(touch.gameX - gesture.startX, 2) + Math.pow(touch.gameY - gesture.startY, 2));
			if (distance <= tapDistance && FlxG.game.ticks - gesture.startTime <= tapTime) pulse('accept');

			return;
		}

		if (!allowGestures || gesture.blocked) return;

		final deltaX = touch.gameX - gesture.anchorX;
		final deltaY = touch.gameY - gesture.anchorY;

		final direction:Float = naturalScrolling ? -1 : 1;

		if (Math.abs(deltaY) >= swipeDistance && Math.abs(deltaY) >= Math.abs(deltaX))
		{
			pulse(deltaY * direction > 0 ? 'ui_down' : 'ui_up');
		}
		else if (Math.abs(deltaX) >= swipeDistance)
		{
			pulse(deltaX * direction > 0 ? 'ui_right' : 'ui_left');
		}
		else
		{
			return;
		}

		gesture.anchorX = touch.gameX;
		gesture.anchorY = touch.gameY;
		gesture.swiped = true;
	}
	#end

	static function onPreUpdate():Void
	{
		frame++;
	}

	static function onStateSwitch():Void
	{
		gestures.clear();
		pulses.resize(0);
	}
}
