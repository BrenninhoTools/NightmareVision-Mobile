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
import flixel.math.FlxPoint;
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
}

class VirtualPadButton extends TouchButton
{
	public final key:VirtualKey;

	public var latched(default, null):Bool = false;

	public var group:String = 'actions';

	public var page:Int = -1;

	var baseScale:Float = 1;

	var holdTimer:Float = 0;

	var repeatTimer:Float = 0;

	public function new(x:Float, y:Float, size:Int, key:VirtualKey)
	{
		super(x, y, [], 3);

		this.key = key;
		blocksGestures = true;

		final path = key.image != null ? 'images/mobile/virtualpad/${key.image}.png' : null;

		if (path != null && Paths.fileExists(path))
		{
			loadGraphic(Paths.image('mobile/virtualpad/${key.image}'));
			setGraphicSize(size, size);
		}
		else
		{
			loadGraphic(createGraphic(size, key.label), false, 0, 0, true);
		}

		updateHitbox();
		baseScale = scale.x;
		alpha = VirtualPad.idleAlpha;

		onDown.add(press);
		onUp.add(release);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!touchPressed || key.action != null || key.toggle == true || key.repeat == false || VirtualPad.moveMode) return;

		holdTimer += elapsed;
		if (holdTimer < VirtualPad.repeatDelay) return;

