package funkin.mobile;

import openfl.display.BitmapData;
import openfl.geom.Rectangle;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSignal.FlxTypedSignal;

class Hitbox extends FlxTypedGroup<TouchButton>
{
	public static final COLORS:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];

	public static final MODES:Array<String> = ['Four Lanes', 'Triangle', 'Arrows', 'D-Pad Left', 'D-Pad Right', 'Double D-Pad'];

	public static function usesColors(mode:String):Bool
	{
		return mode == 'Four Lanes' || mode == 'Triangle';
	}

	public static function build(actions:Array<String>, camera:FlxCamera):Hitbox
	{
		final mode = ClientPrefs.hitboxMode;
		final hitbox = new Hitbox(actions, usesColors(mode) ? ClientPrefs.hitboxColors : null).setCamera(camera);

		switch (mode)
		{
			case 'D-Pad Left' | 'D-Pad Right':
				hitbox.applyDPad(mode == 'D-Pad Right');
			case 'Double D-Pad':
				hitbox.applyDoubleDPad();
			case 'Triangle':
				hitbox.applyTriangle();
			case 'Four Lanes':
				final image = loadCustomImage();
				if (image != null)
				{
					hitbox.applyImage(image);
					image.dispose();
				}
			default:
		}

		return hitbox;
	}

	public var alphaMultiplier(default, set):Float = 1;

	public static var pressedAlpha:Float = 0.9;

	public static var releaseDuration:Float = 0.15;

	public var enabled(default, set):Bool = true;

	public var colors(default, null):Array<FlxColor>;

	public var lanePressedAlpha:Float = pressedAlpha;

	public var idleAlpha(default, set):Float = 0;

	public var forceVisible:Null<Bool> = null;

	public final onLaneDown:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

	public final onLaneUp:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

	final fades:Map<TouchButton, FlxTween> = [];

	final actions:Array<String>;

	public function new(actions:Array<String>, ?colors:Array<FlxColor>)
	{
		super();

		this.actions = actions;
		this.colors = colors != null && colors.length > 0 ? colors.copy() : COLORS.copy();

		alphaMultiplier = ClientPrefs.hitboxAlpha;

		final laneWidth = Math.floor(FlxG.width / actions.length);

		for (i => action in actions)
		{
			final width = i == actions.length - 1 ? FlxG.width - laneWidth * i : laneWidth;

			final lane = createLane(i, action);
			lane.setPosition(laneWidth * i, 0);
			lane.loadGraphic(createLaneGraphic(width, FlxG.height, getColor(i)));
			add(lane);
		}
	}

	function createLane(index:Int, action:String):TouchButton
	{
		final lane = new TouchButton(0, 0, [action], 0);
		lane.blocksGestures = true;
		lane.haptic = false;
		lane.ID = index;
		lane.alpha = 0;

		lane.onDown.add(() -> {
			fades.get(lane)?.cancel();
			lane.alpha = shownAlpha(lanePressedAlpha);
			onLaneDown.dispatch(lane.ID);
		});

		lane.onUp.add(() -> {
			fades.get(lane)?.cancel();
			fades.set(lane, FlxTween.tween(lane, {alpha: shownAlpha(idleAlpha)}, releaseDuration));
			onLaneUp.dispatch(lane.ID);
		});

		return lane;
	}

	function shownAlpha(value:Float):Float
	{
		return isHidden() ? 0 : value * alphaMultiplier;
	}

	function set_alphaMultiplier(value:Float):Float
	{
		alphaMultiplier = Math.max(0, Math.min(1, value));

		if (members != null)
			for (lane in members)
				if (lane != null && !lane.touchPressed) lane.alpha = shownAlpha(idleAlpha);

		return alphaMultiplier;
	}

	public var triangle(default, null):Bool = false;

	public static function triangleBounds(index:Int, width:Float, height:Float):Rectangle
	{
		return switch (index)
		{
			case 0: new Rectangle(0, 0, width / 2, height);
			case 1: new Rectangle(0, height / 2, width, height / 2);
			case 2: new Rectangle(0, 0, width, height / 2);
			default: new Rectangle(width / 2, 0, width / 2, height);
		}
	}

	public static function triangleScore(index:Int, x:Float, y:Float, width:Float, height:Float):Float
	{
		final dx = (x - width / 2) / (width / 2);
		final dy = (y - height / 2) / (height / 2);

		return switch (index)
		{
			case 0: -dx;
			case 1: dy;
			case 2: -dy;
			default: dx;
		}
	}

	public static function triangleContains(index:Int, x:Float, y:Float, width:Float, height:Float, padding:Float = 0):Bool
	{
		if (x < 0 || y < 0 || x >= width || y >= height) return false;

		final score = triangleScore(index, x, y, width, height);
		final tolerance = padding / (Math.min(width, height) / 2);

		for (other in 0...4)
			if (other != index && triangleScore(other, x, y, width, height) > score + tolerance) return false;

		return true;
	}

	public static function createTriangleGraphic(index:Int, width:Float, height:Float, color:FlxColor):BitmapData
	{
		final bounds = triangleBounds(index, width, height);
		final cx = width / 2 - bounds.x;
		final cy = height / 2 - bounds.y;

		final points:Array<Array<Float>> = switch (index)
		{
			case 0: [[0, 0], [0, bounds.height], [cx, cy]];
			case 1: [[0, bounds.height], [bounds.width, bounds.height], [cx, cy]];
			case 2: [[0, 0], [bounds.width, 0], [cx, cy]];
			default: [[bounds.width, 0], [bounds.width, bounds.height], [cx, cy]];
		}

		final shape = new openfl.display.Shape();
		final graphics = shape.graphics;
		final inset = borderSize / 2;

		graphics.lineStyle(borderSize, color.rgb, 1);
		graphics.beginFill(color.rgb, fillAlpha);
		graphics.moveTo(Math.max(inset, Math.min(bounds.width - inset, points[0][0])), Math.max(inset, Math.min(bounds.height - inset, points[0][1])));
		for (i in 1...points.length)
			graphics.lineTo(Math.max(inset, Math.min(bounds.width - inset, points[i][0])), Math.max(inset, Math.min(bounds.height - inset, points[i][1])));
		graphics.lineTo(Math.max(inset, Math.min(bounds.width - inset, points[0][0])), Math.max(inset, Math.min(bounds.height - inset, points[0][1])));
		graphics.endFill();

		final bitmap = new BitmapData(Std.int(Math.max(1, Math.ceil(bounds.width))), Std.int(Math.max(1, Math.ceil(bounds.height))), true, FlxColor.TRANSPARENT);
		bitmap.draw(shape, null, null, null, null, true);
		return bitmap;
	}

	public function applyTriangle():Void
	{
		if (members.length < 4) return;

		triangle = true;

		for (index in 0...4)
		{
			final lane = members[index];
			if (lane == null) continue;

			final bounds = triangleBounds(index, FlxG.width, FlxG.height);
			lane.loadGraphic(createTriangleGraphic(index, FlxG.width, FlxG.height, getColor(index)));
			lane.setPosition(bounds.x, bounds.y);
			lane.updateHitbox();

			final laneIndex = index;
			lane.hitTest = (x, y, padding) -> triangleContains(laneIndex, x, y, FlxG.width, FlxG.height, padding);
		}
	}

	public function applyDoubleDPad():Void
	{
		if (members.length < 4) return;

		applyDPad(false);

		final atlas = loadNoteAtlas();
		final camera = members[0].cameras;

		for (index in 0...4)
		{
			final lane = createLane(index, actions[index]);
			lane.cameras = camera;
			lane.loadGraphic(createDPadGraphic(dpadSize, getColor(index), atlas, DPAD_NOTES[index]));
			lane.updateHitbox();
			final position = dpadPosition(index, true);
			lane.setPosition(position[0], position[1]);
			lane.alpha = shownAlpha(idleAlpha);
			add(lane);
		}

		if (atlas != null) atlas.parent.destroy();
	}

	public static function dpadPosition(index:Int, onRight:Bool):Array<Float>
	{
		final size = dpadSize;
		final step = size + dpadGap;
		final width = size * 3 + dpadGap * 2;
		final left = onRight ? MobileUtil.rightEdge() - width : MobileUtil.leftEdge();
		final bottom = MobileUtil.bottomEdge() - size;

		return switch (index)
		{
			case 0: [left, bottom - step];
			case 1: [left + step, bottom];
			case 2: [left + step, bottom - step * 2];
			default: [left + step * 2, bottom - step];
		}
	}

	public static inline final CUSTOM_IMAGE_FOLDER:String = 'mobile';

	public static function getCustomImagePath():Null<String>
	{
		final path = ClientPrefs.hitboxImage;
		if (path == null || path.length == 0) return null;
		#if sys
		if (!sys.FileSystem.exists(path)) return null;
		#end
		return path;
	}

	public static function loadCustomImage():Null<BitmapData>
	{
		final path = getCustomImagePath();
		if (path == null) return null;

		try
		{
			#if sys
			return BitmapData.fromBytes(sys.io.File.getBytes(path));
			#end
		}
		catch (e:Dynamic) {}

		return null;
	}

	public static function sliceImage(image:BitmapData, index:Int, count:Int, width:Int, height:Int):BitmapData
	{
		final laneWidth = Math.floor(width / count);
		final sliceWidth = index == count - 1 ? width - laneWidth * index : laneWidth;
		final result = new BitmapData(Std.int(Math.max(1, sliceWidth)), Std.int(Math.max(1, height)), true, FlxColor.TRANSPARENT);
		final matrix = new openfl.geom.Matrix();
		matrix.scale(width / image.width, height / image.height);
		matrix.translate(-laneWidth * index, 0);
		result.draw(image, matrix, null, null, null, true);
		return result;
	}

	public var customImage(default, null):Bool = false;

	public function applyImage(image:BitmapData):Void
	{
		if (image == null || dpad) return;

		customImage = true;

		for (index => lane in members)
		{
			if (lane == null) continue;
			lane.loadGraphic(sliceImage(image, index, members.length, FlxG.width, FlxG.height));
			lane.updateHitbox();
		}
	}

	public static final DPAD_NOTES:Array<String> = ['purple', 'blue', 'green', 'red'];

	public static var dpadSize:Int = 124;

	public static var dpadGap:Float = 6;

	public static var dpadIdleAlpha:Float = 0.6;

	public var dpad(default, null):Bool = false;

	public function applyDPad(onRight:Bool):Void
	{
		if (members.length < 4) return;

		dpad = true;

		final size = dpadSize;
		final atlas = loadNoteAtlas();

		for (index in 0...4)
		{
			final lane = members[index];
			if (lane == null) continue;

			lane.loadGraphic(createDPadGraphic(size, getColor(index), atlas, DPAD_NOTES[index]));
			final position = dpadPosition(index, onRight);
			lane.setPosition(position[0], position[1]);
			lane.updateHitbox();
		}

		if (atlas != null) atlas.parent.destroy();

		lanePressedAlpha = 1;
		idleAlpha = dpadIdleAlpha;
	}

	public static function loadNoteAtlas():Null<flixel.graphics.frames.FlxAtlasFrames>
	{
		try
		{
			final bitmap = FunkinAssets.getBitmapData(Paths.getPath('images/UI/notes/NOTE_assets.png', null, true), false);
			final xmlPath = Paths.getPath('images/UI/notes/NOTE_assets.xml', null, true);
			if (bitmap == null || !FunkinAssets.exists(xmlPath)) return null;

			final graphic = flixel.graphics.FlxGraphic.fromBitmapData(bitmap, false, null, false);
			return flixel.graphics.frames.FlxAtlasFrames.fromSparrow(graphic, FunkinAssets.getContent(xmlPath, false));
		}
		catch (e:Dynamic) {}

		return null;
	}

	public static function createDPadGraphic(size:Int, color:FlxColor, atlas:Null<flixel.graphics.frames.FlxAtlasFrames>, prefix:String):BitmapData
	{
		final radius = size * 0.28;
		final shape = new openfl.display.Shape();
		final graphics = shape.graphics;

		var dark:FlxColor = color;
		dark.brightness *= 0.55;

		graphics.beginFill(dark.rgb, 0.9);
		graphics.drawRoundRect(0, 0, size, size, radius, radius);
		graphics.endFill();

		graphics.beginFill(color.rgb, 0.75);
		graphics.drawRoundRect(5, 5, size - 10, size - 10, radius * 0.85, radius * 0.85);
		graphics.endFill();

		graphics.beginFill(0xFFFFFF, 0.18);
		graphics.drawRoundRect(9, 9, size - 18, (size - 18) * 0.45, radius * 0.7, radius * 0.7);
		graphics.endFill();

		final bitmap = new BitmapData(size, size, true, FlxColor.TRANSPARENT);
		bitmap.draw(shape);

		if (atlas != null)
		{
			var frame:Null<flixel.graphics.frames.FlxFrame> = null;
			for (candidate in atlas.frames)
			{
				if (candidate.name != null && candidate.name.startsWith(prefix) && !candidate.name.contains('hold'))
				{
					frame = candidate;
					break;
				}
			}

			if (frame != null)
			{
				final arrow = frame.paint(null, null, true);
				final target = size * 0.62;
				final scale = Math.min(target / arrow.width, target / arrow.height);
				final matrix = new openfl.geom.Matrix();
				matrix.scale(scale, scale);
				matrix.translate((size - arrow.width * scale) / 2, (size - arrow.height * scale) / 2);
				bitmap.draw(arrow, matrix, new openfl.geom.ColorTransform(1, 1, 1, 0.9), null, null, true);
				arrow.dispose();
			}
		}

		return bitmap;
	}

	public function isHidden():Bool
	{
		return forceVisible != null ? !forceVisible : ClientPrefs.invisibleHitbox;
	}

	public function setCamera(camera:FlxCamera):Hitbox
	{
		for (lane in members)
			lane.cameras = [camera];

		return this;
	}

	public function getLane(index:Int):Null<TouchButton>
	{
		return index >= 0 && index < members.length ? members[index] : null;
	}

	public function setLaneColor(index:Int, color:FlxColor):Void
	{
		final lane = getLane(index);
		if (lane == null) return;

		while (colors.length <= index)
			colors.push(COLORS[colors.length % COLORS.length]);
		colors[index] = color;

		lane.loadGraphic(createLaneGraphic(Std.int(lane.width), Std.int(lane.height), color));
	}

	public function setColors(newColors:Array<FlxColor>):Void
	{
		for (index in 0...members.length)
			if (index < newColors.length) setLaneColor(index, newColors[index]);
	}

	public function setLaneBounds(index:Int, x:Float, y:Float, width:Float, height:Float):Void
	{
		final lane = getLane(index);
		if (lane == null || width < 1 || height < 1) return;

		lane.loadGraphic(createLaneGraphic(Std.int(width), Std.int(height), getColor(index)));
		lane.setPosition(x, y);
		lane.updateHitbox();
	}

	public function setLaneActions(index:Int, laneActions:Array<String>):Void
	{
		final lane = getLane(index);
		if (lane != null) lane.actions = laneActions;
	}

	public function resetLayout():Void
	{
		final laneWidth = Math.floor(FlxG.width / members.length);

		for (index => lane in members)
		{
			final width = index == members.length - 1 ? FlxG.width - laneWidth * index : laneWidth;
			setLaneBounds(index, laneWidth * index, 0, width, FlxG.height);
			lane.actions = [actions[index]];
		}
	}

	public function isLanePressed(index:Int):Bool
	{
		for (lane in members)
			if (lane != null && lane.ID == index && lane.touchPressed) return true;
		return false;
	}

	function getColor(index:Int):FlxColor
	{
		return colors[index % colors.length];
	}

	function set_idleAlpha(value:Float):Float
	{
		idleAlpha = Math.max(0, Math.min(1, value));

		for (lane in members)
			if (!lane.touchPressed) lane.alpha = shownAlpha(idleAlpha);

		return idleAlpha;
	}

	function set_enabled(value:Bool):Bool
	{
		for (lane in members)
		{
			lane.touchEnabled = value;

			if (!value)
			{
				fades.get(lane)?.cancel();
				lane.alpha = 0;
			}
			else if (!lane.touchPressed)
			{
				lane.alpha = shownAlpha(idleAlpha);
			}
		}

		return enabled = value;
	}

	public static var fillAlpha:Float = 0.25;

	public static var borderSize:Int = 3;

	public static function createLaneGraphic(width:Int, height:Int, color:FlxColor):BitmapData
	{
		final bitmap = new BitmapData(width, height, true, FlxColor.TRANSPARENT);

		var fill:FlxColor = color;
		fill.alphaFloat = fillAlpha;
		bitmap.fillRect(new Rectangle(0, 0, width, height), fill);

		var border:FlxColor = color;
		border.alphaFloat = 1;
		bitmap.fillRect(new Rectangle(0, 0, width, borderSize), border);
		bitmap.fillRect(new Rectangle(0, height - borderSize, width, borderSize), border);
		bitmap.fillRect(new Rectangle(0, 0, borderSize, height), border);
		bitmap.fillRect(new Rectangle(width - borderSize, 0, borderSize, height), border);

		return bitmap;
	}

	override function destroy():Void
	{
		for (tween in fades)
			tween?.cancel();
		fades.clear();

		onLaneDown.removeAll();
		onLaneUp.removeAll();

		super.destroy();
	}
}
