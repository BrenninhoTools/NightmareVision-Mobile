package funkin.mobile;

import openfl.Assets;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

import flixel.FlxG;

class ExternalInput
{
	public static var active(default, null):Bool = false;

	public static var keyboard(default, null):Bool = false;

	public static var gamepad(default, null):Bool = false;

	public static var autoHide:Bool = true;

	public static var pollInterval:Float = 0.5;

	static var initialized:Bool = false;

	static var timer:Float = 0;

	static var banner:Null<ExternalInputBanner> = null;

	public static function init():Void
	{
		#if mobile
		if (initialized) return;
		initialized = true;

		FlxG.signals.postUpdate.add(update);

		lime.ui.Gamepad.onConnect.add((device) -> {
			device.onDisconnect.add(refresh);
			refresh();
		});

		for (device in lime.ui.Gamepad.devices)
			device.onDisconnect.add(refresh);

		refresh();
		#end
	}

	static function update():Void
	{
		timer += FlxG.elapsed;
		if (timer < pollInterval) return;

		timer = 0;
		refresh();
	}

	public static function refresh():Void
	{
		#if mobile
		final mask = NativeUtil.getExternalInput();

		var limeGamepad = false;
		for (device in lime.ui.Gamepad.devices)
		{
			if (device != null && device.connected)
			{
				limeGamepad = true;
				break;
			}
		}

		apply((mask & 1) != 0, (mask & 2) != 0 || limeGamepad);
		#end
	}

	static function apply(hasKeyboard:Bool, hasGamepad:Bool):Void
	{
		if (hasKeyboard == keyboard && hasGamepad == gamepad) return;

		final addedKeyboard = hasKeyboard && !keyboard;
		final addedGamepad = hasGamepad && !gamepad;
		final removedKeyboard = !hasKeyboard && keyboard;
		final removedGamepad = !hasGamepad && gamepad;

		keyboard = hasKeyboard;
		gamepad = hasGamepad;

		setActive(autoHide && (keyboard || gamepad));

		if (addedKeyboard || addedGamepad) notify(describe(addedKeyboard, addedGamepad) + ' Connected');
		else if (removedKeyboard || removedGamepad) notify(describe(removedKeyboard, removedGamepad) + ' Disconnected');
	}

	static function setActive(value:Bool):Void
	{
		if (active == value) return;

		if (value) TouchInput.releaseAll();
		active = value;
		TouchInput.enabled = !value;
	}

	static function describe(hasKeyboard:Bool, hasGamepad:Bool):String
	{
		return hasKeyboard && hasGamepad ? 'Keyboard/Gamepad' : (hasKeyboard ? 'Keyboard' : 'Gamepad');
	}

	public static function notify(message:String):Void
	{
		if (FlxG.game?.parent == null) return;

		if (banner == null)
		{
			banner = new ExternalInputBanner();
			FlxG.game.parent.addChild(banner);
		}
		else
		{
			FlxG.game.parent.setChildIndex(banner, FlxG.game.parent.numChildren - 1);
		}

		banner.show(message);
		TouchCursor.bringToFront();
	}
}

class ExternalInputBanner extends Sprite
{
	public static var holdTime:Float = 2.2;

	public static var slideTime:Float = 0.25;

	final background:Shape;

	final label:TextField;

	var elapsed:Float = 0;

	var running:Bool = false;

	var lastTime:Float = 0;

	public function new()
	{
		super();

		mouseEnabled = mouseChildren = false;

		background = new Shape();
		addChild(background);

		final font = Assets.exists('assets/fonts/aller.ttf') ? Assets.getFont('assets/fonts/aller.ttf').fontName : '_sans';
		final format = new TextFormat(font, 22, 0xFFFFFF, true);
		format.align = TextFormatAlign.CENTER;

		label = new TextField();
		label.selectable = false;
		label.mouseEnabled = false;
		label.defaultTextFormat = format;
		label.autoSize = TextFieldAutoSize.CENTER;
		label.multiline = false;
		addChild(label);

		visible = false;
	}

	public function show(message:String):Void
	{
		label.text = message;

		final width = label.textWidth + 48;
		final height = label.textHeight + 22;

		background.graphics.clear();
		background.graphics.beginFill(0x000000, 0.78);
		background.graphics.drawRoundRect(0, 0, width, height, 22, 22);
		background.graphics.endFill();
		background.graphics.lineStyle(2, 0xFFFFFF, 0.85);
		background.graphics.drawRoundRect(0, 0, width, height, 22, 22);

		label.x = (width - label.width) / 2;
		label.y = (height - label.height) / 2;

		elapsed = 0;
		lastTime = haxe.Timer.stamp();
		visible = true;
		alpha = 1;

		if (!running)
		{
			running = true;
			addEventListener(Event.ENTER_FRAME, onFrame);
		}

		layout(0);
	}

	function onFrame(_:Event):Void
	{
		final now = haxe.Timer.stamp();
		elapsed += now - lastTime;
		lastTime = now;

		final total = slideTime * 2 + holdTime;

		if (elapsed >= total)
		{
			visible = false;
			running = false;
			removeEventListener(Event.ENTER_FRAME, onFrame);
			return;
		}

		var progress = 1.0;
		if (elapsed < slideTime) progress = elapsed / slideTime;
		else if (elapsed > slideTime + holdTime) progress = 1 - (elapsed - slideTime - holdTime) / slideTime;

		layout(progress);
	}

	function layout(progress:Float):Void
	{
		final stage = this.stage;
		if (stage == null) return;

		final scale = Math.max(1, Math.min(stage.stageWidth / FlxG.width, stage.stageHeight / FlxG.height));
		scaleX = scaleY = scale;

		final eased = 1 - Math.pow(1 - Math.max(0, Math.min(1, progress)), 3);
		final bannerHeight = background.height * scale;

		x = (stage.stageWidth - background.width * scale) / 2;
		y = -bannerHeight + (bannerHeight + 16 * scale) * eased;
		alpha = Math.max(0, Math.min(1, progress * 1.4));
	}
}
