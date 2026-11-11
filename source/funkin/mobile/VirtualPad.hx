package funkin.mobile;

import funkin.mobile.input.TouchButton;
import funkin.mobile.util.Hitbox;

import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.ui.KeyLocation;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;

typedef VirtualKey =
{
	var label:String;
	var ?image:String;
	var key:FlxKey;
	var ?charCode:Int;
	var ?toggle:Bool;
	var ?action:Void->Void;
	var ?repeat:Bool;
	var ?color:FlxColor;
}

typedef VirtualPadLayout =
{
	var ?dpadRow:Bool;
	var ?columns:Int;
	var ?rightLimit:Float;
	var ?bottomLimit:Float;
}

class VirtualPadButton extends TouchButton
{
	public final key:VirtualKey;

	public var latched(default, null):Bool = false;

	public var group:String = 'actions';

	var holdTimer:Float = 0;

	var repeatTimer:Float = 0;

	var animated:Bool = false;

	public function new(x:Float, y:Float, size:Int, key:VirtualKey)
	{
		super(x, y, [], 3);

		this.key = key;
		blocksGestures = true;

		final graphic = key.image != null ? VirtualPad.getStateGraphic(key.image) : null;

		if (graphic != null)
		{
			loadGraphic(graphic, true, VirtualPad.STATE_WIDTH, VirtualPad.STATE_HEIGHT);
			animation.add('idle', [0], 0, false);
			animation.add('latched', [1], 0, false);
			animation.add('pressed', [2], 0, false);
			animation.play('idle');
			animated = true;
			setGraphicSize(size, Std.int(size * VirtualPad.STATE_HEIGHT / VirtualPad.STATE_WIDTH));
			color = key.color ?? VirtualPad.colorFor(key);
		}
		else
		{
			loadGraphic(createGraphic(size, key.label), false, 0, 0, true);
		}

		updateHitbox();
		alpha = VirtualPad.idleAlpha;

		onDown.add(press);
		onUp.add(release);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!touchPressed || key.action != null || key.toggle == true || key.repeat == false) return;

		holdTimer += elapsed;
		if (holdTimer < VirtualPad.repeatDelay) return;

