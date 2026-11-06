package funkin.states.options;

import openfl.display.BitmapData;

import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.util.FlxColor;

import haxe.ui.backend.flixel.UISubState;
import haxe.ui.components.Button;
import haxe.ui.components.HorizontalSlider;
import haxe.ui.components.Label;
import haxe.ui.components.NumberStepper;
import haxe.ui.containers.Box;
import haxe.ui.containers.Grid;
import haxe.ui.containers.HBox;
import haxe.ui.containers.HorizontalButtonBar;
import haxe.ui.containers.VBox;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;

import funkin.mobile.Hitbox;
import funkin.mobile.MobileUtil;
import funkin.objects.note.Note;

class HitboxCustomSubState extends UISubState
{
	public static final LANE_NAMES:Array<String> = ['Left', 'Down', 'Up', 'Right'];

	public static final MODE_LABELS:Array<String> = ['Lanes', 'Triangle', 'Arrows', 'Pad Left', 'Pad Right', 'Double Pad'];

	public static final IMAGE_EXTENSIONS:Array<String> = ['png', 'jpg', 'jpeg'];

	static inline final PANEL_WIDTH:Float = 400;

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

	var previewItems:Array<FlxSprite> = [];

	var lanes:Array<FlxSprite> = [];

	var previewLabel:FlxText;

	var noteAtlas:Null<flixel.graphics.frames.FlxAtlasFrames> = null;

	var customImage:Null<BitmapData> = null;

	var panel:VBox;

	var menuPage:VBox;

	var rgbPage:VBox;

	var modeButtons:Array<Button> = [];

	var alphaSlider:HorizontalSlider;

	var alphaLabel:Label;

	var laneBar:HorizontalButtonBar;

	var statusLabel:Label;

	var imageButton:Button;

	var rgbButton:Button;

	var rgbNotice:Label;

	var colorBox:VBox;

	var swatch:Box;

	var hexLabel:Label;

	var sliders:Array<HorizontalSlider> = [];

	var steppers:Array<NumberStepper> = [];

	var syncing:Bool = false;

	var picking:Bool = false;

	var exiting:Bool = false;

	var pulse:Float = 0;

	var backButton:Null<funkin.mobile.TouchButton> = null;

	override function create()
	{
		colors = [for (i in 0...4) getSavedColor(i)];
		customImage = Hitbox.loadCustomImage();

		uiCamera = MobileUtil.createCamera();
		cameras = [uiCamera];

		super.create();

		FlxG.mouse.visible = true;

		final shade = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		shade.setGraphicSize(FlxG.width, FlxG.height);
		shade.updateHitbox();
		shade.alpha = 0.8;
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

		final frame = new FlxSprite(previewX - 3, previewY - 3).makeGraphic(Std.int(previewWidth + 6), Std.int(previewHeight + 6), FlxColor.WHITE);
		frame.scrollFactor.set();
		frame.alpha = 0.85;
		add(frame);

		previewBg = new FlxSprite().loadGraphic(Paths.image('menus/menuDesat'));
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
		showPage(false);
	}

	function buildPanel(x:Float, y:Float):Void
	{
		panel = new VBox();
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

		menuPage = buildMenuPage();
		panel.addComponent(menuPage);

		rgbPage = buildRgbPage();
		panel.addComponent(rgbPage);

		Screen.instance.addComponent(panel);
		if (!members.contains(panel)) add(panel);
		panel.cameras = [uiCamera];
	}

