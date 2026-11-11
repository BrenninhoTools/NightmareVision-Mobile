package funkin.mobile.states;

import funkin.mobile.android.logcat.LogcatUtil;
import funkin.mobile.backend.StorageUtil;
import funkin.mobile.native.NativeUtil;

import flixel.FlxG;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;

import haxe.ui.components.Button;
import haxe.ui.components.HorizontalProgress;
import haxe.ui.components.Label;
import haxe.ui.containers.HBox;
import haxe.ui.containers.VBox;
import haxe.ui.core.Screen;

class CopyState extends FlxState
{
	public static var frameBudget:Float = 0.014;

	public static inline final PANEL_WIDTH:Float = 640;

	static final ACCENT:Int = 0x8A6BD1;

	var files:Array<String> = [];

	var failed:Array<String> = [];

	var index:Int = 0;

	var copying:Bool = false;

	var waitingChoice:Bool = false;

	var job:Null<funkin.mobile.backend.StorageUtil.CopyJob> = null;

	var startTime:Float = 0;

	var panel:VBox;

	var title:Label;

	var subtitle:Label;

	var progress:HorizontalProgress;

	var countLabel:Label;

	var percentLabel:Label;

	var fileLabel:Label;

	var statsLabel:Label;

	var errorBox:VBox;

	var errorLabel:Label;

	var failedLabel:Label;

	var particles:Array<FlxSprite> = [];

	var shownProgress:Float = 0;

	override function create():Void
	{
		super.create();

		FlxG.mouse.visible = true;

		if (!StorageUtil.ready || StorageUtil.isUpToDate())
		{
			finish();
			return;
		}

		buildBackground();
		buildPanel();

		final pending = StorageUtil.getPendingFiles();
		LogcatUtil.mark('CopyState: ' + pending.length + ' pending files');
		start(pending);
	}

