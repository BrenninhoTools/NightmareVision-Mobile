package funkin.mobile;

import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.ui.KeyLocation;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;

typedef VirtualKey =
{
	var label:String;
	var key:FlxKey;
	var ?charCode:Int;
	var ?toggle:Bool;
	var ?action:Void->Void;
}

class VirtualPadButton extends TouchButton
{
	public final key:VirtualKey;

	public var latched(default, null):Bool = false;

	public function new(x:Float, y:Float, size:Int, key:VirtualKey)
	{
		super(x, y, [], 3);

		this.key = key;
		blocksGestures = true;

		loadGraphic(createGraphic(size, key.label), false, 0, 0, true);
		alpha = VirtualPad.idleAlpha;

		onDown.add(press);
		onUp.add(release);
	}

	function press():Void
	{
		NativeUtil.vibrate(8);

		if (key.action != null)
		{
			key.action();
			flash();
			return;
		}

		if (key.toggle == true)
		{
			latched = !latched;
			VirtualPad.sendKey(key, latched);
			alpha = latched ? 1 : VirtualPad.idleAlpha;
			color = latched ? 0xFFFFE066 : FlxColor.WHITE;
			return;
		}

		VirtualPad.sendKey(key, true);
		alpha = 1;
		scale.set(0.92, 0.92);
	}

	function release():Void
	{
		if (key.action != null || key.toggle == true) return;

		VirtualPad.sendKey(key, false);
		alpha = VirtualPad.idleAlpha;
		scale.set(1, 1);
	}

	function flash():Void
	{
		alpha = 1;
		scale.set(0.92, 0.92);
		FlxTimer.wait(0.1, () -> {
			if (!exists) return;
			alpha = VirtualPad.idleAlpha;
			scale.set(1, 1);
		});
	}

	public function releaseAll():Void
	{
		if (key.action != null) return;

		if (latched || touchPressed) VirtualPad.sendKey(key, false);
		latched = false;
	}

	static function createGraphic(size:Int, label:String):BitmapData
	{
		final radius = size * 0.32;
		final shape = new Shape();
		final g = shape.graphics;

		g.beginFill(0x000000);
		g.drawRoundRect(0, 0, size, size, radius, radius);
		g.endFill();

		g.beginFill(0xFFFFFF);
		g.drawRoundRect(3, 3, size - 6, size - 6, radius * 0.9, radius * 0.9);
		g.endFill();

		g.beginFill(0x000000);
		g.drawRoundRect(10, 10, size - 20, size - 20, radius * 0.7, radius * 0.7);
		g.endFill();

		g.beginFill(0x1C1C1C);
		g.drawRoundRect(13, 13, size - 26, size - 26, radius * 0.6, radius * 0.6);
		g.endFill();

		final bitmap = new BitmapData(size, size, true, 0);
		bitmap.draw(shape);

		final fontSize = label.length <= 1 ? Std.int(size * 0.42) : Std.int(Math.min(size * 0.26, (size - 26) / (label.length * 0.62)));
		final text = new FlxText(0, 0, size, label, fontSize);
		text.setFormat(Paths.DEFAULT_FONT, fontSize, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.drawFrame(true);

		final pixels = text.pixels;
		if (pixels != null)
		{
			final matrix = new openfl.geom.Matrix();
			matrix.translate(0, Std.int((size - pixels.height) / 2));
			bitmap.draw(pixels, matrix, null, null, null, true);
		}

		text.destroy();

		return bitmap;
	}
}

class VirtualPad extends FlxTypedGroup<VirtualPadButton>
{
	public static var idleAlpha:Float = 0.55;

	public static var buttonSize:Int = 84;

	public static var margin:Float = 18;

	public static var gap:Float = 8;

	static var shiftDown:Bool = false;

	static var ctrlDown:Bool = false;

	public var shown(default, set):Bool = true;

	public final toggleButton:VirtualPadButton;

	final padCamera:FlxCamera;

	final blockedPointers:Map<Int, Bool> = [];

	var mouseBlocked:Bool = false;

