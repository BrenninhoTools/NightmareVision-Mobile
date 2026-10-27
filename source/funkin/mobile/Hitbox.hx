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

		final laneWidth = Math.floor(FlxG.width / actions.length);

		for (i => action in actions)
		{
			final width = i == actions.length - 1 ? FlxG.width - laneWidth * i : laneWidth;

			final lane = new TouchButton(laneWidth * i, 0, [action], 0);
			lane.blocksGestures = true;
			lane.haptic = false;
			lane.ID = i;
			lane.loadGraphic(createLaneGraphic(width, FlxG.height, getColor(i)));
			lane.alpha = 0;

			lane.onDown.add(() -> {
				fades.get(lane)?.cancel();
				lane.alpha = isHidden() ? 0 : lanePressedAlpha;
				onLaneDown.dispatch(lane.ID);
			});

			lane.onUp.add(() -> {
				fades.get(lane)?.cancel();
				fades.set(lane, FlxTween.tween(lane, {alpha: isHidden() ? 0 : idleAlpha}, releaseDuration));
				onLaneUp.dispatch(lane.ID);
			});

			add(lane);
		}
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
		return getLane(index)?.touchPressed ?? false;
	}

	function getColor(index:Int):FlxColor
	{
		return colors[index % colors.length];
	}

	function set_idleAlpha(value:Float):Float
	{
		idleAlpha = Math.max(0, Math.min(1, value));

		for (lane in members)
			if (!lane.touchPressed) lane.alpha = isHidden() ? 0 : idleAlpha;

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
				lane.alpha = isHidden() ? 0 : idleAlpha;
			}
		}

		return enabled = value;
	}

	public static var fillAlpha:Float = 0.25;

	public static var borderSize:Int = 3;

	static function createLaneGraphic(width:Int, height:Int, color:FlxColor):BitmapData
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
