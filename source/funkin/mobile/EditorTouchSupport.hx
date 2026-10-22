package funkin.mobile;

import flixel.FlxG;
import flixel.FlxState;

class EditorTouchSupport
{
	public static final EDITOR_PACKAGE:String = 'funkin.states.editors.';
	
	public static final MENU_ONLY:Array<String> = ['funkin.states.editors.MasterEditorMenu', 'funkin.states.editors.ChartConverterState'];
	
	public static var enabled:Bool = true;
	
	public static var current(default, null):Null<VirtualPad> = null;
	
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
		if (current != null) current.suspended = true;
	}

	public static function resume():Void
	{
		if (suspendCount <= 0) return;
		if (--suspendCount > 0) return;

		TouchInput.gesturesEnabled = gesturesBeforeSuspend;
		if (current != null) current.suspended = false;
	}

	static function onPreSwitch():Void
	{
		if (suspendCount > 0)
		{
			suspendCount = 0;
			TouchInput.gesturesEnabled = gesturesBeforeSuspend;
		}
		current = null;
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
		
		current = new VirtualPad(camera);
		state.add(current);
	}
}
