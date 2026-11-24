package funkin.mobile.util;

#if android
import androidmanager.os.Tablet;
#end

import funkin.mobile.input.ExternalInput;
import funkin.mobile.input.TouchInput;
import funkin.mobile.VirtualPad;

import flixel.FlxG;
import flixel.util.FlxSignal;

class DeviceProfile
{
	public static var formFactor(default, null):String = 'phone';

	public static var tablet(default, null):Bool = false;

	public static var foldable(default, null):Bool = false;

	public static var desktop(default, null):Bool = false;

	public static var diagonalInches(default, null):Float = 0;

	public static var widthClass(default, null):String = 'compact';

	public static var posture(default, null):String = 'unknown';

	public static var tabletButtonMm:Float = 13;

	public static var phoneButtonSize:Int = 96;

	public static final onChange:FlxSignal = new FlxSignal();

	static var pixelsPerMm:Float = 0;

	static var initialized:Bool = false;

	public static function init():Void
	{
		#if mobile
		if (initialized) return;
		initialized = true;

		#if android
		try
		{
			Tablet.onChange.add(apply);
			Tablet.onKeyboardChange.add(onKeyboardChange);
			Tablet.onPostureChange.add(onPostureChange);
			Tablet.startListening();

			final info = Tablet.info;
			if (info != null) apply(info);
		}
		catch (e:Dynamic) {}
		#elseif ios
		final model = lime.system.System.deviceModel ?? '';
		tablet = model.indexOf('iPad') != -1;
		formFactor = tablet ? 'tablet' : 'phone';
		widthClass = tablet ? 'expanded' : 'compact';
		refresh();
		#end
		#end
	}

	#if android
	static function onKeyboardChange(_:Bool):Void
	{
		ExternalInput.refresh();
	}

	static function onPostureChange(value:Posture, _:Float):Void
	{
		posture = value;
		onChange.dispatch();
	}

	static function apply(info:ScreenInfo):Void
	{
		formFactor = info.formFactor;
		foldable = info.foldable;
		desktop = info.desktop;
		diagonalInches = info.diagonalInches;
		widthClass = info.widthClass;
		posture = info.posture;
		tablet = info.largeScreen || formFactor == 'tablet' || formFactor == 'desktop';

		final dpi = (info.xdpi + info.ydpi) / 2;
		pixelsPerMm = dpi >= 60 && dpi <= 1200 ? dpi / 25.4 : info.densityDpi / 25.4;

		refresh();
	}
	#end

	static function refresh():Void
	{
		VirtualPad.buttonSize = tablet ? Std.int(Math.max(64, Math.min(phoneButtonSize, millimetersToGame(tabletButtonMm)))) : phoneButtonSize;
		TouchInput.calibrate();
		onChange.dispatch();
	}

	public static function millimetersToScreen(millimeters:Float):Float
	{
		if (pixelsPerMm > 0) return millimeters * pixelsPerMm;

		try
		{
			final display = lime.system.System.getDisplay(0);
			if (display != null && display.dpi > 0) return millimeters * display.dpi / 25.4;
		}
		catch (e:Dynamic) {}

		return millimeters * 160 / 25.4;
	}

	public static function millimetersToGame(millimeters:Float):Float
	{
		final scale = FlxG.scaleMode != null ? FlxG.scaleMode.scale : null;
		final ratio = scale != null && scale.x > 0 ? scale.x : 1;
		return millimetersToScreen(millimeters) / ratio;
	}
}
