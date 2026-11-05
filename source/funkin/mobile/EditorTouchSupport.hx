package funkin.mobile;

import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;
import openfl.ui.KeyLocation;

class EditorTouchSupport
{
	public static final EDITOR_PACKAGE:String = 'funkin.states.editors.';
	
	public static final CHART_EDITORS:Array<String> = ['funkin.states.editors.ChartEditorState', 'funkin.states.editors.OLDChartEditorState'];
	
	public static final MENU_ONLY:Array<String> = ['funkin.states.editors.MasterEditorMenu', 'funkin.states.editors.ChartConverterState'];
	
	public static var enabled:Bool = true;
	
	public static var current(default, null):Null<TouchButton> = null;

	static var escapeHeld:Bool = false;
	
	static var initialized:Bool = false;
	
	static var gesturesBefore:Bool = true;
	
	static var inEditor:Bool = false;
	
	public static function init():Void
	{
		if (initialized) return;
		initialized = true;
		
		FlxG.signals.preStateSwitch.add(onPreSwitch);
		FlxG.signals.postStateSwitch.add(onPostSwitch);
		FlxG.signals.postUpdate.add(onUpdate);
	}
	
	public static function isEditor(state:Null<FlxState>):Bool
	{
		if (state == null) return false;
		
		final name = Type.getClassName(Type.getClass(state));
		return name != null && name.startsWith(EDITOR_PACKAGE);
	}
	
	public static var scrollStep:Float = 28;

	static var scrollAccumulator:Float = 0;

	static var lastCenterY:Float = 0;

	static var twoFingers:Bool = false;

	static function onUpdate():Void
	{
		if (!inEditor || current == null || ExternalInput.active) return;

		TouchInput.poll();

		if (!TouchInput.pinching)
		{
			twoFingers = false;
			scrollAccumulator = 0;
			return;
		}

		final centerY = TouchInput.pinchCenter.y;

		if (!twoFingers)
		{
			twoFingers = true;
			lastCenterY = centerY;
			return;
		}

		scrollAccumulator += centerY - lastCenterY;
		lastCenterY = centerY;

		while (Math.abs(scrollAccumulator) >= scrollStep)
		{
			final direction = scrollAccumulator > 0 ? 1 : -1;
			scrollAccumulator -= direction * scrollStep;
			dispatchWheel(direction);
		}
	}

	static function dispatchWheel(delta:Int):Void
	{
		final stage = FlxG.stage;
		if (stage == null) return;

		stage.dispatchEvent(new openfl.events.MouseEvent(openfl.events.MouseEvent.MOUSE_WHEEL, true, false, stage.mouseX, stage.mouseY, null, false, false, false, false, delta));
	}

	static var suspendCount:Int = 0;

	static var gesturesBeforeSuspend:Bool = false;

	public static function suspend():Void
	{
		if (!inEditor) return;

		if (suspendCount++ > 0) return;

		gesturesBeforeSuspend = TouchInput.gesturesEnabled;
		TouchInput.gesturesEnabled = true;
		if (current != null)
		{
			releaseEscape();
			current.visible = false;
		}
	}

	public static function resume():Void
	{
		if (suspendCount <= 0) return;
		if (--suspendCount > 0) return;

		TouchInput.gesturesEnabled = gesturesBeforeSuspend;
		if (current != null) current.visible = true;
	}

	static function onPreSwitch():Void
	{
		if (suspendCount > 0)
		{
			suspendCount = 0;
			TouchInput.gesturesEnabled = gesturesBeforeSuspend;
		}
		releaseEscape();
		current = null;
		ChartTouchControls.detach();
	}
	
	static function onPostSwitch():Void
	{
		final state = FlxG.state;
		final editor = enabled && isEditor(state);
		
		if (editor && !inEditor) gesturesBefore = TouchInput.gesturesEnabled;
		if (!editor && inEditor) TouchInput.gesturesEnabled = gesturesBefore;
		inEditor = editor;
		
		if (!editor) return;
		
		final name = Type.getClassName(Type.getClass(state));
		final camera = MobileUtil.createCamera();
		
		if (MENU_ONLY.contains(name))
		{
			state.add(MobileUtil.createBackButton(camera));
			return;
		}
		
		TouchInput.gesturesEnabled = false;
		
		current = createEditorBackButton(camera, state);
		state.add(current);
		
		if (CHART_EDITORS.contains(name)) ChartTouchControls.attach(state);
	}
	
	static function createEditorBackButton(camera:flixel.FlxCamera, state:FlxState):TouchButton
	{
		final button = MobileUtil.createBackButton(camera);
		button.actions = [];
		button.persistent = false;
		button.owner = state;
		button.onDown.add(pressEscape);
		button.onUp.add(releaseEscape);
		return button;
	}
	
	public static function hitsButton(stageX:Float, stageY:Float):Bool
	{
		if (current == null || !current.exists || !current.visible) return false;
		
		final camera = TouchUtil.getCamera(current);
		final scale = FlxG.scaleMode.scale;
		final gameX = (stageX - FlxG.game.x) / scale.x;
		final gameY = (stageY - FlxG.game.y) / scale.y;
		final x = (gameX - camera.x) / camera.zoom + camera.viewMarginX;
		final y = (gameY - camera.y) / camera.zoom + camera.viewMarginY;
		final padding = 10;
		
		return x >= current.x - padding && x < current.x + current.width + padding && y >= current.y - padding && y < current.y + current.height + padding;
	}
	
	static function pressEscape():Void
	{
		final stage = FlxG.stage;
		if (stage == null || escapeHeld) return;
		
		escapeHeld = true;
		stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, false, 27, FlxKey.ESCAPE, KeyLocation.STANDARD));
	}
	
	static function releaseEscape():Void
	{
		if (!escapeHeld) return;
		
		escapeHeld = false;
		final stage = FlxG.stage;
		if (stage != null) stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP, true, false, 27, FlxKey.ESCAPE, KeyLocation.STANDARD));
	}
}
