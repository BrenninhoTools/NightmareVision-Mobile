package funkin.states.options;

import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.util.FlxColor;

import haxe.ui.backend.flixel.UISubState;
import haxe.ui.components.Button;
import haxe.ui.components.HorizontalSlider;
import haxe.ui.components.Label;
import haxe.ui.components.NumberStepper;
import haxe.ui.containers.Box;
import haxe.ui.containers.HorizontalButtonBar;
import haxe.ui.containers.HBox;
import haxe.ui.containers.VBox;

import funkin.mobile.Hitbox;
import funkin.mobile.MobileUtil;
import funkin.objects.note.Note;

class HitboxCustomSubState extends UISubState
{
	public static final LANE_NAMES:Array<String> = ['Left', 'Down', 'Up', 'Right'];

	public static final MODES:Array<String> = ['Four Lanes', 'Arrows', 'D-Pad Left', 'D-Pad Right'];

	static inline final PANEL_WIDTH:Float = 390;

	static inline final GAP:Float = 16;

	public var onClosed:Null<Void->Void> = null;

	var uiCamera:FlxCamera;

	var colors:Array<FlxColor>;

	var selected:Int = 0;

	var previewX:Float = 0;

	var previewY:Float = 0;

	var previewWidth:Float = 0;

	var previewHeight:Float = 0;

	var previewBg:FlxSprite;

	var previewFrame:FlxSprite;

	var previewItems:Array<FlxSprite> = [];

	var lanes:Array<FlxSprite> = [];

	var previewLabel:FlxText;

	var noteAtlas:Null<flixel.graphics.frames.FlxAtlasFrames> = null;

	var modeBar:HorizontalButtonBar;

	var laneBar:HorizontalButtonBar;

	var colorBox:VBox;

	var lockedLabel:Label;

	var swatch:Box;

	var hexLabel:Label;

	var sliders:Array<HorizontalSlider> = [];

	var steppers:Array<NumberStepper> = [];

	var syncing:Bool = false;

	var backButton:Null<funkin.mobile.TouchButton> = null;

