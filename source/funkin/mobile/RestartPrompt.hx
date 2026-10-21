package funkin.mobile;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

import funkin.backend.MusicBeatSubstate;

class RestartPrompt extends MusicBeatSubstate
{
	final message:String;

	final onConfirm:Void->Void;

	final onCancel:Void->Void;

	final confirmLabel:String;

	final cancelLabel:String;

	var choices:Array<FlxText> = [];

	var selected:Int = 0;

	var promptCamera:Null<FlxCamera> = null;

	var finished:Bool = false;

	public function new(message:String, onConfirm:Void->Void, onCancel:Void->Void, confirmLabel:String = 'RESTART', cancelLabel:String = 'LATER')
	{
		super();

		this.message = message;
		this.onConfirm = onConfirm;
		this.onCancel = onCancel;
		this.confirmLabel = confirmLabel;
		this.cancelLabel = cancelLabel;
	}

	override function create():Void
	{
		super.create();

		promptCamera = MobileUtil.createCamera();
		cameras = [promptCamera];

		final shade = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		shade.setGraphicSize(FlxG.width, FlxG.height);
		shade.updateHitbox();
		shade.alpha = 0.75;
		add(shade);

		final text = new FlxText(60, 0, FlxG.width - 120, message, 36);
		text.setFormat(Paths.DEFAULT_FONT, 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.y = FlxG.height * 0.38 - text.height / 2;
		add(text);

		for (index => label in [confirmLabel, cancelLabel])
		{
			final choice = new FlxText(0, FlxG.height * 0.66, 360, label, 48);
			choice.setFormat(Paths.DEFAULT_FONT, 48, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			choice.borderSize = 3;
			choice.x = FlxG.width * (index == 0 ? 0.3 : 0.7) - choice.width / 2;
			add(choice);
			choices.push(choice);
		}

		refresh();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (finished) return;

		if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			selected = selected == 0 ? 1 : 0;
			FlxG.sound.play(Paths.sound('scrollMenu'));
			refresh();
		}

		for (index => choice in choices)
		{
			if (TouchUtil.tappedOn(choice, promptCamera))
			{
				choose(index);
				return;
			}
		}

		if (controls.BACK)
		{
			choose(1);
			return;
		}

		if (controls.ACCEPT && !TouchUtil.tapped) choose(selected);
	}

	function refresh():Void
	{
		for (index => choice in choices)
		{
			choice.alpha = index == selected ? 1 : 0.5;
			choice.color = index == selected ? 0xFFFFE066 : FlxColor.WHITE;
		}
	}

	function choose(index:Int):Void
	{
		finished = true;
		FlxG.sound.play(Paths.sound(index == 0 ? 'confirmMenu' : 'cancelMenu'));
		close();

		if (index == 0) onConfirm();
		else onCancel();
	}

	override function destroy():Void
	{
		if (promptCamera != null && FlxG.cameras.list.contains(promptCamera)) FlxG.cameras.remove(promptCamera);
		promptCamera = null;

		super.destroy();
	}
}
