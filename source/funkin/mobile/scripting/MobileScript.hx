package funkin.mobile.scripting;

import funkin.mobile.util.MobileUtil;
import funkin.mobile.VirtualPad;
import funkin.mobile.backend.StorageUtil;
import funkin.mobile.input.TouchButton;
import funkin.mobile.input.TouchInput;
import funkin.mobile.native.NativeUtil;
import funkin.mobile.util.Hitbox;
import funkin.mobile.util.TouchUtil;
import funkin.mobile.ui.ScreenStyle;
import funkin.mobile.haptics.Haptics;
import funkin.mobile.haptics.Haptics.HapticType;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.util.FlxColor;

import funkin.scripts.ScriptGroup;

class MobileScript
{
	public static var isMobile(get, never):Bool;

	public static var isAndroid(get, never):Bool;

	public static var isIOS(get, never):Bool;

	public static var touchPressed(get, never):Bool;

	public static var touchJustPressed(get, never):Bool;

	public static var touchJustReleased(get, never):Bool;

	public static var tapped(get, never):Bool;

	public static var doubleTapped(get, never):Bool;

	public static var longPressed(get, never):Bool;

	public static var dragging(get, never):Bool;

	public static var touchCount(get, never):Int;

	public static var touchX(get, never):Float;

	public static var touchY(get, never):Float;

	public static var tapX(get, never):Float;

	public static var tapY(get, never):Float;

	public static var dragX(get, never):Float;

	public static var dragY(get, never):Float;

	public static var holdTime(get, never):Float;

	public static var swipe(get, never):String;

	public static var hitbox(get, never):Null<Hitbox>;

	public static var pauseButton(get, never):Null<TouchButton>;

	public static var hapticsEnabled(get, never):Bool;

	public static var storagePath(get, never):String;

	public static var storageType(get, never):String;

	public static var freeSpaceMB(get, never):Int;

	static var scriptCamera:Null<FlxCamera> = null;

	static var lastTouchCount:Int = 0;

	static var lastExternal:Bool = false;

	static var lastSafeTop:Float = -1;

	public static var screenStyle(get, never):String;

	public static var safeLeft(get, never):Float;

	public static var safeRight(get, never):Float;

	public static var safeTop(get, never):Float;

	public static var safeBottom(get, never):Float;

	public static var externalInput(get, never):Bool;

	public static var lastInputDevice(get, never):String;

	public static var pinching(get, never):Bool;

	public static var pinchScale(get, never):Float;

	public static function getTouches():Array<{id:Int, x:Float, y:Float, justPressed:Bool, justReleased:Bool}>
	{
		final touches:Array<{id:Int, x:Float, y:Float, justPressed:Bool, justReleased:Bool}> = [];

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
			if (touch.pressed || touch.justReleased)
				touches.push({id: touch.touchPointID, x: touch.gameX, y: touch.gameY, justPressed: touch.justPressed, justReleased: touch.justReleased});
		#end

		return touches;
	}

	public static function touchedInRect(x:Float, y:Float, width:Float, height:Float, ?camera:FlxCamera):Bool
	{
		#if mobile
		return TouchUtil.pressedInRect(x, y, width, height, camera);
		#else
		return false;
		#end
	}

	public static function tappedInRect(x:Float, y:Float, width:Float, height:Float, ?camera:FlxCamera):Bool
	{
		#if mobile
		return TouchUtil.tappedInRect(x, y, width, height, camera);
		#else
		return false;
		#end
	}

	public static function hapticConfirm():Void
	{
		Haptics.confirm();
	}

	public static function hapticRumble(strength:Float = 1):Void
	{
		Haptics.rumble(strength, 0);
	}

	public static function hapticImpact(strength:Float = 1):Void
	{
		Haptics.impact(strength);
	}

	public static function hapticDenied():Void
	{
		Haptics.denied();
	}

	public static function getDeviceSummary():String
	{
		return NativeUtil.getDeviceSummary();
	}

	public static function log(message:String):Void
	{
		funkin.mobile.android.logcat.LogcatUtil.info(message);
	}

	public static function touchOverlaps(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		#if mobile
		return TouchUtil.overlaps(object, camera);
		#else
		return false;
		#end
	}

	public static function justPressedOn(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		#if mobile
		return TouchUtil.justPressedOn(object, camera);
		#else
		return false;
		#end
	}

	public static function justReleasedOn(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		#if mobile
		return TouchUtil.justReleasedOn(object, camera);
		#else
		return false;
		#end
	}

	public static function tappedOn(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		#if mobile
		return TouchUtil.tappedOn(object, camera);
		#else
		return false;
		#end
	}

