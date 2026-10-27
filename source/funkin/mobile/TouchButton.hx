package funkin.mobile;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.util.FlxSignal;
#if FLX_TOUCH
import flixel.input.touch.FlxTouch;
#end

class TouchButton extends FlxSprite
{
	static final touchPoint:FlxPoint = FlxPoint.get();

	public var actions:Array<String>;

	public var priority:Int;

	public var blocksGestures:Bool = false;

	public var touchEnabled:Bool = true;

	public var persistent:Bool = false;

	public var haptic:Bool = true;

	public var owner:Null<flixel.FlxState> = null;

	public var touchPressed(default, null):Bool = false;

	public var touchJustPressed(default, null):Bool = false;

	public var touchJustReleased(default, null):Bool = false;

	public final onDown:FlxSignal = new FlxSignal();

	public final onUp:FlxSignal = new FlxSignal();

	public var ownedCamera:Null<FlxCamera> = null;

	var held:Bool = false;

	var captureTime:Float = -1;

	public var pressTime(default, null):Float = 0;

	public var releaseTime(default, null):Float = 0;

	var armed:Bool = false;

	public function new(x:Float = 0, y:Float = 0, ?actions:Array<String>, priority:Int = 1)
	{
		super(x, y);

		this.actions = actions ?? [];
		this.priority = priority;

		scrollFactor.set();

		TouchInput.init();
		TouchInput.register(this);
	}

	public function isTouchable():Bool
	{
		if (ExternalInput.active || !touchEnabled || !exists || !alive || !visible) return false;
		if (persistent) return true;

		final state = owner ?? TouchUtil.getOwnerState(this);
		return state == null || state == TouchUtil.getActiveState();
	}

	#if FLX_TOUCH
	public function containsTouch(touch:FlxTouch):Bool
	{
		touch.getViewPosition(TouchUtil.getCamera(this), touchPoint);

		return touchPoint.x >= x && touchPoint.x < x + width && touchPoint.y >= y && touchPoint.y < y + height;
	}
	#end

	@:allow(funkin.mobile.TouchInput)
	function beginPoll():Void
	{
		held = false;
		captureTime = -1;
	}

	@:allow(funkin.mobile.TouchInput)
	function capture(time:Float = -1):Void
	{
		held = true;
		if (time >= 0 && (captureTime < 0 || time < captureTime)) captureTime = time;
	}

	@:allow(funkin.mobile.TouchInput)
	function endPoll():Void
	{
		if (!isTouchable()) held = false;

		if (!armed)
		{
			if (!held) armed = true;
			held = false;
		}

		final wasPressed = touchPressed;

		touchPressed = held;
		touchJustPressed = touchPressed && !wasPressed;
		touchJustReleased = !touchPressed && wasPressed;

		if (touchJustPressed) pressTime = captureTime >= 0 ? captureTime : TouchInput.now();
		if (touchJustReleased) releaseTime = TouchInput.lastReleaseTime >= 0 ? TouchInput.lastReleaseTime : TouchInput.now();

		if (touchJustPressed)
		{
			if (haptic) Haptics.button();
			onDown.dispatch();
		}
		if (touchJustReleased) onUp.dispatch();
	}

	public function loadAtlas(path:String, prefix:String, fps:Float = 24):TouchButton
	{
		frames = Paths.getSparrowAtlas(path);

		animation.addByIndices('idle', prefix, [0], '', fps, false);
		animation.addByPrefix('press', prefix, fps, false);
		animation.play('idle');

		onDown.add(() -> animation.play('press', true));

		return this;
	}

	override function draw():Void
	{
		if (ExternalInput.active) return;
		super.draw();
	}

	override function destroy():Void
	{
		TouchInput.unregister(this);

		onDown.destroy();
		onUp.destroy();

		if (ownedCamera != null && FlxG.cameras.list.contains(ownedCamera)) FlxG.cameras.remove(ownedCamera);
		ownedCamera = null;

		super.destroy();
	}
}
