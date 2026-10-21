package funkin.mobile;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class CopyState extends FlxState
{
	public static var frameBudget:Float = 0.014;

	var files:Array<String> = [];

	var failed:Array<String> = [];

	var index:Int = 0;

	var copying:Bool = false;

	var waitingChoice:Bool = false;

	var label:FlxText;

	var fileLabel:FlxText;

	var barBack:FlxSprite;

	var bar:FlxSprite;

	var retryButton:FlxText;

	var continueButton:FlxText;

	override function create():Void
	{
		super.create();

		FlxG.mouse.visible = false;

		if (!StorageUtil.ready)
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

		label = new FlxText(0, barBack.y - 80, FlxG.width, '', 24);
		label.alignment = CENTER;
		add(label);

		fileLabel = new FlxText(40, barBack.y + 36, FlxG.width - 80, '', 14);
		fileLabel.alignment = CENTER;
		fileLabel.color = 0xFFAAAAAA;
		add(fileLabel);

		retryButton = createChoice('RETRY', FlxG.width * 0.25);
		continueButton = createChoice('CONTINUE', FlxG.width * 0.75);

		start(StorageUtil.getPendingFiles());
	}

	function createChoice(text:String, centerX:Float):FlxText
	{
		final button = new FlxText(0, FlxG.height - 120, 300, text, 32);
		button.alignment = CENTER;
		button.x = centerX - button.width / 2;
		button.visible = false;
		add(button);
		return button;
	}

	function start(list:Array<String>):Void
	{
		files = list;
		failed = [];
		index = 0;
		waitingChoice = false;
		retryButton.visible = continueButton.visible = false;

		if (files.length == 0)
		{
			StorageUtil.finishCopy([]);
			finish();
			return;
		}

		copying = true;
		updateLabel();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (waitingChoice)
		{
			handleChoice();
			return;
		}

		if (!copying) return;

		final start = Sys.time();

		while (index < files.length && Sys.time() - start < frameBudget)
		{
			final id = files[index++];
			if (!StorageUtil.copyAsset(id)) failed.push(id);
		}

		updateLabel();

		if (index >= files.length) complete();
	}

	function complete():Void
	{
		copying = false;

		final remaining = StorageUtil.finishCopy(failed);

		if (remaining.length == 0)
		{
			finish();
			return;
		}

		failed = remaining;
		waitingChoice = true;

		label.text = '${remaining.length} file(s) could not be copied.\nCheck your free storage space.';
		fileLabel.text = remaining[0];
		retryButton.visible = continueButton.visible = true;
	}

	function handleChoice():Void
	{
		if (pressed(retryButton) || FlxG.keys.justPressed.R)
		{
			start(failed);
		}
		else if (pressed(continueButton) || FlxG.keys.justPressed.ENTER)
		{
			finish();
		}
	}

	function pressed(button:FlxText):Bool
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.justReleased())
		{
			if (touch.overlaps(button)) return true;
		}
		#end

		#if FLX_MOUSE
		if (FlxG.mouse.justReleased && FlxG.mouse.overlaps(button)) return true;
		#end

		return false;
	}

	function updateLabel():Void
	{
		if (label == null) return;

		final progress = files.length > 0 ? index / files.length : 1;

		label.text = 'Copying files to storage...\n$index / ${files.length}';
		fileLabel.text = index > 0 && index <= files.length ? files[index - 1] : '';
		bar.scale.x = progress;
	}

	function finish():Void
	{
		copying = false;
		waitingChoice = false;

		FlxG.switchState(() -> new Init());
	}
}