	public static function doubleTappedOn(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		#if mobile
		return TouchUtil.doubleTappedOn(object, camera);
		#else
		return false;
		#end
	}

	public static function longPressedOn(object:FlxBasic, ?camera:FlxCamera):Bool
	{
		#if mobile
		return TouchUtil.longPressedOn(object, camera);
		#else
		return false;
		#end
	}

	public static function holding(object:FlxBasic, minTime:Float = 0, ?camera:FlxCamera):Bool
	{
		#if mobile
		return TouchUtil.holding(object, minTime, camera);
		#else
		return false;
		#end
	}

	public static function setGesturesEnabled(value:Bool):Void
	{
		TouchInput.gesturesEnabled = value;
	}

	public static function setSwipeDistance(value:Float):Void
	{
		if (value > 0) TouchInput.swipeDistance = value;
	}

	public static function setTwoFingerBack(value:Bool):Void
	{
		TouchInput.twoFingerBack = value;
	}

	public static function pulseAction(action:String):Void
	{
		TouchInput.pulse(action);
	}

	public static function vibrate(milliseconds:Int = 20, intensity:Float = 1):Void
	{
		#if mobile
		if (!ClientPrefs.haptics) return;
		NativeUtil.vibrate(milliseconds, intensity * ClientPrefs.hapticsIntensity);
		#end
	}

	public static function hapticLight():Void
	{
		Haptics.play(LIGHT);
	}

	public static function hapticMedium():Void
	{
		Haptics.play(MEDIUM);
	}

	public static function hapticHeavy():Void
	{
		Haptics.play(HEAVY);
	}

	public static function toast(message:String, longDuration:Bool = false):Void
	{
		#if mobile
		NativeUtil.toast(message, longDuration);
		#end
	}

	public static function showKeyboard():Void
	{
		#if mobile
		NativeUtil.showKeyboard();
		#end
	}

	public static function hideKeyboard():Void
	{
		#if mobile
		NativeUtil.hideKeyboard();
		#end
	}

	public static function getCamera():FlxCamera
	{
		if (scriptCamera == null || !FlxG.cameras.list.contains(scriptCamera)) scriptCamera = MobileUtil.createCamera();
		return scriptCamera;
	}

	public static function createButton(x:Float, y:Float, image:String, ?onPress:Void->Void, ?onRelease:Void->Void, ?actions:Array<String>, ?camera:FlxCamera):TouchButton
	{
		final button = new TouchButton(x, y, actions ?? [], 2);
		button.loadGraphic(Paths.image(image));
		button.cameras = [camera ?? getCamera()];
		button.alpha = MobileUtil.buttonAlpha;

		if (onPress != null) button.onDown.add(onPress);
		if (onRelease != null) button.onUp.add(onRelease);

		#if mobile
		FlxG.state.add(button);
		#else
		button.visible = false;
		button.touchEnabled = false;
		#end

		return button;
	}

	public static function createAtlasButton(x:Float, y:Float, image:String, prefix:String, ?onPress:Void->Void, ?onRelease:Void->Void, ?actions:Array<String>, scale:Float = 1, ?camera:FlxCamera):TouchButton
	{
		final button = MobileUtil.createButton(image, prefix, actions ?? [], scale, camera ?? getCamera());
		button.setPosition(x, y);

		if (onPress != null) button.onDown.add(onPress);
		if (onRelease != null) button.onUp.add(onRelease);

		#if mobile
		FlxG.state.add(button);
		#else
		button.visible = false;
		button.touchEnabled = false;
		#end

		return button;
	}

	public static function removeButton(button:TouchButton):Void
	{
		if (button == null) return;
		FlxG.state.remove(button, true);
		button.destroy();
	}

	public static function createVirtualPad(?dpad:Array<VirtualPad.VirtualKey>, ?actions:Array<Array<VirtualPad.VirtualKey>>):Null<VirtualPad>
	{
		#if mobile
		final pad = new VirtualPad(getCamera(), dpad, actions);
		FlxG.state.add(pad);
		return pad;
		#else
		return null;
		#end
	}

	public static function setHitboxEnabled(value:Bool):Void
	{
		final box = hitbox;
		if (box != null) box.enabled = value;
	}

	public static function setHitboxVisible(?value:Bool):Void
	{
		final box = hitbox;
		if (box == null) return;

		box.forceVisible = value;
		box.idleAlpha = box.idleAlpha;
	}

	public static function setHitboxIdleAlpha(value:Float):Void
	{
		final box = hitbox;
		if (box != null) box.idleAlpha = value;
	}

	public static function setHitboxPressedAlpha(value:Float):Void
	{
		final box = hitbox;
		if (box != null) box.lanePressedAlpha = Math.max(0, Math.min(1, value));
	}