	public function new(camera:FlxCamera, ?dpad:Array<VirtualKey>, ?actions:Array<Array<VirtualKey>>)
	{
		super();

		padCamera = camera;

		dpad ??= [
			{label: '^', key: UP},
			{label: '<', key: LEFT},
			{label: '>', key: RIGHT},
			{label: 'v', key: DOWN}
		];

		actions ??= [
			[
				{label: 'Q', key: Q, charCode: 'q'.code},
				{label: 'E', key: E, charCode: 'e'.code},
				{label: 'ENTER', key: ENTER, charCode: 13},
				{label: 'ESC', key: ESCAPE, charCode: 27}
			],
			[
				{label: 'SHIFT', key: SHIFT, toggle: true},
				{label: 'CTRL', key: CONTROL, toggle: true},
				{label: 'SPACE', key: SPACE, charCode: 32},
				{label: 'KB', key: NONE, action: toggleKeyboard}
			]
		];

		final size = buttonSize;
		final step = size + gap;
		final bottom = FlxG.height - margin - size;

		if (dpad.length >= 4)
		{
			addButton(margin + step, bottom - step * 2, dpad[0]);
			addButton(margin, bottom - step, dpad[1]);
			addButton(margin + step * 2, bottom - step, dpad[2]);
			addButton(margin + step, bottom, dpad[3]);
		}

		for (rowIndex => row in actions)
		{
			final y = bottom - step * (actions.length - 1 - rowIndex);
			for (columnIndex => key in row)
			{
				final x = FlxG.width - margin - size - step * (row.length - 1 - columnIndex);
				addButton(x, y, key);
			}
		}

		toggleButton = new VirtualPadButton(margin, margin, Std.int(size * 0.75), {label: 'PAD', key: NONE, action: () -> shown = !shown});
		toggleButton.cameras = [padCamera];
		add(toggleButton);

		FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 10000);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 10000);
		FlxG.stage.addEventListener(MouseEvent.CLICK, onMouseClick, false, 10000);
	}

	function addButton(x:Float, y:Float, key:VirtualKey):Void
	{
		final button = new VirtualPadButton(x, y, buttonSize, key);
		button.cameras = [padCamera];
		add(button);
	}

	function set_shown(value:Bool):Bool
	{
		shown = value;

		for (button in members)
		{
			if (button == null || button == toggleButton) continue;

			if (!value) button.releaseAll();
			button.visible = value;
		}

		return value;
	}

	function toggleKeyboard():Void
	{
		final window = lime.app.Application.current?.window;
		if (window != null && window.textInputEnabled) NativeUtil.hideKeyboard();
		else NativeUtil.showKeyboard();
	}

	function hitsButton(stageX:Float, stageY:Float):Bool
	{
		final scale = FlxG.scaleMode.scale;
		final gameX = (stageX - FlxG.game.x) / scale.x;
		final gameY = (stageY - FlxG.game.y) / scale.y;
		final viewX = (gameX - padCamera.x) / padCamera.zoom + padCamera.viewMarginX;
		final viewY = (gameY - padCamera.y) / padCamera.zoom + padCamera.viewMarginY;

		for (button in members)
		{
			if (button == null || !button.visible || !button.exists) continue;
			if (viewX >= button.x && viewX < button.x + button.width && viewY >= button.y && viewY < button.y + button.height) return true;
		}

		return false;
	}

	function onMouseDown(event:MouseEvent):Void
	{
		mouseBlocked = hitsButton(event.stageX, event.stageY);
		if (mouseBlocked) event.stopImmediatePropagation();
	}

	function onMouseUp(event:MouseEvent):Void
	{
		if (!mouseBlocked) return;
		event.stopImmediatePropagation();
	}

	function onMouseClick(event:MouseEvent):Void
	{
		if (!mouseBlocked) return;
		mouseBlocked = false;
		event.stopImmediatePropagation();
	}

	public static function sendKey(key:VirtualKey, down:Bool):Void
	{
		final stage = FlxG.stage;
		if (stage == null || key.key == NONE) return;

		if (key.key == SHIFT) shiftDown = down;
		if (key.key == CONTROL) ctrlDown = down;

		final type = down ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP;
		stage.dispatchEvent(new KeyboardEvent(type, true, false, key.charCode ?? 0, key.key, KeyLocation.STANDARD, ctrlDown, false, shiftDown));
	}

	override function destroy():Void
	{
		for (button in members)
			if (button != null) button.releaseAll();

		shiftDown = ctrlDown = false;

		FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		FlxG.stage.removeEventListener(MouseEvent.CLICK, onMouseClick);

		super.destroy();
	}
}
