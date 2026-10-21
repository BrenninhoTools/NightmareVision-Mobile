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

	public var touchPressed(default, null):Bool = false;

	public var touchJustPressed(default, null):Bool = false;

	public var touchJustReleased(default, null):Bool = false;

	public final onDown:FlxSignal = new FlxSignal();

	public final onUp:FlxSignal = new FlxSignal();

	public var ownedCamera:Null<FlxCamera> = null;

	var held:Bool = false;

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
		return touchEnabled && exists && alive && visible;
	}

	#if FLX_TOUCH
	public function containsTouch(touch:FlxTouch):Bool
	{
		touch.getViewPosition(getCameras()[0], touchPoint);

		return touchPoint.x >= x && touchPoint.x < x + width && touchPoint.y >= y && touchPoint.y < y + height;
	}
	#end

	@:allow(funkin.mobile.TouchInput)
	function beginPoll():Void
	{
		held = false;
	}

	@:allow(funkin.mobile.TouchInput)
	function capture():Void
	{
		held = true;
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

		if (touchJustPressed) onDown.dispatch();
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