		repeatTimer += elapsed;
		while (repeatTimer >= VirtualPad.repeatInterval)
		{
			repeatTimer -= VirtualPad.repeatInterval;
			VirtualPad.sendKey(key, true);
		}
	}

	function press():Void
	{
		holdTimer = repeatTimer = 0;

		if (VirtualPad.moveMode && key.action == null) return;

		if (key.action != null)
		{
			key.action();
			flash();
			return;
		}

		if (key.toggle == true)
		{
			setLatched(!latched);
			return;
		}

		VirtualPad.sendKey(key, true);
		alpha = 1;
		scale.set(baseScale * 0.9, baseScale * 0.9);
	}

	function release():Void
	{
		if (key.action != null || key.toggle == true) return;

		if (!VirtualPad.moveMode) VirtualPad.sendKey(key, false);
		alpha = VirtualPad.idleAlpha;
		scale.set(baseScale, baseScale);
	}

	public function setLatched(value:Bool, notify:Bool = true):Void
	{
		latched = value;
		if (notify && key.key != NONE) VirtualPad.sendKey(key, latched);
		alpha = latched ? 1 : VirtualPad.idleAlpha;
		color = latched ? 0xFFFFE066 : FlxColor.WHITE;
	}

	function flash():Void
	{
		alpha = 1;
		scale.set(baseScale * 0.9, baseScale * 0.9);
		FlxTimer.wait(0.1, () -> {
			if (!exists) return;
			alpha = latched ? 1 : VirtualPad.idleAlpha;
			scale.set(baseScale, baseScale);
		});
	}

	public function releaseAll():Void
	{
		if (key.action != null) return;

		if (latched || touchPressed) VirtualPad.sendKey(key, false);
		latched = false;
		color = FlxColor.WHITE;
		alpha = VirtualPad.idleAlpha;
		scale.set(baseScale, baseScale);
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

	public static var repeatDelay:Float = 0.35;

	public static var repeatInterval:Float = 0.05;

	public static var moveMode(default, null):Bool = false;

	public static var mouseMode(default, null):Int = 0;

	public static var rightClickMode(get, never):Bool;

	static inline function get_rightClickMode():Bool return mouseMode == 1;

	static var shiftDown:Bool = false;

	static var ctrlDown:Bool = false;

	static var altDown:Bool = false;

	static final offsets:Map<String, FlxPoint> = [];

	public static final DEFAULT_PAGES:Array<Array<Array<VirtualKey>>> = [
		[
			[key('Q', 'q', Q), key('E', 'e', E), {label: 'ENTER', image: 'enter', key: ENTER, charCode: 13}, {label: 'ESC', image: 'esc', key: ESCAPE, charCode: 27}],
			[{label: 'SHIFT', image: 'shift', key: SHIFT, toggle: true}, {label: 'CTRL', image: 'ctrl', key: CONTROL, toggle: true}, {label: 'SPACE', image: 'space', key: SPACE, charCode: 32}]
		],
		[
			[key('Z', 'z', Z), key('X', 'x', X), key('C', 'c', C), key('V', 'v', V)],
			[key('A', 'a', A), key('S', 's', S), key('D', 'd', D), key('W', 'w', W)]
		],
		[
			[key('I', 'i', I), key('J', 'j', J), key('K', 'k', K), key('L', 'l', L)],
			[key('R', 'r', R), key('F', 'f', F), key('T', 't', T), key('G', 'g', G)]
		],
		[
			[key('1', 'one', ONE), key('2', 'two', TWO), key('3', 'three', THREE), key('4', 'four', FOUR)],
			[{label: '-', image: 'minus', key: MINUS, charCode: '-'.code}, {label: '+', image: 'plus', key: PLUS, charCode: '+'.code}, {label: 'TAB', image: 'tab', key: TAB, charCode: 9},
				{label: 'ALT', image: 'alt', key: ALT, toggle: true}],
			[{label: 'DEL', image: 'del', key: DELETE, charCode: 127}, {label: 'BKSP', image: 'bksp', key: BACKSPACE, charCode: 8}]
		]
	];

	public var shown(default, set):Bool = true;

	public var page(default, null):Int = 0;

	public final toolbar:Array<VirtualPadButton> = [];

	public final pageLabel:FlxText;

	final padCamera:FlxCamera;

	final pages:Array<Array<Array<VirtualKey>>>;

	final pageButtons:Array<Array<VirtualPadButton>> = [];

	final dpadButtons:Array<VirtualPadButton> = [];

	var mouseBlocked:Bool = false;

	var redirectedDown:Bool = false;

	var dragButton:Null<VirtualPadButton> = null;

	var dragLast:FlxPoint = FlxPoint.get();

	public static inline function key(label:String, image:String, key:FlxKey):VirtualKey
	{
		return {label: label, image: image, key: key, charCode: label.toLowerCase().charCodeAt(0)};
	}

	public function new(camera:FlxCamera, ?dpad:Array<VirtualKey>, ?actions:Array<Array<VirtualKey>>, ?pages:Array<Array<Array<VirtualKey>>>)
	{
		super();

		padCamera = camera;

		dpad ??= [
			{label: '^', image: 'up', key: UP},
			{label: '<', image: 'left', key: LEFT},
			{label: '>', image: 'right', key: RIGHT},
			{label: 'v', image: 'down', key: DOWN}
		];

		this.pages = pages ?? (actions != null ? [actions] : DEFAULT_PAGES);

		loadOffsets();

		final size = buttonSize;
		final step = size + gap;
		final bottom = FlxG.height - margin - size - ScreenStyle.safeBottom;
		final left = margin + ScreenStyle.safeLeft;
		final right = FlxG.width - margin - ScreenStyle.safeRight;

		if (dpad.length >= 4)
		{
			final positions = [[left + step, bottom - step * 2], [left, bottom - step], [left + step * 2, bottom - step], [left + step, bottom]];
			for (index in 0...4)
				dpadButtons.push(addButton(positions[index][0], positions[index][1], dpad[index], 'dpad', -1, size));
		}

		for (pageIndex => rows in this.pages)
		{
			final buttons:Array<VirtualPadButton> = [];

			for (rowIndex => row in rows)
			{
				final y = bottom - step * (rows.length - 1 - rowIndex);
				for (columnIndex => entry in row)
				{
					final x = right - size - step * (row.length - 1 - columnIndex);
					buttons.push(addButton(x, y, entry, 'actions', pageIndex, size));
				}
			}

			pageButtons.push(buttons);
		}

		final small = Std.int(size * 0.75);
		final top = margin + ScreenStyle.safeTop;
		final tools:Array<VirtualKey> = [
			{label: 'PAD', image: 'pad', key: NONE, action: () -> shown = !shown},
			{label: 'PAGE', image: 'page', key: NONE, action: () -> setPage(page + 1)},
			{label: 'RMB', image: 'rmb', key: NONE, action: cycleMouseMode},
			{label: 'KB', image: 'kb', key: NONE, action: toggleKeyboard},
			{label: 'MOVE', image: 'move', key: NONE, action: toggleMove}
		];

		for (index => tool in tools)
		{
			final button = new VirtualPadButton(left + (small + gap) * index, top, small, tool);
			button.cameras = [padCamera];
			button.group = 'toolbar';
			toolbar.push(button);
			add(button);
		}

		pageLabel = new FlxText(left + (small + gap) * tools.length + 4, top + small / 2 - 12, 0, '', 20);
		pageLabel.setFormat(Paths.DEFAULT_FONT, 20, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		pageLabel.cameras = [padCamera];

		applyOffsets();
		setPage(0);

		FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 10000);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 10000);
		FlxG.stage.addEventListener(MouseEvent.CLICK, onMouseClick, false, 10000);
	}

	function addButton(x:Float, y:Float, entry:VirtualKey, group:String, pageIndex:Int, size:Int):VirtualPadButton
	{
		final button = new VirtualPadButton(x, y, size, entry);
		button.cameras = [padCamera];
		button.group = group;
		button.page = pageIndex;
		add(button);
		return button;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (moveMode) updateDrag();
	}

	override function draw():Void
	{
		super.draw();

		if (shown && pageLabel.visible) pageLabel.draw();
	}

	public var suspended(default, set):Bool = false;

	function set_suspended(value:Bool):Bool
	{
		suspended = value;

		if (value)
		{
			for (button in members)
			{
				if (button == null) continue;
				if (button.key.toggle != true) button.releaseAll();
				button.visible = false;
				button.touchEnabled = false;
			}
			pageLabel.visible = false;
		}
		else
		{
			for (button in members)
				if (button != null) button.touchEnabled = true;

			toolbar[0].visible = true;
			shown = shown;
		}

		return value;
	}

	public function setPage(index:Int):Void
	{
		page = pages.length > 0 ? FlxMath.wrap(index, 0, pages.length - 1) : 0;

		for (pageIndex => buttons in pageButtons)
		{
			for (button in buttons)
			{
				final active = shown && pageIndex == page;
				if (!active && button.touchPressed) button.releaseAll();
				button.visible = active;
			}
		}

		pageLabel.text = '${page + 1}/${pages.length}';
		pageLabel.visible = pages.length > 1;
	}

	function set_shown(value:Bool):Bool
	{
		shown = value;

		for (button in members)
		{
			if (button == null || button == toolbar[0]) continue;

			if (!value && button.key.toggle != true) button.releaseAll();
			button.visible = value;
		}

		if (value) setPage(page);
		pageLabel.visible = value && pages.length > 1;

		return value;
	}

	function toggleKeyboard():Void
	{
		final window = lime.app.Application.current?.window;
		if (window != null && window.textInputEnabled) NativeUtil.hideKeyboard();
		else NativeUtil.showKeyboard();
	}

	function cycleMouseMode():Void
	{
		mouseMode = (mouseMode + 1) % 3;

		for (button in toolbar)
		{
			if (button.key.label != 'RMB') continue;
			button.color = switch (mouseMode)
			{
				case 1: 0xFFFFE066;
				case 2: 0xFF66E0FF;
				default: FlxColor.WHITE;
			}
			button.alpha = mouseMode == 0 ? idleAlpha : 1;
		}

		NativeUtil.toast(switch (mouseMode)
		{
			case 1: 'Touch works as right click';
			case 2: 'Touch works as middle click';
			default: 'Touch works as left click';
		});
	}

	function toggleMove():Void
	{
		moveMode = !moveMode;
		highlightTool('MOVE', moveMode);

		if (!moveMode)
		{
			dragButton = null;
			saveOffsets();
		}

		NativeUtil.toast(moveMode ? 'Drag the buttons to move them' : 'Layout saved');
	}

	function highlightTool(label:String, value:Bool):Void
	{
		for (button in toolbar)
		{
			if (button.key.label != label) continue;
			button.color = value ? 0xFFFFE066 : FlxColor.WHITE;
			button.alpha = value ? 1 : idleAlpha;
		}
	}

	function updateDrag():Void
	{
		#if FLX_TOUCH
		var touch:Null<flixel.input.touch.FlxTouch> = null;
		for (candidate in FlxG.touches.list)
			if (candidate.pressed)
			{
				touch = candidate;
				break;
			}

		if (touch == null)
		{
			dragButton = null;
			return;
		}

		final point = touch.getViewPosition(padCamera);

		if (touch.justPressed || dragButton == null)
		{
			dragButton = null;
			for (button in members)
			{
				if (button == null || !button.visible || button.group == 'toolbar') continue;
				if (point.x >= button.x && point.x < button.x + button.width && point.y >= button.y && point.y < button.y + button.height)
				{
					dragButton = button;
					break;
				}
			}

			dragLast.copyFrom(point);
			point.put();
			return;
		}

		final dx = point.x - dragLast.x;
		final dy = point.y - dragLast.y;
		dragLast.copyFrom(point);
		point.put();

		if (dx == 0 && dy == 0) return;

		final offset = getOffset(dragButton.group);
		offset.x += dx;
		offset.y += dy;

		for (button in members)
		{
			if (button == null || button.group != dragButton.group) continue;
			button.x += dx;
			button.y += dy;
		}
		#end
	}

	static function getOffset(group:String):FlxPoint
	{
		var offset = offsets.get(group);
		if (offset == null)
		{
			offset = FlxPoint.get();
			offsets.set(group, offset);
		}
		return offset;
	}

	function applyOffsets():Void
	{
		for (button in members)
		{
			if (button == null || button.group == 'toolbar') continue;
			final offset = getOffset(button.group);
			button.x += offset.x;
			button.y += offset.y;
		}
	}

	static function loadOffsets():Void
	{
		final data:Dynamic = FlxG.save.data.virtualPadOffsets;
		if (data == null) return;

		for (group in ['dpad', 'actions'])
		{
			final entry:Dynamic = Reflect.field(data, group);
			if (entry == null) continue;
			getOffset(group).set(Std.parseFloat(Std.string(entry.x)), Std.parseFloat(Std.string(entry.y)));
		}
	}

	static function saveOffsets():Void
	{
		final data:Dynamic = {};
		for (group => offset in offsets)
			Reflect.setField(data, group, {x: offset.x, y: offset.y});

		FlxG.save.data.virtualPadOffsets = data;
		FlxG.save.flush();
	}

	public static function resetLayout():Void
	{
		for (offset in offsets)
			offset.set();
		saveOffsets();
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
		mouseBlocked = hitsButton(event.stageX, event.stageY) || moveMode;
		if (mouseBlocked)
		{
			event.stopImmediatePropagation();
			return;
		}

		if (mouseMode != 0)
		{
			event.stopImmediatePropagation();
			redirectedDown = true;
			final type = mouseMode == 1 ? MouseEvent.RIGHT_MOUSE_DOWN : MouseEvent.MIDDLE_MOUSE_DOWN;
			FlxG.stage.dispatchEvent(new MouseEvent(type, true, false, event.localX, event.localY, null, event.ctrlKey, event.altKey, event.shiftKey, true));
		}
	}

	function onMouseUp(event:MouseEvent):Void
	{
		if (redirectedDown)
		{
			event.stopImmediatePropagation();
			redirectedDown = false;
			final upType = mouseMode == 2 ? MouseEvent.MIDDLE_MOUSE_UP : MouseEvent.RIGHT_MOUSE_UP;
			final clickType = mouseMode == 2 ? MouseEvent.MIDDLE_CLICK : MouseEvent.RIGHT_CLICK;
			FlxG.stage.dispatchEvent(new MouseEvent(upType, true, false, event.localX, event.localY, null, event.ctrlKey, event.altKey, event.shiftKey, false));
			FlxG.stage.dispatchEvent(new MouseEvent(clickType, true, false, event.localX, event.localY, null, event.ctrlKey, event.altKey, event.shiftKey, false));
			return;
		}

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
		moveMode = false;
		mouseMode = 0;

		FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		FlxG.stage.removeEventListener(MouseEvent.CLICK, onMouseClick);

		pageLabel.destroy();
		dragLast.put();

		super.destroy();
	}
}