	function buildMenuPage():VBox
	{
		final page = new VBox();
		page.percentWidth = 100;
		page.verticalSpacing = 10;

		page.addComponent(makeLabel('Hitbox Mode', 15));

		final modeGrid = new Grid();
		modeGrid.columns = 3;
		modeGrid.percentWidth = 100;
		modeGrid.horizontalSpacing = 6;
		modeGrid.verticalSpacing = 6;
		for (index => mode in Hitbox.MODES)
		{
			final button = new Button();
			button.text = MODE_LABELS[index];
			button.toggle = true;
			button.percentWidth = 33;
			button.height = 40;
			button.onClick = (_) -> setMode(mode);
			modeGrid.addComponent(button);
			modeButtons.push(button);
		}
		page.addComponent(modeGrid);
		syncModeButtons();

		alphaLabel = makeLabel('', 15);
		page.addComponent(alphaLabel);

		alphaSlider = new HorizontalSlider();
		alphaSlider.min = 0;
		alphaSlider.max = 100;
		alphaSlider.step = 5;
		alphaSlider.precision = 0;
		alphaSlider.percentWidth = 100;
		alphaSlider.pos = Math.round(ClientPrefs.hitboxAlpha * 100);
		alphaSlider.onChange = (_) -> {
			if (syncing) return;
			ClientPrefs.hitboxAlpha = Math.round(alphaSlider.pos) / 100;
			updateAlphaLabel();
			highlightLanes();
		};
		page.addComponent(alphaSlider);
		updateAlphaLabel();

		imageButton = makeButton('Import Hitbox Image');
		imageButton.onClick = (_) -> importImage();
		page.addComponent(imageButton);

		rgbButton = makeButton('RGB Hitbox');
		rgbButton.onClick = (_) -> {
			FlxG.sound.play(Paths.sound('scrollMenu'));
			showPage(true);
		};
		page.addComponent(rgbButton);

		final reset = makeButton('Reset Hitbox');
		reset.onClick = (_) -> resetHitbox();
		page.addComponent(reset);

		statusLabel = makeLabel('', 14);
		statusLabel.percentWidth = 100;
		page.addComponent(statusLabel);

		final done = makeButton('Save and Back');
		page.addComponent(done);
		done.onClick = (_) -> exit();

		return page;
	}

	function buildRgbPage():VBox
	{
		final page = new VBox();
		page.percentWidth = 100;
		page.verticalSpacing = 8;

		page.addComponent(makeLabel('RGB Hitbox', 18));

		rgbNotice = makeLabel('', 14);
		rgbNotice.percentWidth = 100;
		rgbNotice.styleString = 'font-size: 14px; color: #FFB347;';
		page.addComponent(rgbNotice);

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
		resetLane.percentWidth = 50;
		resetLane.onClick = (_) -> {
			colors[selected] = Hitbox.COLORS[selected];
			FlxG.sound.play(Paths.sound('cancelMenu'));
			applyColor();
		};
		buttons.addComponent(resetLane);

		final resetColors = makeButton('Reset Colors');
		resetColors.percentWidth = 50;
		resetColors.onClick = (_) -> {
			colors = Hitbox.COLORS.copy();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			rebuildPreview();
			syncControls();
		};
		buttons.addComponent(resetColors);

		colorBox.addComponent(buttons);
		page.addComponent(colorBox);

		final back = makeButton('Back');
		back.onClick = (_) -> {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			showPage(false);
		};
		page.addComponent(back);

		return page;
	}

