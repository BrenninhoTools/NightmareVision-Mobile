package funkin.mobile;

import funkin.mobile.util.MobileUtil;
import funkin.mobile.input.ExternalInput;
import funkin.mobile.input.TouchButton;
import funkin.mobile.input.TouchInput;
import funkin.mobile.util.TouchUtil;

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

	public static var pad(default, null):Null<VirtualPad> = null;

	static inline function letter(image:String, key:FlxKey, ?charCode:Int):VirtualPad.VirtualKey
	{
		return VirtualPad.letter(image, key, charCode);
	}

	static inline function toggle(image:String, key:FlxKey):VirtualPad.VirtualKey
	{
		return VirtualPad.toggleKey(image, key);
	}

	public static function layoutFor(name:String):Null<Array<Array<VirtualPad.VirtualKey>>>
	{
		return switch (name)
		{
			case 'funkin.states.editors.ChartEditorState' | 'funkin.states.editors.OLDChartEditorState':
				[
					[letter('e', E), letter('d', Q, 'q'.code)],
					[letter('z', Z), letter('x', X)],
					[letter('f', S, 's'.code), letter('v', SPACE, 32)],
					[toggle('s', SHIFT), toggle('c', CONTROL)],
					[letter('a', ENTER, 13)]
				];
			case 'funkin.states.editors.CharacterEditorState':
				[
					[letter('a', A), letter('y', W, 'w'.code), letter('s', S), letter('d', D)],
					[letter('z', Z), letter('x', X), letter('c', C), letter('v', SPACE, 32)],
					[letter('e', E), letter('g', Q, 'q'.code), toggle('b', SHIFT), toggle('f', CONTROL)]
				];
			case 'funkin.states.editors.MenuCharacterEditorState':
				[[letter('a', ENTER, 13), letter('v', SPACE, 32), toggle('s', SHIFT)]];
			case 'funkin.states.editors.WeekEditorState':
				[[letter('a', ENTER, 13)]];
			case 'funkin.states.editors.SongMetaEditor':
				[[toggle('c', CONTROL), letter('s', S)]];
			case 'funkin.states.editors.WIPNoteSkinEditor':
				[[letter('e', E), letter('d', Q, 'q'.code), letter('y', R, 'r'.code)], [toggle('s', SHIFT), toggle('c', CONTROL)]];
			default:
				null;
		}
	}

	public static function hasDPad(name:String):Bool
	{
		return switch (name)
		{
			case 'funkin.states.editors.SongMetaEditor' | 'funkin.states.editors.WeekEditorState': false;
			default: true;
		}
	}

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
		if (pad != null) pad.suspended = true;
	}

	public static function resume():Void
	{
		if (suspendCount <= 0) return;
		if (--suspendCount > 0) return;

		TouchInput.gesturesEnabled = gesturesBeforeSuspend;
		if (current != null) current.visible = true;
		if (pad != null) pad.suspended = false;
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
		pad = null;
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

		final dpad = hasDPad(name) ? VirtualPad.DEFAULT_DPAD : [];
		final actions = layoutFor(name) ?? VirtualPad.DEFAULT_ACTIONS;
		final layout:VirtualPad.VirtualPadLayout = CHART_EDITORS.contains(name) ? {dpadRow: true, columns: 2, bottomLimit: current.y - VirtualPad.gap * 2} : {rightLimit: current.x - VirtualPad.gap * 2};
		pad = new VirtualPad(camera, dpad, actions, null, layout);
		state.add(pad);
		
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
		if (pad != null && pad.exists && pad.hitsButton(stageX, stageY)) return true;
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
