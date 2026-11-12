package funkin.mobile.states;

import funkin.mobile.native.PurchaseUtil;

import flixel.FlxG;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;

import haxe.ui.components.HorizontalProgress;
import haxe.ui.components.Label;
import haxe.ui.containers.VBox;
import haxe.ui.core.Screen;

class RestorePurchasesState extends FlxState
{
	public static var resultTime:Float = 1.6;

	var panel:VBox;

	var status:Label;

	var progress:HorizontalProgress;

	var leaving:Bool = false;

	var spin:Float = 0;

	override function create():Void
	{
		super.create();

		FlxG.mouse.visible = true;

		final gradient = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFF120E1E, 0xFF231A3A, 0xFF120E1E]);
		gradient.scrollFactor.set();
		add(gradient);

		panel = new VBox();
		panel.width = Math.min(520, FlxG.width - 40);
		panel.padding = 22;
		panel.verticalSpacing = 14;
		panel.backgroundColor = 0x1B1729;
		panel.borderColor = 0x8A6BD1;
		panel.borderSize = 2;
		panel.borderRadius = 10;

		final title = new Label();
		title.text = 'Restore Purchases';
		title.styleString = 'font-size: 28px; color: #FFFFFF;';
		title.horizontalAlign = 'center';
		panel.addComponent(title);

		status = new Label();
		status.text = 'Connecting to the store...';
		status.styleString = 'font-size: 16px; color: #B9B3CC;';
		status.percentWidth = 100;
		status.textAlign = 'center';
		panel.addComponent(status);

		progress = new HorizontalProgress();
		progress.percentWidth = 100;
		progress.height = 18;
		progress.indeterminate = true;
		panel.addComponent(progress);

		Screen.instance.addComponent(panel);
		if (!members.contains(panel)) add(panel);
		layout();

		PurchaseUtil.restore(onRestored);
	}

	function layout():Void
	{
		panel.left = (FlxG.width - panel.width) / 2;
		panel.top = (FlxG.height - panel.height) / 2;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		layout();

		if (PurchaseUtil.restoring)
		{
			spin += elapsed;
			final dots = Std.int(spin * 3) % 4;
			status.text = 'Restoring your purchases' + [for (i in 0...dots) '.'].join('');
		}
	}

	function onRestored(result:RestoreResult):Void
	{
		progress.indeterminate = false;
		progress.pos = 100;

		status.text = switch (result)
		{
			case RESTORED(count): 'Restored $count purchase' + (count == 1 ? '' : 's') + '!';
			case NOTHING: 'No purchases to restore.';
			case FAILED(reason): 'Could not restore purchases.\n' + (reason ?? '');
			case UNSUPPORTED: 'Purchases are not available on this platform.';
		}

		#if mobile
		switch (result)
		{
			case RESTORED(_): funkin.mobile.haptics.Haptics.confirm();
			case FAILED(_): funkin.mobile.haptics.Haptics.denied();
			default:
		}
		#end

		haxe.Timer.delay(goToTitle, Std.int(resultTime * 1000));
	}

	function goToTitle():Void
	{
		if (leaving) return;
		leaving = true;

		Screen.instance.removeComponent(panel, false);
		FlxG.switchState(() -> new funkin.states.TitleState());
	}
}