	function makeChannelRow(channel:Int):HBox
	{
		final row = new HBox();
		row.percentWidth = 100;
		row.horizontalSpacing = 8;

		final name = makeLabel(['R', 'G', 'B'][channel], 18);
		name.width = 22;
		name.verticalAlign = 'center';
		name.styleString = 'font-size: 18px; color: ' + ['#FF6B6B', '#6BFF8A', '#6BB5FF'][channel] + ';';
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
		button.percentWidth = 100;
		button.height = 44;
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

	function setMode(mode:String):Void
	{
		if (ClientPrefs.hitboxMode != mode)
		{
			ClientPrefs.hitboxMode = mode;
			FlxG.sound.play(Paths.sound('scrollMenu'));
			#if mobile
			funkin.mobile.Haptics.select();
			#end
			rebuildPreview();
			refreshControls();
		}

		syncModeButtons();
	}

	function syncModeButtons():Void
	{
		syncing = true;
		for (index => button in modeButtons)
			button.selected = Hitbox.MODES[index] == ClientPrefs.hitboxMode;
		syncing = false;
	}

	function updateAlphaLabel():Void
	{
		alphaLabel.text = 'Hitbox Alpha: ' + Math.round(ClientPrefs.hitboxAlpha * 100) + '%';
	}

	function colorsEditable():Bool
	{
		final mode = ClientPrefs.hitboxMode;
		return mode == 'Triangle' || (mode == 'Four Lanes' && customImage == null);
	}

	function showPage(rgb:Bool):Void
	{
		menuPage.hidden = rgb;
		rgbPage.hidden = !rgb;
		refreshControls();
	}

	function setStatus(text:String):Void
	{
		statusLabel.text = text;
	}

	function importImage():Void
	{
		if (picking) return;

		picking = true;
		FlxG.sound.play(Paths.sound('scrollMenu'));
		setStatus('Choose an image...');

		funkin.utils.FileUtil.browseForFile({
			title: 'Import Hitbox Image',
			typeFilter: [new openfl.net.FileFilter('Images', '*.png;*.jpg;*.jpeg')]
		}, (path) -> {
			picking = false;
			onImagePicked(path);
		}, () -> {
			picking = false;
			setStatus('');
		});
	}

	function onImagePicked(path:Null<String>):Void
	{
		#if sys
		if (path == null || !sys.FileSystem.exists(path))
		{
			denied('Could not open that image.');
			return;
		}

		var image:Null<BitmapData> = null;
		try
		{
			image = BitmapData.fromBytes(sys.io.File.getBytes(path));
		}
		catch (e:Dynamic) {}

		if (image == null || image.width <= 0 || image.height <= 0)
		{
			denied('That file is not a supported image.');
			return;
		}

		final extension = haxe.io.Path.extension(path).toLowerCase();
		final target = haxe.io.Path.join([Hitbox.CUSTOM_IMAGE_FOLDER, 'hitbox.' + (IMAGE_EXTENSIONS.contains(extension) ? extension : 'png')]);

		try
		{
			if (!sys.FileSystem.exists(Hitbox.CUSTOM_IMAGE_FOLDER)) sys.FileSystem.createDirectory(Hitbox.CUSTOM_IMAGE_FOLDER);

			for (old in IMAGE_EXTENSIONS)
			{
				final oldPath = haxe.io.Path.join([Hitbox.CUSTOM_IMAGE_FOLDER, 'hitbox.' + old]);
				if (oldPath != target && sys.FileSystem.exists(oldPath)) sys.FileSystem.deleteFile(oldPath);
			}

			if (haxe.io.Path.normalize(sys.FileSystem.absolutePath(path)) != haxe.io.Path.normalize(sys.FileSystem.absolutePath(target))) sys.io.File.copy(path, target);
		}
		catch (e:Dynamic)
		{
			image.dispose();
			denied('Could not save the image.');
			return;
		}

		ClientPrefs.hitboxImage = target;
		ClientPrefs.flush();

		if (customImage != null) customImage.dispose();
		customImage = image;

		if (ClientPrefs.hitboxMode != 'Four Lanes')
		{
			ClientPrefs.hitboxMode = 'Four Lanes';
			syncModeButtons();
		}

		FlxG.sound.play(Paths.sound('confirmMenu'));
		#if mobile
		funkin.mobile.Haptics.button();
		#end

		rebuildPreview();
		refreshControls();
		setStatus('Image imported.');
		#else
		denied('Importing images is not supported here.');
		#end
	}

	function resetHitbox():Void
	{
		colors = Hitbox.COLORS.copy();
		ClientPrefs.hitboxColors = Hitbox.COLORS.copy();

		#if sys
		final path = Hitbox.getCustomImagePath();
		if (path != null)
		{
			try
			{
				sys.FileSystem.deleteFile(path);
			}
			catch (e:Dynamic) {}
		}
		#end

		ClientPrefs.hitboxImage = '';
		ClientPrefs.hitboxAlpha = 1;
		ClientPrefs.flush();

		syncing = true;
		alphaSlider.pos = 100;
		syncing = false;
		updateAlphaLabel();

		if (customImage != null)
		{
			customImage.dispose();
			customImage = null;
		}

		FlxG.sound.play(Paths.sound('cancelMenu'));
		#if mobile
		funkin.mobile.Haptics.button();
		#end

		rebuildPreview();
		refreshControls();
		setStatus('Hitbox reset to default.');
	}

	function denied(message:String):Void
	{
		FlxG.sound.play(Paths.sound('cancelMenu'));
		#if mobile
		funkin.mobile.Haptics.denied();
		#end
		setStatus(message);
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
		if (colorsEditable() && selected < lanes.length) lanes[selected].color = colors[selected];
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
		final editable = colorsEditable();

		if (!Hitbox.usesColors(ClientPrefs.hitboxMode)) rgbNotice.text = 'Colors can only be changed\nin Four Lanes or Triangle mode.';
		else if (customImage != null) rgbNotice.text = 'A custom image is in use.\nUse Reset Hitbox to use colors again.';
		else rgbNotice.text = '';

		rgbNotice.hidden = editable;
		colorBox.disabled = !editable;
		colorBox.opacity = editable ? 1 : 0.4;

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
		previewTriangle = false;
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

			case 'D-Pad Left' | 'D-Pad Right' | 'Double D-Pad':
				final size = Std.int(Hitbox.dpadSize * scale);
				final sides = ClientPrefs.hitboxMode == 'Double D-Pad' ? [false, true] : [ClientPrefs.hitboxMode == 'D-Pad Right'];

				for (onRight in sides)
				{
					for (i in 0...4)
					{
						final position = Hitbox.dpadPosition(i, onRight);
						final button = addPreview(new FlxSprite().loadGraphic(Hitbox.createDPadGraphic(size, Hitbox.COLORS[i], noteAtlas, Hitbox.DPAD_NOTES[i])));
						button.setPosition(previewX + position[0] * scale, previewY + position[1] * scale);
					}
				}
				previewLabel.text = ClientPrefs.hitboxMode;

			case 'Triangle':
				previewTriangle = true;
				for (i in 0...4)
				{
					final bounds = Hitbox.triangleBounds(i, previewWidth, previewHeight);
					final lane = addPreview(new FlxSprite().loadGraphic(Hitbox.createTriangleGraphic(i, previewWidth, previewHeight, FlxColor.WHITE)));
					lane.setPosition(previewX + bounds.x, previewY + bounds.y);
					lane.color = colors[i];
					lanes.push(lane);
				}
				previewLabel.text = 'Tap a triangle to edit its color';

			default:
				final width = Std.int(previewWidth);
				final height = Std.int(previewHeight);
				final laneWidth = Math.floor(width / 4);
				for (i in 0...4)
				{
					final sliceWidth = i == 3 ? width - laneWidth * 3 : laneWidth;
					final graphic = customImage != null ? Hitbox.sliceImage(customImage, i, 4, width, height) : Hitbox.createLaneGraphic(sliceWidth, height, FlxColor.WHITE);
					final lane = addPreview(new FlxSprite().loadGraphic(graphic));
					lane.setPosition(previewX + laneWidth * i, previewY);
					lane.color = customImage != null ? FlxColor.WHITE : colors[i];
					lanes.push(lane);
				}
				previewLabel.text = customImage != null ? 'Custom image hitbox' : 'Tap a lane to edit its color';
		}

		add(previewLabel);
		highlightLanes();
	}

