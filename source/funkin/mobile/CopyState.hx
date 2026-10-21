package funkin.mobile;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class CopyState extends FlxState
{
	public static var frameBudget:Float = 0.014;

	var files:Array<String> = [];

	final failed:Array<String> = [];

	var index:Int = 0;

	var finished:Bool = false;

	var label:FlxText;

	var barBack:FlxSprite;

	var bar:FlxSprite;

	override function create():Void
	{
		super.create();

		FlxG.mouse.visible = false;

		files = StorageUtil.getPendingFiles();

		if (files.length == 0)
		{
			finish();
			return;
		}

		final barWidth = Std.int(FlxG.width * 0.6);

		barBack = new FlxSprite().makeGraphic(barWidth, 16, 0xFF2A2A2A);
		barBack.screenCenter();
		barBack.y += 40;
		add(barBack);

		bar = new FlxSprite(barBack.x, barBack.y).makeGraphic(barWidth, 16, FlxColor.WHITE);
		bar.origin.set();
		bar.scale.x = 0;
		add(bar);

		label = new FlxText(0, barBack.y - 70, FlxG.width, '', 24);
		label.alignment = CENTER;
		add(label);

		updateLabel();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (finished) return;

		final start = Sys.time();

		while (index < files.length && Sys.time() - start < frameBudget)
		{
			final id = files[index++];
			if (!StorageUtil.copyAsset(id)) failed.push(id);
		}

		updateLabel();

		if (index >= files.length) finish();
	}

	function updateLabel():Void
	{
		if (label == null) return;

		final progress = files.length > 0 ? index / files.length : 1;

		label.text = 'Copying files to storage...\n$index / ${files.length}';
		bar.scale.x = progress;
	}

	function finish():Void
	{
		if (finished) return;
		finished = true;

		StorageUtil.finishCopy(failed);

		FlxG.switchState(() -> new Init());
	}
}
