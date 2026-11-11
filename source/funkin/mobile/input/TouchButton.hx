package funkin.mobile.input;

import funkin.mobile.haptics.Haptics;
import funkin.mobile.util.TouchUtil;

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

	public var hitTest:Null<(Float, Float, Float) -> Bool> = null;

	var held:Bool = false;

	var captureTime:Float = -1;

	public var pressTime(default, null):Float = 0;

	public var releaseTime(default, null):Float = 0;

	var armed:Bool = false;

	var pendingRelease:Float = -1;

	var pendingReleaseFrame:Int = -1;

	var lastHeldFrame:Int = -1;

	@:allow(funkin.mobile.input.TouchInput)
	function captureRelease(time:Float):Void
	{
		final frame = TouchInput.currentFrame;
		if (pendingReleaseFrame != frame || time > pendingRelease) pendingRelease = time;
		pendingReleaseFrame = frame;
	}

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
	public function containsTouch(touch:FlxTouch, padding:Float = 0):Bool
	{
		return containsPoint(touch.gameX, touch.gameY, padding);
	}
	#end

	public function containsPoint(gameX:Float, gameY:Float, padding:Float = 0):Bool
	{
		final camera = TouchUtil.getCamera(this);
		final viewX = (gameX - camera.x) / camera.zoom + camera.viewMarginX;
		final viewY = (gameY - camera.y) / camera.zoom + camera.viewMarginY;

		if (hitTest != null) return hitTest(viewX, viewY, padding);

		return viewX >= x - padding && viewX < x + width + padding && viewY >= y - padding && viewY < y + height + padding;
	}

	@:allow(funkin.mobile.input.TouchInput)
	function beginPoll():Void
	{
		held = false;
		captureTime = -1;
	}

	@:allow(funkin.mobile.input.TouchInput)
	function capture(time:Float = -1):Void
	{
		held = true;
		if (time >= 0 && (captureTime < 0 || time < captureTime)) captureTime = time;
	}

	@:allow(funkin.mobile.input.TouchInput)
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
		if (touchJustReleased)
		{
			if (pendingReleaseFrame >= lastHeldFrame && pendingRelease >= pressTime) releaseTime = pendingRelease;
			else releaseTime = TouchInput.now();
			pendingRelease = -1;
			pendingReleaseFrame = -1;
		}
		if (touchPressed) lastHeldFrame = TouchInput.currentFrame;

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