		repeatTimer += elapsed;
		while (repeatTimer >= VirtualPad.repeatInterval)
		{
			repeatTimer -= VirtualPad.repeatInterval;
			VirtualPad.sendKey(key, true);
		}
	}

	function show(state:String):Void
	{
		if (animated) animation.play(state);

		alpha = state == 'idle' ? VirtualPad.idleAlpha : 1;
	}

	function press():Void
	{
		holdTimer = repeatTimer = 0;

		if (key.action != null)
		{
			key.action();
			show('pressed');
			return;
		}

		if (key.toggle == true)
		{
			setLatched(!latched);
			return;
		}

		VirtualPad.sendKey(key, true);
		show('pressed');
	}

	function release():Void
	{
		if (key.toggle == true)
		{
			show(latched ? 'latched' : 'idle');
			return;
		}

		if (key.action == null) VirtualPad.sendKey(key, false);
		show('idle');
	}

	public function setLatched(value:Bool, notify:Bool = true):Void
	{
		latched = value;
		if (notify && key.key != NONE) VirtualPad.sendKey(key, latched);
		show(latched ? 'latched' : 'idle');
		if (!animated) color = latched ? 0xFFFFE066 : FlxColor.WHITE;
	}

	public function releaseAll():Void
	{
		if (key.action != null) return;

		if (latched || touchPressed) VirtualPad.sendKey(key, false);
		latched = false;
		if (!animated) color = FlxColor.WHITE;
		show('idle');
	}

	public static var keyColor:FlxColor = 0xFF3B3B52;

	static function createGraphic(size:Int, label:String):BitmapData
	{
		final radius = size * 0.28;
		final shape = new Shape();
		final g = shape.graphics;

		var dark:FlxColor = keyColor;
		dark.brightness *= 0.5;

		g.beginFill(dark.rgb, 0.92);
		g.drawRoundRect(0, 0, size, size, radius, radius);
		g.endFill();

		g.beginFill(keyColor.rgb, 0.85);
		g.drawRoundRect(5, 5, size - 10, size - 10, radius * 0.85, radius * 0.85);
		g.endFill();

		final bitmap = new BitmapData(size, size, true, 0);
		bitmap.draw(shape);

		final fontSize = label.length <= 1 ? Std.int(size * 0.44) : Std.int(Math.min(size * 0.27, (size - 22) / (label.length * 0.62)));
		final text = new FlxText(0, 0, size, label, fontSize);
		text.setFormat(Paths.DEFAULT_FONT, fontSize, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
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
	public static inline final ATLAS:String = 'mobile/virtualpad';

	public static inline final STATE_WIDTH:Int = 132;

	public static inline final STATE_HEIGHT:Int = 127;

	public static var idleAlpha:Float = 0.6;

	public static var buttonSize:Int = 96;

	public static var gap:Float = 6;

	public static var repeatDelay:Float = 0.35;

	public static var repeatInterval:Float = 0.05;

	public static final LETTER_COLORS:Map<String, FlxColor> = [
		'a' => 0xFF4CD964,
		'b' => 0xFFFF4D4D,
		'c' => 0xFF44C4FF,
		'd' => 0xFFFF9F3A,
		'e' => 0xFFB57BFF,
		'f' => 0xFFFF66B2,
		'g' => 0xFF66E0C8,
		's' => 0xFFFFD84D,
		'v' => 0xFF8FA8FF,
		'x' => 0xFFFF7070,
		'y' => 0xFFFFE066,
		'z' => 0xFF7CFF8F
	];

	static var shiftDown:Bool = false;

	static var ctrlDown:Bool = false;

	static var altDown:Bool = false;

	static var atlas:Null<FlxAtlasFrames> = null;

	static final stateGraphics:Map<String, FlxGraphic> = [];

	public static final DEFAULT_DPAD:Array<VirtualKey> = [
		{label: '<', image: 'left', key: LEFT},
		{label: 'v', image: 'down', key: DOWN},
		{label: '^', image: 'up', key: UP},
		{label: '>', image: 'right', key: RIGHT}
	];

	public static final DEFAULT_ACTIONS:Array<Array<VirtualKey>> = [
		[letter('a', ENTER, 13), letter('v', SPACE, 32), letter('z', Z), letter('x', X)],
		[toggleKey('s', SHIFT), toggleKey('c', CONTROL)]
	];

	public var shown(default, set):Bool = true;

	public var page(default, null):Int = 0;

	public final dpadButtons:Array<VirtualPadButton> = [];

	public final actionButtons:Array<VirtualPadButton> = [];

	final padCamera:FlxCamera;

	final pages:Array<Array<Array<VirtualKey>>>;

	final pageButtons:Array<Array<VirtualPadButton>> = [];

	var mouseBlocked:Bool = false;

	public static function letter(image:String, key:FlxKey, ?charCode:Int):VirtualKey
	{
		return {label: image.toUpperCase(), image: image, key: key, charCode: charCode ?? image.charCodeAt(0)};
	}

	public static function toggleKey(image:String, key:FlxKey):VirtualKey
	{
		return {label: image.toUpperCase(), image: image, key: key, toggle: true};
	}

	public static function colorFor(key:VirtualKey):FlxColor
	{
		return switch (key.image)
		{
			case 'left': Hitbox.COLORS[0];
			case 'down': Hitbox.COLORS[1];
			case 'up': Hitbox.COLORS[2];
			case 'right': Hitbox.COLORS[3];
			default: LETTER_COLORS.get(key.image) ?? FlxColor.WHITE;
		}
	}

	public static function getStateGraphic(name:String):Null<FlxGraphic>
	{
		final cached = stateGraphics.get(name);
		if (cached != null && cached.bitmap != null) return cached;

		if (atlas == null)
		{
			try
			{
				atlas = Paths.getSparrowAtlas(ATLAS, null, false);
			}
			catch (e:Dynamic)
			{
				atlas = null;
			}
			if (atlas == null) return null;
			atlas.parent.persist = true;
			atlas.parent.destroyOnNoUse = false;
		}

		final frame = atlas.getByName(name);
		if (frame == null || atlas.parent.bitmap == null) return null;

		final source = atlas.parent.bitmap;
		final width = STATE_WIDTH * 3;
		final bitmap = new BitmapData(width, STATE_HEIGHT, true, 0);
		bitmap.copyPixels(source, new Rectangle(frame.frame.x, frame.frame.y, Math.min(width, frame.frame.width), Math.min(STATE_HEIGHT, frame.frame.height)), new Point(0, 0));

		final graphic = FlxGraphic.fromBitmapData(bitmap, false, 'virtualpad-' + name, false);
		graphic.persist = true;
		graphic.destroyOnNoUse = false;
		stateGraphics.set(name, graphic);
		return graphic;
	}

	public function new(camera:FlxCamera, ?dpad:Array<VirtualKey>, ?actions:Array<Array<VirtualKey>>, ?pages:Array<Array<Array<VirtualKey>>>, ?layout:VirtualPadLayout)
	{
		super();

		padCamera = camera;

		dpad ??= DEFAULT_DPAD;
		this.pages = pages ?? [actions ?? DEFAULT_ACTIONS];

		final size = buttonSize;
		final height = Std.int(size * STATE_HEIGHT / STATE_WIDTH);
		final stepX = size + gap;
		final stepY = height + gap;
		final bottom = MobileUtil.bottomEdge() - height;
		final left = MobileUtil.leftEdge();
		final right = layout?.rightLimit ?? MobileUtil.rightEdge();
		final actionBottom = layout?.bottomLimit != null ? layout.bottomLimit - height : bottom;
		final columns = layout?.columns ?? 0;

		if (dpad.length >= 4)
		{
			final positions = layout?.dpadRow == true ? [for (index in 0...4) [left + stepX * index, bottom]] : [[left, bottom - stepY], [left + stepX, bottom], [left + stepX, bottom - stepY * 2], [left + stepX * 2, bottom - stepY]];
			for (index in 0...4)
			{
				final button = addButton(positions[index][0], positions[index][1], dpad[index], 'dpad', size);
				dpadButtons.push(button);
			}
		}

		for (rows in this.pages)
		{
			final buttons:Array<VirtualPadButton> = [];

			if (columns > 0)
			{
				final entries = [for (row in rows) for (entry in row) entry];
				final rowCount = Math.ceil(entries.length / columns);

				for (index => entry in entries)
				{
					final row = Std.int(index / columns);
					final column = index % columns;
					final x = right - size - stepX * (columns - 1 - column);
					final y = actionBottom - stepY * (rowCount - 1 - row);
					final button = addButton(x, y, entry, 'actions', size);
					buttons.push(button);
					actionButtons.push(button);
				}
			}
			else
			{
				for (rowIndex => row in rows)
				{
					final y = actionBottom - stepY * (rows.length - 1 - rowIndex);
					for (columnIndex => entry in row)
					{
						final x = right - size - stepX * (row.length - 1 - columnIndex);
						final button = addButton(x, y, entry, 'actions', size);
						buttons.push(button);
						actionButtons.push(button);
					}
				}
			}

			pageButtons.push(buttons);
		}

		setPage(0);

		FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 10000);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 10000);
		FlxG.stage.addEventListener(MouseEvent.CLICK, onMouseClick, false, 10000);
	}

	function addButton(x:Float, y:Float, entry:VirtualKey, group:String, size:Int):VirtualPadButton
	{
		final button = new VirtualPadButton(x, y, size, entry);
		button.cameras = [padCamera];
		button.group = group;
		add(button);
		return button;
	}

	public var suspended(default, set):Bool = false;

	function set_suspended(value:Bool):Bool
	{
		suspended = value;

		for (button in members)
		{
			if (button == null) continue;

			if (value)
			{
				if (button.key.toggle != true) button.releaseAll();
				button.visible = false;
				button.touchEnabled = false;
			}
			else
			{
				button.touchEnabled = true;
			}
		}

		if (!value) shown = shown;

		return value;
	}

	public function setPage(index:Int):Void
	{
		page = pages.length > 0 ? FlxMath.wrap(index, 0, pages.length - 1) : 0;

		for (pageIndex => buttons in pageButtons)
		{
			for (button in buttons)
			{
				final active = shown && !suspended && pageIndex == page;
				if (!active && button.touchPressed) button.releaseAll();
				button.visible = active;
			}
		}
	}

	function set_shown(value:Bool):Bool
	{
		shown = value;

		for (button in dpadButtons)
		{
			if (!value) button.releaseAll();
			button.visible = value && !suspended;
		}

		setPage(page);

		return value;
	}

	public function hitsButton(stageX:Float, stageY:Float):Bool
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
		if (mouseBlocked) event.stopImmediatePropagation();
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
		if (key.key == ALT) altDown = down;

		var charCode = key.charCode ?? 0;
		if (shiftDown && charCode >= 'a'.code && charCode <= 'z'.code) charCode -= 32;

		final type = down ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP;
		stage.dispatchEvent(new KeyboardEvent(type, true, false, charCode, key.key, KeyLocation.STANDARD, ctrlDown, altDown, shiftDown));
	}

	override function destroy():Void
	{
		for (button in members)
			if (button != null) button.releaseAll();

		shiftDown = ctrlDown = altDown = false;

		FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		FlxG.stage.removeEventListener(MouseEvent.CLICK, onMouseClick);

		super.destroy();
	}
}
