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
	}
	
	public static function isEditor(state:Null<FlxState>):Bool
	{
		if (state == null) return false;
		
		final name = Type.getClassName(Type.getClass(state));
		return name != null && name.startsWith(EDITOR_PACKAGE);
	}
	
	static function onPreSwitch():Void
	{
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