	function buildBackground():Void
	{
		final gradient = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFF120E1E, 0xFF231A3A, 0xFF120E1E]);
		gradient.scrollFactor.set();
		add(gradient);

		for (i in 0...18)
		{
			final size = FlxG.random.int(6, 22);
			final particle = new FlxSprite(FlxG.random.float(0, FlxG.width), FlxG.random.float(0, FlxG.height)).makeGraphic(size, size, FlxColor.WHITE);
			particle.alpha = FlxG.random.float(0.04, 0.14);
			particle.angle = FlxG.random.float(0, 360);
			particle.velocity.set(FlxG.random.float(-12, 12), FlxG.random.float(-28, -10));
			particle.angularVelocity = FlxG.random.float(-30, 30);
			particle.color = FlxG.random.bool() ? 0xFFB79BFF : 0xFFFFFFFF;
			particles.push(particle);
			add(particle);
		}
	}

	function buildPanel():Void
	{
		panel = new VBox();
		panel.width = Math.min(PANEL_WIDTH, FlxG.width - 40);
		panel.padding = 22;
		panel.verticalSpacing = 12;
		panel.backgroundColor = 0x1B1729;
		panel.borderColor = ACCENT;
		panel.borderSize = 2;
		panel.borderRadius = 10;

		title = makeLabel('NightmareVision', 30, '#FFFFFF');
		title.horizontalAlign = 'center';
		panel.addComponent(title);

		subtitle = makeLabel('Preparing the game files. This only happens on the first launch and after updates.', 15, '#B9B3CC');
		subtitle.percentWidth = 100;
		subtitle.textAlign = 'center';
		panel.addComponent(subtitle);

		progress = new HorizontalProgress();
		progress.percentWidth = 100;
		progress.height = 22;
		progress.min = 0;
		progress.max = 100;
		progress.pos = 0;
		panel.addComponent(progress);

		final counts = new HBox();
		counts.percentWidth = 100;

		countLabel = makeLabel('0 / 0 files', 16, '#FFFFFF');
		countLabel.percentWidth = 70;
		counts.addComponent(countLabel);

		percentLabel = makeLabel('0%', 16, '#D9CCFF');
		percentLabel.percentWidth = 30;
		percentLabel.textAlign = 'right';
		counts.addComponent(percentLabel);

		panel.addComponent(counts);

		fileLabel = makeLabel('', 13, '#8F89A3');
		fileLabel.percentWidth = 100;
		panel.addComponent(fileLabel);

		statsLabel = makeLabel('', 13, '#8F89A3');
		statsLabel.percentWidth = 100;
		panel.addComponent(statsLabel);

		errorBox = new VBox();
		errorBox.percentWidth = 100;
		errorBox.verticalSpacing = 8;
		errorBox.hidden = true;

		errorLabel = makeLabel('', 16, '#FF8A8A');
		errorLabel.percentWidth = 100;
		errorBox.addComponent(errorLabel);

		failedLabel = makeLabel('', 12, '#B9B3CC');
		failedLabel.percentWidth = 100;
		errorBox.addComponent(failedLabel);

		final buttons = new HBox();
		buttons.percentWidth = 100;
		buttons.horizontalSpacing = 8;

		final retry = makeButton('Retry');
		retry.onClick = (_) -> retryFailed();
		buttons.addComponent(retry);

		final copyList = makeButton('Copy Error List');
		copyList.onClick = (_) -> {
			NativeUtil.setClipboard(failed.join('\n'));
			NativeUtil.toast('Error list copied');
		};
		buttons.addComponent(copyList);

		final skip = makeButton('Continue');
		skip.onClick = (_) -> finish();
		buttons.addComponent(skip);

		errorBox.addComponent(buttons);
		panel.addComponent(errorBox);

		Screen.instance.addComponent(panel);
		if (!members.contains(panel)) add(panel);

		layoutPanel();
	}

	function layoutPanel():Void
	{
		if (panel == null) return;
		panel.left = (FlxG.width - panel.width) / 2;
		panel.top = Math.max(20, (FlxG.height - panel.height) / 2);
	}

	function makeLabel(text:String, size:Int, color:String):Label
	{
		final label = new Label();
		label.text = text;
		label.styleString = 'font-size: ${size}px; color: $color;';
		return label;
	}

	function makeButton(text:String):Button
	{
		final button = new Button();
		button.text = text;
		button.percentWidth = 33;
		button.height = 46;
		return button;
	}

	function start(list:Array<String>):Void
	{
		files = list;
		failed = [];
		index = 0;
		waitingChoice = false;
		shownProgress = 0;
		errorBox.hidden = true;
		title.text = 'NightmareVision';

		if (files.length == 0)
		{
			StorageUtil.finishCopy([]);
			finish();
			return;
		}

		copying = true;
		startTime = haxe.Timer.stamp();
		job = StorageUtil.supportsThreadedCopy ? StorageUtil.startCopyJob(files) : null;
		updateLabels();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		updateParticles();
		layoutPanel();

		if (waitingChoice)
		{
			if (FlxG.keys.justPressed.R) retryFailed();
			else if (FlxG.keys.justPressed.ENTER) finish();
			return;
		}

		if (!copying) return;

		if (job != null)
		{
			index = job.done;
			updateLabels();
			StorageUtil.flush();

			if (job.finished)
			{
				failed = job.failed.copy();
				job = null;
				complete();
			}
			return;
		}

		final begin = Sys.time();

		while (index < files.length && Sys.time() - begin < frameBudget)
		{
			final id = files[index++];
			LogcatUtil.debug('copy ' + id);
			if (!StorageUtil.copyAsset(id)) failed.push(id);
		}

		updateLabels();

		if (index >= files.length) complete();
	}

	function updateParticles():Void
	{
		for (particle in particles)
		{
			if (particle.y < -30)
			{
				particle.y = FlxG.height + 10;
				particle.x = FlxG.random.float(0, FlxG.width);
			}
			if (particle.x < -30) particle.x = FlxG.width + 10;
			else if (particle.x > FlxG.width + 30) particle.x = -10;
		}
	}

	function updateLabels():Void
	{
		if (progress == null) return;

		final total = files.length;
		final target = total > 0 ? index / total * 100 : 100;
		shownProgress += (target - shownProgress) * Math.min(1, FlxG.elapsed * 12);
		if (Math.abs(target - shownProgress) < 0.1) shownProgress = target;

		progress.pos = shownProgress;
		countLabel.text = '$index / $total files';
		percentLabel.text = Std.int(target) + '%';

		final current = job != null ? job.current : (index > 0 && index <= total ? files[index - 1] : '');
		fileLabel.text = shorten(current ?? '', 72);

		final elapsedTime = haxe.Timer.stamp() - startTime;
		if (elapsedTime > 0.5 && index > 0)
		{
			final speed = index / elapsedTime;
			final remaining = speed > 0 ? (total - index) / speed : 0;
			statsLabel.text = Std.int(speed) + ' files/s  |  ' + formatTime(remaining) + ' left  |  ' + StorageUtil.getActiveStorageType();
		}
		else
		{
			statsLabel.text = StorageUtil.getActiveStorageType();
		}
	}

	function complete():Void
	{
		copying = false;

		final remaining = StorageUtil.finishCopy(failed);
		LogcatUtil.mark('CopyState: copy finished, ' + remaining.length + ' failed');

		if (remaining.length == 0)
		{
			finish();
			return;
		}

		failed = remaining;
		waitingChoice = true;

		final free = StorageUtil.getFreeSpaceMB();
		title.text = 'Some files could not be copied';
		errorLabel.text = '${remaining.length} file(s) failed.' + (free >= 0 ? ' Free space: $free MB.' : '') + '\nCheck your storage and try again, or continue anyway.';
		failedLabel.text = [for (i in 0...Std.int(Math.min(5, remaining.length))) '- ' + shorten(remaining[i], 70)].join('\n') + (remaining.length > 5 ? '\n...and ' + (remaining.length - 5) + ' more' : '');
		errorBox.hidden = false;

		#if mobile
		funkin.mobile.haptics.Haptics.denied();
		#end
	}

	function retryFailed():Void
	{
		if (!waitingChoice) return;
		start(failed.copy());
	}

	static function shorten(text:String, max:Int):String
	{
		return text.length <= max ? text : '...' + text.substr(text.length - max + 3);
	}

	static function formatTime(seconds:Float):String
	{
		final total = Std.int(Math.max(0, seconds));
		final minutes = Std.int(total / 60);
		final rest = total % 60;
		return minutes + ':' + (rest < 10 ? '0' : '') + rest;
	}

	function finish():Void
	{
		LogcatUtil.mark('CopyState: finished, failed ' + failed.length);
		copying = false;
		waitingChoice = false;

		if (panel != null) Screen.instance.removeComponent(panel, false);

		FlxG.switchState(() -> new Init());
	}
}
