package funkin.mobile;

import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.ui.KeyLocation;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;

class ChartTouchControls
{
	public static var tapDistance:Float = 30;

	public static var tapTime:Float = 0.35;

	public static var scrollStep:Float = 26;

	public static var swipeDistance:Float = 110;

	public static var pinchStep:Float = 70;

	public static var active(default, null):Bool = false;

	static var state:Null<FlxState> = null;

	static var backButton:Null<TouchButton> = null;

	static final touches:Map<Int, {startX:Float, startY:Float, x:Float, y:Float}> = [];

	static var primaryId:Int = -1;

	static var onGrid:Bool = false;

	static var blockingReal:Bool = false;

	static var scrolled:Bool = false;

	static var multi:Bool = false;

	static var startTime:Float = 0;

	static var lastY:Float = 0;

	static var scrollAccumulator:Float = 0;

	static var pinchStart:Float = 0;

	static var pinchSteps:Int = 0;

	static var synthetic:Bool = false;

	static final pendingUps:Array<Void->Void> = [];

	public static function attach(target:FlxState):Void
	{
		detach();

		state = target;
		active = true;

		final camera = MobileUtil.createCamera();
		backButton = MobileUtil.createButton('backButton', 'back', [], MobileUtil.backScale, camera);
		backButton.setPosition(MobileUtil.rightEdge() - backButton.width, MobileUtil.bottomEdge() - backButton.height);
		backButton.blocksGestures = true;
		backButton.onDown.add(() -> pressKey(ESCAPE, 27));
		target.add(backButton);

		final stage = FlxG.stage;
		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin, false, 30000);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove, false, 30000);
		stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd, false, 30000);
		stage.addEventListener(MouseEvent.MOUSE_DOWN, blockMouse, false, 30000);
		stage.addEventListener(MouseEvent.MOUSE_UP, blockMouse, false, 30000);
		stage.addEventListener(MouseEvent.CLICK, blockMouse, false, 30000);
		FlxG.signals.postUpdate.add(flushPending);

		NativeUtil.toast('Tap the grid to place notes, drag to scroll, swipe sideways to change section, two fingers to play or pause, pinch to zoom.', true);
	}

	public static function detach():Void
	{
		if (!active) return;

		active = false;
		state = null;
		backButton = null;
		touches.clear();
		primaryId = -1;
		pendingUps.resize(0);

		final stage = FlxG.stage;
		stage.removeEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
		stage.removeEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
		stage.removeEventListener(TouchEvent.TOUCH_END, onTouchEnd);
		stage.removeEventListener(MouseEvent.MOUSE_DOWN, blockMouse);
		stage.removeEventListener(MouseEvent.MOUSE_UP, blockMouse);
		stage.removeEventListener(MouseEvent.CLICK, blockMouse);
		FlxG.signals.postUpdate.remove(flushPending);
	}

	static function enabled():Bool
	{
		return active && state != null && FlxG.state == state && state.subState == null && !ExternalInput.active;
	}

	static function toGame(stageX:Float, stageY:Float):{x:Float, y:Float}
	{
		final scale = FlxG.scaleMode.scale;
		return {x: (stageX - FlxG.game.x) / scale.x, y: (stageY - FlxG.game.y) / scale.y};
	}

	static function hitsGrid(gameX:Float, gameY:Float):Bool
	{
		final grid:Null<FlxSprite> = Reflect.field(state, 'gridBG');
		if (grid == null || !grid.exists) return false;

		if (backButton != null && TouchUtil.pointOverlaps(gameX, gameY, backButton)) return false;

		return TouchUtil.pointOverlaps(gameX, gameY, grid);
	}

	static function onTouchBegin(event:TouchEvent):Void
	{
		if (!enabled()) return;

		final point = toGame(event.stageX, event.stageY);
		touches.set(event.touchPointID, {startX: point.x, startY: point.y, x: point.x, y: point.y});

		if (primaryId == -1)
		{
			primaryId = event.touchPointID;
			onGrid = hitsGrid(point.x, point.y);
			blockingReal = onGrid;
			scrolled = false;
			multi = false;
			startTime = haxe.Timer.stamp();
			lastY = point.y;
			scrollAccumulator = 0;
			return;
		}

		if (onGrid || multi)
		{
			multi = true;
			pinchStart = currentPinch();
			pinchSteps = 0;
		}
	}

	static function onTouchMove(event:TouchEvent):Void
	{
		if (!enabled()) return;

		final entry = touches.get(event.touchPointID);
		if (entry == null) return;

		final point = toGame(event.stageX, event.stageY);
		entry.x = point.x;
		entry.y = point.y;

		if (multi)
		{
			final distance = currentPinch();
			final steps = Std.int((distance - pinchStart) / pinchStep);

			while (pinchSteps < steps)
			{
				pinchSteps++;
				pressKey(X, 'x'.code);
			}

			while (pinchSteps > steps)
			{
				pinchSteps--;
				pressKey(Z, 'z'.code);
			}
			return;
		}

		if (!onGrid || event.touchPointID != primaryId) return;

		final dx = point.x - entry.startX;
		final dy = point.y - entry.startY;

		if (!scrolled && Math.abs(dy) > tapDistance && Math.abs(dy) >= Math.abs(dx)) scrolled = true;

		if (!scrolled) return;

		scrollAccumulator += point.y - lastY;
		lastY = point.y;

		while (Math.abs(scrollAccumulator) >= scrollStep)
		{
			final direction = scrollAccumulator > 0 ? 1 : -1;
			scrollAccumulator -= direction * scrollStep;
			wheel(direction);
		}
	}

	static function onTouchEnd(event:TouchEvent):Void
	{
		final entry = touches.get(event.touchPointID);
		touches.remove(event.touchPointID);

		if (!enabled() || entry == null) return;

		final point = toGame(event.stageX, event.stageY);

		if (event.touchPointID != primaryId)
		{
			if (Lambda.count(touches) == 0) primaryId = -1;
			return;
		}

		if (Lambda.count(touches) > 0)
		{
			primaryId = touches.keys().next();
			return;
		}

		primaryId = -1;

		if (multi)
		{
			if (pinchSteps == 0 && haxe.Timer.stamp() - startTime <= 0.45) pressKey(SPACE, 32);
			multi = false;
			return;
		}

		if (!onGrid || scrolled) return;

		final dx = point.x - entry.startX;
		final dy = point.y - entry.startY;

		if (Math.abs(dx) >= swipeDistance && Math.abs(dx) > Math.abs(dy) * 1.5)
		{
			if (dx < 0) pressKey(RIGHT, 0);
			else pressKey(LEFT, 0);
			return;
		}

		if (Math.abs(dx) <= tapDistance && Math.abs(dy) <= tapDistance && haxe.Timer.stamp() - startTime <= tapTime) click(event.stageX, event.stageY);
	}

	static function currentPinch():Float
	{
		final points = [for (entry in touches) entry];
		if (points.length < 2) return 0;
		return Math.sqrt(Math.pow(points[0].x - points[1].x, 2) + Math.pow(points[0].y - points[1].y, 2));
	}

	static function blockMouse(event:MouseEvent):Void
	{
		if (synthetic || !enabled()) return;

		if (blockingReal) event.stopImmediatePropagation();
	}

	static function click(stageX:Float, stageY:Float):Void
	{
		final stage = FlxG.stage;

		synthetic = true;
		stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_MOVE, true, false, stageX, stageY));
		stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN, true, false, stageX, stageY, null, false, false, false, true));
		synthetic = false;

		pendingUps.push(() -> {
			synthetic = true;
			stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP, true, false, stageX, stageY));
			stage.dispatchEvent(new MouseEvent(MouseEvent.CLICK, true, false, stageX, stageY));
			synthetic = false;
		});

	}

	static function wheel(delta:Int):Void
	{
		final stage = FlxG.stage;
		synthetic = true;
		stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_WHEEL, true, false, stage.mouseX, stage.mouseY, null, false, false, false, false, delta));
		synthetic = false;
	}

	public static function pressKey(key:FlxKey, charCode:Int):Void
	{
		final stage = FlxG.stage;
		if (stage == null) return;

		stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, false, charCode, key, KeyLocation.STANDARD));
		pendingUps.push(() -> stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP, true, false, charCode, key, KeyLocation.STANDARD)));
	}

	static function flushPending():Void
	{
		if (pendingUps.length == 0) return;

		final actions = pendingUps.copy();
		pendingUps.resize(0);

		for (action in actions)
			action();
	}
}
