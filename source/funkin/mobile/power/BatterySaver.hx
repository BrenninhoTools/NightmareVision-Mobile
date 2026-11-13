package funkin.mobile.power;

#if android
import androidmanager.battery.Battery;
import androidmanager.callback.Callback;
import androidmanager.content.Interface;
import androidmanager.os.Device;
import androidmanager.view.Window;
#elseif ios
import ios.Callback as IOSCallback;
import ios.Device as IOSDevice;
import ios.Screen as IOSScreen;
import ios.Toast as IOSToast;
#end

import flixel.FlxG;

enum abstract SaverReason(String) to String
{
	var NONE = 'Off';
	var FORCED = 'Always on';
	var LOW_BATTERY = 'Low battery';
	var SYSTEM = 'System battery saver';
	var HOT = 'Device is hot';
}

class BatterySaver
{
	public static final MODES:Array<String> = ['Off', 'Auto', 'On'];

	public static var gameplayFps:Int = 60;

	public static var menuFps:Int = 30;

	public static var idleFps:Int = 20;

	public static var idleSeconds:Float = 20;

	public static var pollSeconds:Float = 15;

	public static var hysteresis:Int = 5;

	public static var active(default, null):Bool = false;

	public static var idle(default, null):Bool = false;

	public static var reason(default, null):SaverReason = NONE;

	public static var level(default, null):Int = -1;

	public static var charging(default, null):Bool = false;

	public static var systemSaver(default, null):Bool = false;

	public static var thermal(default, null):Int = 0;

	public static var onChange(default, null):lime.app.Event<Bool->Void> = new lime.app.Event<Bool->Void>();

	static var initialized:Bool = false;

	static var pollTimer:Float = 0;

	static var lastInput:Float = 0;

	static var appliedFps:Int = -1;

	static var appliedRefresh:Bool = false;

	static var appliedSustained:Bool = false;

	static var appliedKeepOn:Null<Bool> = null;

	static var savedTrails:Bool = true;

	static var savedRipples:Bool = true;

	public static function init():Void
	{
		#if (android || ios)
		if (initialized) return;
		initialized = true;

		try
		{
			#if android
			Battery.init();
			Callback.init();
			Callback.onTrimMemory.add(onTrimMemory);
			Callback.onLowMemory.add(() -> freeMemory(true));
			Callback.onResume.add(() -> {
				lastInput = now();
				pollTimer = pollSeconds;
			});
			#else
			IOSDevice.startMonitoring();
			IOSCallback.addListener(onIOSEvent);
			#end
		}
		catch (e:Dynamic)
		{
			funkin.mobile.android.logcat.LogcatUtil.warn('Battery saver init failed: ' + e);
		}

		savedTrails = funkin.mobile.ui.TouchCursor.trails;
		savedRipples = funkin.mobile.ui.TouchCursor.ripples;
		lastInput = now();
		poll();
		FlxG.signals.postUpdate.add(update);
		#end
	}

	public static function refresh():Void
	{
		#if (android || ios)
		if (!initialized) return;
		poll();
		apply();
		#end
	}

	public static function describe():String
	{
		#if (android || ios)
		final battery = level >= 0 ? level + '%' + (charging ? ' charging' : '') : 'unknown';
		return (active ? 'Active: ' + reason : 'Inactive') + ', battery ' + battery + (thermal >= 2 ? ', device hot' : '');
		#else
		return 'Not available';
		#end
	}

	static inline function now():Float
	{
		return haxe.Timer.stamp();
	}

	static function update():Void
	{
		#if (android || ios)
		if (hasInput()) lastInput = now();

		pollTimer += FlxG.elapsed;
		if (pollTimer >= pollSeconds) poll();

		apply();
		#end
	}

	static function hasInput():Bool
	{
		if (FlxG.touches.list.length > 0) return true;
		if (FlxG.keys.pressed.ANY) return true;
		if (FlxG.mouse.pressed || FlxG.mouse.justMoved || FlxG.mouse.wheel != 0) return true;
		return FlxG.gamepads.anyInput();
	}