	public static function setHitboxColors(colors:Array<Int>):Void
	{
		final box = hitbox;
		if (box != null) box.setColors([for (color in colors) (color : FlxColor)]);
	}

	public static function setHitboxLaneColor(lane:Int, color:Int):Void
	{
		final box = hitbox;
		if (box != null) box.setLaneColor(lane, color);
	}

	public static function setHitboxLane(lane:Int, x:Float, y:Float, width:Float, height:Float):Void
	{
		final box = hitbox;
		if (box != null) box.setLaneBounds(lane, x, y, width, height);
	}

	public static function setHitboxLaneActions(lane:Int, actions:Array<String>):Void
	{
		final box = hitbox;
		if (box != null) box.setLaneActions(lane, actions);
	}

	public static function resetHitbox():Void
	{
		final box = hitbox;
		if (box == null) return;

		box.resetLayout();
		box.setColors(Hitbox.COLORS);
		box.forceVisible = null;
		box.idleAlpha = 0;
		box.lanePressedAlpha = Hitbox.pressedAlpha;
	}

	public static function isHitboxLanePressed(lane:Int):Bool
	{
		return hitbox?.isLanePressed(lane) ?? false;
	}

	public static function flashHitboxLane(lane:Int, duration:Float = 0.25, ?color:Int):Void
	{
		final hitbox = get_hitbox();
		if (hitbox != null) hitbox.flashLane(lane, duration, color);
	}

	public static function getDeviceModel():String
	{
		return NativeUtil.getDeviceModel();
	}

	public static function getOSVersion():String
	{
		return NativeUtil.getOSVersion();
	}

	public static function getBatteryLevel():Int
	{
		return NativeUtil.getBatteryLevel();
	}

	public static function isCharging():Bool
	{
		return NativeUtil.isCharging();
	}

	public static function isPowerSaveMode():Bool
	{
		return NativeUtil.isPowerSaveMode();
	}

	public static function getRefreshRate():Float
	{
		return NativeUtil.getRefreshRate();
	}

	public static function openURL(url:String):Bool
	{
		return NativeUtil.openURL(url);
	}

	public static function setClipboard(text:String):Void
	{
		NativeUtil.setClipboard(text);
	}

	public static function getClipboard():String
	{
		return NativeUtil.getClipboard();
	}

	public static function setKeepScreenOn(value:Bool):Void
	{
		NativeUtil.setKeepScreenOn(value);
	}

	public static function isExternalInputActive():Bool
	{
		return funkin.mobile.input.ExternalInput.active;
	}

	public static function setPauseButtonVisible(value:Bool):Void
	{
		final button = pauseButton;
		if (button != null) button.alpha = value ? MobileUtil.buttonAlpha : 0;
	}

	public static function setPauseButtonEnabled(value:Bool):Void
	{
		final button = pauseButton;
		if (button != null) button.touchEnabled = value;
	}

	public static function setPauseButtonPosition(x:Float, y:Float):Void
	{
		final button = pauseButton;
		if (button == null) return;
		MobileUtil.release(button);
		button.setPosition(x, y);
	}

	@:allow(funkin.backend.MusicBeatState)
	static function dispatch(group:Null<ScriptGroup>):Void
	{
		#if mobile
		if (group == null) return;

		TouchInput.poll();

		final count = TouchInput.touchCount;
		if (count > lastTouchCount) group.call('onTouchBegin', [TouchInput.touchPosition.x, TouchInput.touchPosition.y, count]);
		if (count < lastTouchCount) group.call('onTouchEnd', [TouchInput.touchPosition.x, TouchInput.touchPosition.y, count]);

		if (TouchInput.justTapped) group.call('onTap', [TouchInput.tapPosition.x, TouchInput.tapPosition.y]);
		if (TouchInput.justDoubleTapped) group.call('onDoubleTap', [TouchInput.tapPosition.x, TouchInput.tapPosition.y]);
		if (TouchInput.justLongPressed) group.call('onLongPress', [TouchInput.touchPosition.x, TouchInput.touchPosition.y]);
		if (TouchInput.lastSwipe != NONE) group.call('onSwipe', [swipeName(TouchInput.lastSwipe)]);
		if (TouchInput.dragging && (TouchInput.dragX != 0 || TouchInput.dragY != 0)) group.call('onDrag', [TouchInput.dragX, TouchInput.dragY]);
		if (TouchInput.pinching && TouchInput.pinchDelta != 0) group.call('onPinch', [get_pinchScale(), TouchInput.pinchDelta]);

		final external = funkin.mobile.input.ExternalInput.active;
		if (external != lastExternal) group.call('onExternalInputChange', [external]);

		if (lastSafeTop >= 0 && lastSafeTop != ScreenStyle.safeTop) group.call('onSafeAreaChange', [ScreenStyle.safeLeft, ScreenStyle.safeTop, ScreenStyle.safeRight, ScreenStyle.safeBottom]);
		#end
	}