	var previewTriangle:Bool = false;

	function highlightLanes():Void
	{
		final rgbOpen = rgbPage != null && !rgbPage.hidden;
		final multiplier = ClientPrefs.hitboxAlpha;

		for (item in previewItems)
			item.alpha = multiplier;

		for (i in 0...lanes.length)
			lanes[i].alpha = (!rgbOpen || i == selected ? 1 : 0.45) * multiplier;
	}

	function previewLaneAt(x:Float, y:Float):Int
	{
		final localX = x - previewX;
		final localY = y - previewY;
		if (localX < 0 || localY < 0 || localX >= previewWidth || localY >= previewHeight) return -1;

		if (previewTriangle)
		{
			for (i in 0...4)
				if (Hitbox.triangleContains(i, localX, localY, previewWidth, previewHeight)) return i;
			return -1;
		}

		return Std.int(Math.min(3, localX / (previewWidth / 4)));
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (picking) return;

		final rgbOpen = !rgbPage.hidden;

		pulse += elapsed;
		if (rgbOpen && selected < lanes.length) lanes[selected].alpha = (0.8 + Math.sin(pulse * 5) * 0.2) * ClientPrefs.hitboxAlpha;

		if (lanes.length > 0 && FlxG.mouse.justPressed)
		{
			final point = FlxG.mouse.getViewPosition(uiCamera);
			final index = previewLaneAt(point.x, point.y);
			if (index >= 0)
			{
				if (!rgbOpen && colorsEditable())
				{
					selected = index;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					showPage(true);
				}
				else if (rgbOpen && index != selected) selectLane(index);
			}
			point.put();
		}

		if (controls.BACK)
		{
			if (rgbOpen)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				showPage(false);
			}
			else exit();
		}
	}

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
		if (panel != null) Screen.instance.removeComponent(panel, false);

		if (noteAtlas != null)
		{
			noteAtlas.destroy();
			noteAtlas = null;
		}

		if (customImage != null)
		{
			customImage.dispose();
			customImage = null;
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
