package funkin.mobile.android.util;

#if android
import androidmanager.content.Interface;
import androidmanager.view.Screenshot;
#end

import funkin.mobile.haptics.Haptics;
import funkin.mobile.input.ExternalInput;
import funkin.mobile.ui.TouchCursor;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;

import flixel.FlxG;

class ScreenshotUtil extends Sprite
{
	public static inline final ICON:String = 'mobile/screenshotButton';

	public static var album:String = 'NightmareVision';

	public static var buttonSize:Float = 0.11;

	public static var margin:Float = 0.025;

	public static var idleAlpha:Float = 0.55;

	public static var holdTime:Float = 0.6;

	public static var hideFrames:Int = 2;

	public static var instance(default, null):Null<ScreenshotUtil> = null;

	public static var busy(default, null):Bool = false;

	public static var lastPath(default, null):Null<String> = null;

	final button:Sprite;

	final flash:Shape;

	var icon:Null<Bitmap> = null;

	var pressId:Int = -2;

	var pressTime:Float = 0;

	var held:Bool = false;

	var pendingShare:Bool = false;

	var waitFrames:Int = -1;

	var flashAlpha:Float = 0;

	var lastTime:Float = 0;

	var lastWidth:Int = 0;

	var lastHeight:Int = 0;

	public static function init():Void
	{
		#if android
		if (instance != null || FlxG.game?.parent == null) return;

		instance = new ScreenshotUtil();
		FlxG.game.parent.addChild(instance);
		TouchCursor.bringToFront();
		#end
	}

	public static function take(share:Bool = false):Void
	{
		#if android
		if (instance == null || busy) return;
		instance.begin(share);
		#end
	}

	public function new()
	{
		super();

		button = new Sprite();
		button.mouseChildren = false;
		addChild(button);

		flash = new Shape();
		flash.visible = false;
		addChild(flash);

		mouseEnabled = false;
		visible = false;

		button.addEventListener(TouchEvent.TOUCH_BEGIN, onPress);
		button.addEventListener(MouseEvent.MOUSE_DOWN, block);
		button.addEventListener(MouseEvent.MOUSE_UP, block);
		button.addEventListener(MouseEvent.CLICK, block);
		addEventListener(Event.ADDED_TO_STAGE, onAdded);
	}

	function onAdded(_:Event):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAdded);
		stage.addEventListener(TouchEvent.TOUCH_END, onRelease, false, 20001);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onMove, false, 20001);
		addEventListener(Event.ENTER_FRAME, onFrame);
		lastTime = haxe.Timer.stamp();
	}

	function block(event:MouseEvent):Void
	{
		event.stopImmediatePropagation();
	}

	function onPress(event:TouchEvent):Void
	{
		event.stopImmediatePropagation();
		if (busy || pressId != -2) return;

		pressId = event.touchPointID;
		pressTime = haxe.Timer.stamp();
		held = false;
		button.alpha = 1;
		button.scaleX = button.scaleY = 0.9;
		Haptics.select();
	}

	function onMove(event:TouchEvent):Void
	{
		if (event.touchPointID == pressId) event.stopImmediatePropagation();
	}

	function onRelease(event:TouchEvent):Void
	{
		if (event.touchPointID != pressId) return;
		event.stopImmediatePropagation();

		pressId = -2;
		restoreButton();

		if (held) return;
		if (button.hitTestPoint(event.stageX, event.stageY)) begin(false);
	}

	function restoreButton():Void
	{
		button.scaleX = button.scaleY = 1;
		button.alpha = idleAlpha;
		layout(true);
	}

	function onFrame(_:Event):Void
	{
		final now = haxe.Timer.stamp();
		final elapsed = Math.min(0.1, now - lastTime);
		lastTime = now;

		final enabled = ClientPrefs.screenshotButton && !ExternalInput.active;
		if (!busy) visible = enabled;

		if (enabled && icon == null) loadIcon();
		layout(false);

		if (pressId != -2 && !held && now - pressTime >= holdTime)
		{
			held = true;
			Haptics.impact(0.8, 0.5);
			begin(true);
		}

		if (waitFrames >= 0 && waitFrames-- == 0) capture();

		if (flashAlpha > 0)
		{
			flashAlpha = Math.max(0, flashAlpha - elapsed * 3);
			flash.alpha = flashAlpha;
			flash.visible = flashAlpha > 0;
		}
	}

	function loadIcon():Void
	{
		try
		{
			final graphic = Paths.image(ICON);
			if (graphic == null || graphic.bitmap == null) return;

			final bitmap = new Bitmap(graphic.bitmap.clone(), AUTO, true);
			icon = bitmap;
			button.addChild(bitmap);
			button.alpha = idleAlpha;
			layout(true);
		}
		catch (e:Dynamic) {}
	}

	function layout(force:Bool):Void
	{
		if (stage == null || icon == null) return;

		final width = stage.stageWidth;
		final height = stage.stageHeight;
		if (!force && width == lastWidth && height == lastHeight) return;
		lastWidth = width;
		lastHeight = height;

		final source = icon.bitmapData;
		final size = Math.min(width, height) * buttonSize * 1.6;
		final ratio = size / Math.max(source.width, source.height);
		final pressed = button.scaleX;

		icon.scaleX = icon.scaleY = ratio;
		icon.x = -source.width * ratio / 2;
		icon.y = -source.height * ratio / 2;

		final unit = Math.min(width / FlxG.width, height / FlxG.height);
		final gap = Math.min(width, height) * margin;
		final right = width - funkin.mobile.ui.ScreenStyle.safeRight * unit;
		final top = funkin.mobile.ui.ScreenStyle.safeTop * unit;
		button.x = right - gap - source.width * ratio / 2;
		button.y = top + gap + source.height * ratio / 2;
		button.scaleX = button.scaleY = pressed;

		flash.graphics.clear();
		flash.graphics.beginFill(0xFFFFFF);
		flash.graphics.drawRect(0, 0, width, height);
		flash.graphics.endFill();
	}

	function begin(share:Bool):Void
	{
		#if android
		if (busy) return;

		busy = true;
		pendingShare = share;
		visible = false;
		TouchCursor.hidden = true;
		waitFrames = hideFrames;
		#end
	}

	function capture():Void
	{
		#if android
		try
		{
			if (pendingShare)
			{
				Screenshot.share({format: PNG, sound: true}, {title: 'Share screenshot'}, (result) -> finish(result.started, null, result.error));
				return;
			}

			Screenshot.capture(null, {format: PNG, gallery: true, album: album, sound: true}, (result, ?error) -> {
				finish(result != null, result != null ? (result.uri ?? result.path) : null, error);
			});
		}
		catch (e:Dynamic)
		{
			finish(false, null, Std.string(e));
		}
		#end
	}

	function finish(success:Bool, path:Null<String>, error:Null<String>):Void
	{
		busy = false;
		TouchCursor.hidden = false;
		visible = ClientPrefs.screenshotButton && !ExternalInput.active;

		if (!success)
		{
			Haptics.denied();
			toast('Screenshot failed' + (error != null && error.length > 0 ? ': ' + error : ''));
			funkin.mobile.android.logcat.LogcatUtil.warn('Screenshot failed: ' + error);
			return;
		}

		lastPath = path;
		flashAlpha = 0.8;
		flash.alpha = flashAlpha;
		flash.visible = true;
		Haptics.confirm();
		if (!pendingShare) toast('Screenshot saved to the gallery');
	}

	static function toast(message:String):Void
	{
		#if android
		try
		{
			Interface.showToast(message);
		}
		catch (e:Dynamic) {}
		#end
	}
}