	@:allow(funkin.backend.MusicBeatState)
	static function endDispatch():Void
	{
		lastTouchCount = TouchInput.touchCount;
		lastExternal = funkin.mobile.input.ExternalInput.active;
		lastSafeTop = ScreenStyle.safeTop;
	}

	static function swipeName(direction:funkin.mobile.input.TouchInput.SwipeDirection):String
	{
		return switch (direction)
		{
			case UP: 'up';
			case DOWN: 'down';
			case LEFT: 'left';
			case RIGHT: 'right';
			default: '';
		}
	}

	static function get_screenStyle():String
	{
		#if mobile
		return ClientPrefs.screenStyle;
		#else
		return 'Original';
		#end
	}

	static function get_safeLeft():Float return ScreenStyle.safeLeft;

	static function get_safeRight():Float return ScreenStyle.safeRight;

	static function get_safeTop():Float return ScreenStyle.safeTop;

	static function get_safeBottom():Float return ScreenStyle.safeBottom;

	static function get_externalInput():Bool return funkin.mobile.input.ExternalInput.active;

	static function get_lastInputDevice():String return funkin.mobile.input.ExternalInput.lastDevice;

	static function get_pinching():Bool
	{
		#if mobile
		return TouchUtil.pinching;
		#else
		return false;
		#end
	}

	static function get_pinchScale():Float
	{
		#if mobile
		return TouchUtil.pinchScale;
		#else
		return 1;
		#end
	}

	static function get_isMobile():Bool
	{
		return #if mobile true #else false #end;
	}

	static function get_isAndroid():Bool
	{
		return #if android true #else false #end;
	}

	static function get_isIOS():Bool
	{
		return #if ios true #else false #end;
	}

	static function get_touchPressed():Bool
	{
		#if mobile
		return TouchUtil.pressed;
		#else
		return false;
		#end
	}

	static function get_touchJustPressed():Bool
	{
		#if mobile
		return TouchUtil.justPressed;
		#else
		return false;
		#end
	}

	static function get_touchJustReleased():Bool
	{
		#if mobile
		return TouchUtil.justReleased;
		#else
		return false;
		#end
	}

	static function get_tapped():Bool
	{
		TouchInput.poll();
		return TouchInput.justTapped;
	}

	static function get_doubleTapped():Bool
	{
		TouchInput.poll();
		return TouchInput.justDoubleTapped;
	}

	static function get_longPressed():Bool
	{
		TouchInput.poll();
		return TouchInput.justLongPressed;
	}

	static function get_dragging():Bool
	{
		TouchInput.poll();
		return TouchInput.dragging;
	}

	static function get_touchCount():Int
	{
		TouchInput.poll();
		return TouchInput.touchCount;
	}

	static function get_touchX():Float
	{
		TouchInput.poll();
		return TouchInput.touchPosition.x;
	}

	static function get_touchY():Float
	{
		TouchInput.poll();
		return TouchInput.touchPosition.y;
	}

	static function get_tapX():Float
	{
		return TouchInput.tapPosition.x;
	}

	static function get_tapY():Float
	{
		return TouchInput.tapPosition.y;
	}

	static function get_dragX():Float
	{
		TouchInput.poll();
		return TouchInput.dragX;
	}

	static function get_dragY():Float
	{
		TouchInput.poll();
		return TouchInput.dragY;
	}

	static function get_holdTime():Float
	{
		TouchInput.poll();
		return TouchInput.holdTime;
	}

	static function get_swipe():String
	{
		TouchInput.poll();
		return swipeName(TouchInput.lastSwipe);
	}

	static function get_hitbox():Null<Hitbox>
	{
		#if mobile
		return PlayState.instance?.hitbox;
		#else
		return null;
		#end
	}

	static function get_pauseButton():Null<TouchButton>
	{
		#if mobile
		return PlayState.instance?.pauseButton;
		#else
		return null;
		#end
	}

	static function get_hapticsEnabled():Bool
	{
		return Haptics.enabled;
	}

	static function get_storagePath():String
	{
		#if mobile
		return StorageUtil.directory;
		#elseif sys
		return Sys.getCwd();
		#else
		return '';
		#end
	}

	static function get_storageType():String
	{
		return StorageUtil.getActiveStorageType();
	}

	static function get_freeSpaceMB():Int
	{
		return StorageUtil.getFreeSpaceMB();
	}
}