	#if (android || ios)
	static function poll():Void
	{
		pollTimer = 0;

		try
		{
			#if android
			level = Battery.getLevel();
			charging = Battery.isCharging();
			systemSaver = Battery.isPowerSaveMode();
			thermal = Device.thermalStatus;
			#else
			final battery = IOSDevice.batteryLevel;
			level = battery >= 0 ? Math.round(battery * 100) : -1;
			final state:Int = IOSDevice.batteryState;
			charging = state == 2 || state == 3;
			systemSaver = IOSDevice.lowPowerMode;
			final heat:Int = IOSDevice.thermalState;
			thermal = heat >= 2 ? heat + 1 : heat * 2;
			#end
		}
		catch (e:Dynamic) {}

		final wasActive = active;
		reason = resolveReason(wasActive);
		active = reason != NONE;

		if (active == wasActive) return;

		funkin.mobile.android.logcat.LogcatUtil.info('Battery saver ' + (active ? 'on: ' + reason : 'off'));
		if (ClientPrefs.batterySaver == 'Auto') toast(active ? 'Battery saver on: ' + reason : 'Battery saver off');
		onChange.dispatch(active);
	}

	static function resolveReason(wasActive:Bool):SaverReason
	{
		switch (ClientPrefs.batterySaver)
		{
			case 'Off':
				return NONE;
			case 'On':
				return FORCED;
			default:
		}

		if (systemSaver) return SYSTEM;
		if (thermal >= 3) return HOT;

		final limit = ClientPrefs.batterySaverLevel + (wasActive ? hysteresis : 0);
		if (!charging && level >= 0 && level <= limit) return LOW_BATTERY;

		return NONE;
	}

	static function apply():Void
	{
		final gameplay = inGameplay();
		idle = ClientPrefs.batterySaver != 'Off' && !gameplay && now() - lastInput >= idleSeconds;

		var fps = ClientPrefs.unlockedFramerate ? 0 : ClientPrefs.framerate;
		if (active) fps = cap(fps, gameplay ? gameplayFps : menuFps);
		if (idle) fps = cap(fps, idleFps);

		final capped = active || idle;
		if (fps != appliedFps || (capped && FlxG.drawFramerate != fps))
		{
			appliedFps = fps;
			if (capped) setFps(fps);
			else ClientPrefs.changeFps(ClientPrefs.framerate);
		}

		if (active != appliedRefresh)
		{
			appliedRefresh = active;
			#if android
			Window.setPreferredRefreshRate(active ? gameplayFps : 0);
			#end
			funkin.mobile.ui.TouchCursor.trails = active ? false : savedTrails;
			funkin.mobile.ui.TouchCursor.ripples = active ? false : savedRipples;
			funkin.mobile.haptics.Haptics.lowPower = active;
		}

		final sustained = thermal >= 2;
		if (sustained != appliedSustained)
		{
			appliedSustained = sustained;
			#if android
			Window.setSustainedPerformance(sustained);
			#end
		}

		final keepOn = !active || gameplay;
		if (appliedKeepOn != keepOn)
		{
			appliedKeepOn = keepOn;
			#if android
			Window.keepScreenOn = keepOn;
			#else
			IOSScreen.keepAwake = keepOn;
			#end
		}
	}

	static function cap(fps:Int, limit:Int):Int
	{
		return fps <= 0 ? limit : Std.int(Math.min(fps, limit));
	}

	static function setFps(fps:Int):Void
	{
		if (fps > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = fps;
			FlxG.drawFramerate = fps;
		}
		else
		{
			FlxG.drawFramerate = fps;
			FlxG.updateFramerate = fps;
		}
	}

	static function inGameplay():Bool
	{
		final state = FlxG.state;
		return state != null && Std.isOfType(state, funkin.states.PlayState) && state.subState == null;
	}

	#if android
	static function onTrimMemory(level:androidmanager.callback.Callback.TrimMemoryLevel):Void
	{
		final value:Int = level;
		if (value >= 15 || (value >= 10 && active)) freeMemory(value >= 15);
	}
	#else
	static function onIOSEvent(event:String, data:Dynamic):Void
	{
		switch (event)
		{
			case 'memory_warning':
				freeMemory(true);
			case 'low_power_mode' | 'thermal_state' | 'battery_state':
				pollTimer = pollSeconds;
			default:
		}
	}
	#end

	static function freeMemory(full:Bool):Void
	{
		try
		{
			FunkinAssets.cache.clearUnusedMemory();
			#if cpp
			cpp.vm.Gc.run(full);
			#end
			funkin.mobile.android.logcat.LogcatUtil.info('Freed memory after a low memory warning');
		}
		catch (e:Dynamic) {}
	}

	static function toast(message:String):Void
	{
		try
		{
			#if android
			Interface.showToast(message);
			#else
			IOSToast.show(message);
			#end
		}
		catch (e:Dynamic) {}
	}
	#end
}