	override function create()
	{
		colors = [for (i in 0...4) getSavedColor(i)];

		uiCamera = MobileUtil.createCamera();
		cameras = [uiCamera];

		super.create();

		FlxG.mouse.visible = true;

		final shade = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		shade.setGraphicSize(FlxG.width, FlxG.height);
		shade.updateHitbox();
		shade.alpha = 0.75;
		shade.scrollFactor.set();
		insert(0, shade);

		final left = MobileUtil.leftEdge();
		final top = MobileUtil.topEdge();
		final panelLeft = MobileUtil.rightEdge() - PANEL_WIDTH;

		previewWidth = panelLeft - GAP - left;
		previewHeight = previewWidth * FlxG.height / FlxG.width;

		final maxHeight = MobileUtil.bottomEdge() - top - 40;
		if (previewHeight > maxHeight)
		{
			previewHeight = maxHeight;
			previewWidth = previewHeight * FlxG.width / FlxG.height;
		}

		previewX = left;
		previewY = top + (MobileUtil.bottomEdge() - top - previewHeight) / 2;

		final title = new FlxText(previewX, previewY - 34, previewWidth, 'Hitbox Preview', 24);
		title.setFormat(Paths.DEFAULT_FONT, 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		title.scrollFactor.set();
		add(title);

		previewFrame = new FlxSprite(previewX - 3, previewY - 3).makeGraphic(Std.int(previewWidth + 6), Std.int(previewHeight + 6), FlxColor.WHITE);
		previewFrame.scrollFactor.set();
		previewFrame.alpha = 0.85;
		add(previewFrame);

		previewBg = new FlxSprite(previewX, previewY).loadGraphic(Paths.image('menus/menuDesat'));
		previewBg.setGraphicSize(Std.int(previewWidth), Std.int(previewHeight));
		previewBg.updateHitbox();
		previewBg.setPosition(previewX, previewY);
		previewBg.color = 0xFF3C3555;
		previewBg.scrollFactor.set();
		add(previewBg);

		previewLabel = new FlxText(previewX, previewY + 10, previewWidth, '', 18);
		previewLabel.setFormat(Paths.DEFAULT_FONT, 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		previewLabel.scrollFactor.set();

		noteAtlas = Hitbox.loadNoteAtlas();

		buildPanel(panelLeft, top);

		#if mobile
		backButton = MobileUtil.createBackButton(uiCamera);
		add(backButton);
		#end

		rebuildPreview();
		refreshControls();
	}

	function buildPanel(x:Float, y:Float):Void
	{
		final panel = new VBox();
		panel.left = x;
		panel.top = y;
		panel.width = PANEL_WIDTH;
		panel.padding = 14;
		panel.verticalSpacing = 10;
		panel.backgroundColor = 0x1E1B2A;
		panel.borderColor = 0x8A6BD1;
		panel.borderSize = 2;
		panel.borderRadius = 8;

		panel.addComponent(makeLabel('HITBOX CUSTOM', 22));

		panel.addComponent(makeLabel('Hitbox Mode', 15));

		modeBar = new HorizontalButtonBar();
		modeBar.percentWidth = 100;
		for (mode in MODES)
			modeBar.addComponent(makeBarButton(mode == 'Four Lanes' ? 'Lanes' : mode == 'D-Pad Left' ? 'Pad L' : mode == 'D-Pad Right' ? 'Pad R' : mode));
		modeBar.selectedIndex = Std.int(Math.max(0, MODES.indexOf(ClientPrefs.hitboxMode)));
		modeBar.onChange = (_) -> {
			if (syncing || modeBar.selectedIndex < 0) return;
			ClientPrefs.hitboxMode = MODES[modeBar.selectedIndex];
			FlxG.sound.play(Paths.sound('scrollMenu'));
			rebuildPreview();
			refreshControls();
		};
		panel.addComponent(modeBar);

		lockedLabel = makeLabel('Colors can only be changed\nin Four Lanes mode.', 14);
		lockedLabel.styleString = 'color: #FFB347;';
		panel.addComponent(lockedLabel);

		colorBox = new VBox();
		colorBox.percentWidth = 100;
		colorBox.verticalSpacing = 8;

		colorBox.addComponent(makeLabel('Lane', 15));

		laneBar = new HorizontalButtonBar();
		laneBar.percentWidth = 100;
		for (name in LANE_NAMES)
			laneBar.addComponent(makeBarButton(name));
		laneBar.selectedIndex = selected;
		laneBar.onChange = (_) -> {
			if (syncing || laneBar.selectedIndex < 0) return;
			selectLane(laneBar.selectedIndex);
		};
		colorBox.addComponent(laneBar);

		final swatchRow = new HBox();
		swatchRow.percentWidth = 100;
		swatchRow.horizontalSpacing = 10;

		swatch = new Box();
		swatch.width = 56;
		swatch.height = 32;
		swatch.borderColor = 0xFFFFFF;
		swatch.borderSize = 2;
		swatch.borderRadius = 4;
		swatchRow.addComponent(swatch);

		hexLabel = makeLabel('#FFFFFF', 18);
		hexLabel.verticalAlign = 'center';
		swatchRow.addComponent(hexLabel);

		colorBox.addComponent(swatchRow);

		for (channel in 0...3)
			colorBox.addComponent(makeChannelRow(channel));

		final buttons = new HBox();
		buttons.percentWidth = 100;
		buttons.horizontalSpacing = 8;

		final resetLane = makeButton('Reset Lane');
		resetLane.onClick = (_) -> {
			colors[selected] = Hitbox.COLORS[selected];
			FlxG.sound.play(Paths.sound('cancelMenu'));
			applyColor();
		};
		buttons.addComponent(resetLane);

		final resetAll = makeButton('Reset All');
		resetAll.onClick = (_) -> {
			colors = Hitbox.COLORS.copy();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			for (i in 0...lanes.length)
				lanes[i].color = colors[i];
			applyColor();
		};
		buttons.addComponent(resetAll);

		colorBox.addComponent(buttons);
		panel.addComponent(colorBox);

		final done = makeButton('Save and Back');
		done.percentWidth = 100;
		done.onClick = (_) -> exit();
		panel.addComponent(done);

		add(panel);
	}

	function makeChannelRow(channel:Int):HBox
	{
		final row = new HBox();
		row.percentWidth = 100;
		row.horizontalSpacing = 8;

		final name = makeLabel(['R', 'G', 'B'][channel], 18);
		name.width = 22;
		name.verticalAlign = 'center';
		name.styleString = 'color: ' + ['#FF6B6B', '#6BFF8A', '#6BB5FF'][channel] + ';';
		row.addComponent(name);

		final slider = new HorizontalSlider();
		slider.min = 0;
		slider.max = 255;
		slider.step = 1;
		slider.precision = 0;
		slider.percentWidth = 100;
		slider.verticalAlign = 'center';
		slider.onChange = (_) -> {
			if (syncing) return;
			setChannel(channel, Math.round(slider.pos));
		};
		row.addComponent(slider);
		sliders.push(slider);

		final stepper = new NumberStepper();
		stepper.min = 0;
		stepper.max = 255;
		stepper.step = 1;
		stepper.precision = 0;
		stepper.width = 92;
		stepper.verticalAlign = 'center';
		stepper.onChange = (_) -> {
			if (syncing || stepper.pos == null) return;
			setChannel(channel, Math.round(stepper.pos));
		};
		row.addComponent(stepper);
		steppers.push(stepper);

		return row;
	}

	function makeLabel(text:String, size:Int):Label
	{
		final label = new Label();
		label.text = text;
		label.styleString = 'font-size: ${size}px;';
		return label;
	}

	function makeButton(text:String):Button
	{
		final button = new Button();
		button.text = text;
		button.percentWidth = 50;
		button.height = 40;
		return button;
	}

	function makeBarButton(text:String):Button
	{
		final button = new Button();
		button.text = text;
		button.percentWidth = 25;
		button.height = 40;
		return button;
	}

	function setChannel(channel:Int, value:Int):Void
	{
		var color = colors[selected];
		switch (channel)
		{
			case 0:
				color.red = value;
			case 1:
				color.green = value;
			default:
				color.blue = value;
		}
		color.alpha = 255;
		colors[selected] = color;
		applyColor();
	}

	function applyColor():Void
	{
		if (selected < lanes.length) lanes[selected].color = colors[selected];
		syncControls();
	}

	function selectLane(index:Int):Void
	{
		selected = index;
		FlxG.sound.play(Paths.sound('scrollMenu'));
		#if mobile
		funkin.mobile.Haptics.select();
		#end
		syncControls();
		highlightLanes();
	}

	function syncControls():Void
	{
		syncing = true;

		final color = colors[selected];
		final values = [color.red, color.green, color.blue];

		for (i in 0...3)
		{
			sliders[i].pos = values[i];
			steppers[i].pos = values[i];
		}

		if (laneBar.selectedIndex != selected) laneBar.selectedIndex = selected;

		swatch.backgroundColor = (color.rgb : Int);
		hexLabel.text = '#' + StringTools.hex((color.rgb : Int), 6);

		syncing = false;
	}

	function refreshControls():Void
	{
		final editable = ClientPrefs.hitboxMode == 'Four Lanes';

		colorBox.disabled = !editable;
		colorBox.opacity = editable ? 1 : 0.4;
		lockedLabel.hidden = editable;

		syncControls();
		highlightLanes();
	}

	function clearPreview():Void
	{
		for (item in previewItems)
		{
			remove(item, true);
			item.destroy();
		}

		previewItems = [];
		lanes = [];
		remove(previewLabel, true);
	}

	function addPreview(sprite:FlxSprite):FlxSprite
	{
		sprite.scrollFactor.set();
		previewItems.push(sprite);
		insert(members.indexOf(previewBg) + 1, sprite);
		return sprite;
	}

	function rebuildPreview():Void
	{
		clearPreview();

		final scale = previewWidth / FlxG.width;

		switch (ClientPrefs.hitboxMode)
		{
			case 'Arrows':
				final size = Std.int(Note.swagWidth * 1.12 * scale);
				final spots = funkin.game.modchart.ModManager.arrowsLayoutFour;
				for (i in 0...4)
				{
					final arrow = addPreview(new FlxSprite().loadGraphic(Hitbox.createDPadGraphic(size, Hitbox.COLORS[i], noteAtlas, Hitbox.DPAD_NOTES[i])));
					arrow.setPosition(previewX + previewWidth * spots[i] - size / 2, previewY + previewHeight - size - 30 * scale);
				}
				previewLabel.text = 'Tap the arrows at the bottom of the screen';

			case 'D-Pad Left' | 'D-Pad Right':
				final size = Std.int(Hitbox.dpadSize * scale);
				final gap = Hitbox.dpadGap * scale;
				final margin = MobileUtil.BUTTON_MARGIN * scale;
				final crossWidth = size * 3 + gap * 2;
				final originX = ClientPrefs.hitboxMode == 'D-Pad Right' ? previewX + previewWidth - margin - crossWidth : previewX + margin;
				final originY = previewY + previewHeight - margin - crossWidth;
				final offsets = [[0, 1], [1, 2], [1, 0], [2, 1]];

				for (i in 0...4)
				{
					final button = addPreview(new FlxSprite().loadGraphic(Hitbox.createDPadGraphic(size, Hitbox.COLORS[i], noteAtlas, Hitbox.DPAD_NOTES[i])));
					button.setPosition(originX + offsets[i][0] * (size + gap), originY + offsets[i][1] * (size + gap));
				}
				previewLabel.text = ClientPrefs.hitboxMode;

			default:
				final laneWidth = previewWidth / 4;
				for (i in 0...4)
				{
					final lane = addPreview(new FlxSprite().loadGraphic(Hitbox.createLaneGraphic(Std.int(laneWidth), Std.int(previewHeight), FlxColor.WHITE)));
					lane.setPosition(previewX + laneWidth * i, previewY);
					lane.color = colors[i];
					lanes.push(lane);
				}
				previewLabel.text = 'Tap a lane to edit its color';
		}

		add(previewLabel);
		highlightLanes();
	}

	function highlightLanes():Void
	{
		for (i in 0...lanes.length)
			lanes[i].alpha = i == selected ? 1 : 0.45;
	}

	var pulse:Float = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		pulse += elapsed;
		if (selected < lanes.length) lanes[selected].alpha = 0.8 + Math.sin(pulse * 5) * 0.2;

		if (lanes.length > 0 && FlxG.mouse.justPressed)
		{
			final point = FlxG.mouse.getViewPosition(uiCamera);
			if (point.x >= previewX && point.x < previewX + previewWidth && point.y >= previewY && point.y < previewY + previewHeight)
			{
				final index = Std.int(Math.min(3, (point.x - previewX) / (previewWidth / 4)));
				if (index != selected) selectLane(index);
			}
			point.put();
		}

		#if mobile
		if (backButton != null && backButton.touchJustPressed)
		{
			exit();
			return;
		}
		#end

		if (controls.BACK) exit();
	}

	var exiting:Bool = false;

	function exit():Void
	{
		if (exiting) return;
		exiting = true;

		ClientPrefs.hitboxColors = [for (color in colors) color];
		ClientPrefs.flush();
		FlxG.sound.play(Paths.sound('cancelMenu'));

		if (onClosed != null) onClosed();
		close();
	}

	override function destroy()
	{
		if (noteAtlas != null)
		{
			noteAtlas.destroy();
			noteAtlas = null;
		}

		super.destroy();

		if (uiCamera != null && FlxG.cameras.list.contains(uiCamera)) FlxG.cameras.remove(uiCamera);
	}

	public static function getSavedColor(index:Int):FlxColor
	{
		final saved = ClientPrefs.hitboxColors;
		if (saved != null && index < saved.length) return saved[index];
		return Hitbox.COLORS[index % Hitbox.COLORS.length];
	}
}
