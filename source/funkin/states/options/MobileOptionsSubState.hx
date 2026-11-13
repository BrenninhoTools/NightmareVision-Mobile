package funkin.states.options;

import funkin.states.options.Option;
#if android
import funkin.mobile.backend.StorageUtil;
import funkin.mobile.RestartPrompt;
#end

class MobileOptionsSubState extends BaseOptionsMenu
{
	#if mobile
	var startScreenStyle:String = '';
	
	function applyScreenStyle():Bool
	{
		if (ClientPrefs.screenStyle == startScreenStyle) return false;
		
		startScreenStyle = ClientPrefs.screenStyle;
		ClientPrefs.flush();
		funkin.mobile.ui.ScreenStyle.apply(true);
		return true;
	}
	#end
	
	#if android
	var closeAfterPrompt:Bool = false;
	
	var prompted:Bool = false;
	#end
	
	var hitboxModeOption:Option;
	
	function openHitboxCustom():Void
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));
		
		final custom = new HitboxCustomSubState();
		custom.onClosed = () -> {
			if (hitboxModeOption.options != null)
			{
				hitboxModeOption.curOption = Std.int(Math.max(0, hitboxModeOption.options.indexOf(ClientPrefs.hitboxMode)));
				updateTextFrom(hitboxModeOption);
			}
			nextAccept = 5;
		};
		openSubState(custom);
	}
	
	public function new()
	{
		title = 'Mobile Options';
		rpcTitle = 'Mobile Options Menu';
		
		var option:Option = new Option('Restore Purchases', 'Restores anything you bought in the store on this account,\nthen goes back to the title screen.', 'hitboxMode', BUTTON);
		option.callback = () -> {
			FlxG.sound.play(Paths.sound('confirmMenu'));
			FlxG.switchState(() -> new funkin.mobile.states.RestorePurchasesState());
		};
		addOption(option);
		
		var option:Option = new Option('Hitbox Custom', 'Preview the hitbox, import an image, change its colors\nwith RGB and set its alpha.', 'hitboxMode', BUTTON);
		option.callback = openHitboxCustom;
		addOption(option);
		
		hitboxModeOption = new Option('Hitbox Mode', 'Four Lanes / Triangle / Circle: four touch areas. Arrows: tap the strums.\nD-Pad: a four note pad on the left, right or both sides.', 'hitboxMode', STRING, 'Four Lanes', funkin.mobile.util.Hitbox.MODES.copy());
		addOption(hitboxModeOption);
		
		var option:Option = new Option('Invisible Hitbox', 'If checked, the hitbox lanes stay invisible while you play,\nbut they still work.', 'invisibleHitbox', BOOL, false);
		addOption(option);
		
		var option:Option = new Option('Invisible Pause Button', 'If checked, the pause button is hidden during songs,\nbut tapping its corner still pauses.', 'invisiblePauseButton', BOOL, false);
		addOption(option);
		
		var option:Option = new Option('Chart Editor in Pause', 'If checked, the pause menu shows a Chart Editor option\nthat opens the current song in the chart editor.', 'chartEditorInPause', BOOL, true);
		addOption(option);
		
		#if android
		var option:Option = new Option('Screenshot Button', 'If checked, a camera button shows in the top right corner.\nTap it to save a screenshot to the gallery, hold it to share one.', 'screenshotButton', BOOL, false);
		addOption(option);
		#end
		
		var option:Option = new Option('Touch Cursor', 'If checked, a red cursor shows where your fingers\ntouch the screen.', 'touchCursor', BOOL, false);
		addOption(option);
		
		var option:Option = new Option('Haptics', 'If checked, the device vibrates when you hit notes,\ntap menu options and scroll with touch.', 'haptics', BOOL, true);
		option.onChange = () -> funkin.mobile.haptics.Haptics.preview(ClientPrefs.hapticsIntensity);
		addOption(option);
		
		var option:Option = new Option('Haptics Type', 'All: vibrates on notes, menus, buttons and touch.\nNotes: vibrates only when you hit or miss notes.', 'hapticsType', STRING, 'All', funkin.mobile.haptics.Haptics.TYPES.copy());
		option.onChange = () -> funkin.mobile.haptics.Haptics.preview(ClientPrefs.hapticsIntensity);
		addOption(option);
		
		var option:Option = new Option('Haptics Intensity', 'How strong the vibration feels.\nAbove 1.0 the vibrations also get longer.', 'hapticsIntensity', FLOAT, 0.6);
		option.displayFormat = '%vx';
		option.minValue = 0.1;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = () -> funkin.mobile.haptics.Haptics.preview(ClientPrefs.hapticsIntensity);
		addOption(option);
		
		var option:Option = new Option('Haptics Sensitivity', 'Low: vibrates only on note hits and buttons.\nMedium: also misses and taps. High: also every scroll and swipe.', 'hapticsSensitivity', STRING, 'Medium', funkin.mobile.haptics.Haptics.SENSITIVITIES);
		option.onChange = () -> funkin.mobile.haptics.Haptics.preview(ClientPrefs.hapticsIntensity);
		addOption(option);
		
		#if mobile
		startScreenStyle = ClientPrefs.screenStyle;
		
		var option:Option = new Option('Compressed Textures', 'Loads ASTC textures when the game has them, using less memory\nand loading faster. Turn off if images look wrong. Applies to new images.', 'astcTextures', BOOL, true);
		addOption(option);
		
		var option:Option = new Option('Screen Style', 'Original: classic 16:9 with black bars. Full: fills the whole screen without stretching.\nStretch: 16:9 stretched to fill the screen.', 'screenStyle', STRING, 'Original', funkin.mobile.ui.ScreenStyle.STYLES);
		option.onChange = () -> funkin.mobile.ui.ScreenStyle.apply(false);
		addOption(option);
		
		var option:Option = new Option('Battery Saver', 'Off: never saves battery. Auto: turns on when the battery is low, the phone saver is on\nor the phone is hot. On: always. Now: ' + funkin.mobile.power.BatterySaver.describe() + '.',
			'batterySaver', STRING, 'Auto', funkin.mobile.power.BatterySaver.MODES);
		option.onChange = funkin.mobile.power.BatterySaver.refresh;
		addOption(option);
		
		var option:Option = new Option('Battery Saver Level', 'In Auto, the saver turns on when the battery drops to this percent\nand you are not charging.', 'batterySaverLevel', INT, 20);
		option.scrollSpeed = 20;
		option.minValue = 5;
		option.maxValue = 50;
		option.changeValue = 5;
		option.displayFormat = '%v%';
		option.onChange = funkin.mobile.power.BatterySaver.refresh;
		addOption(option);
		
		#end
		
		#if android
		ClientPrefs.storageType = StorageUtil.getStorageType();
		
		var option:Option = new Option('Storage Type', 'Where the game files are kept. Data: Android/data, External: NightmareVision folder,\nMedia: Android/media, Obb: Android/obb. Current: ' + StorageUtil.getInfo() + '.',
			'storageType', STRING, StorageUtil.DEFAULT_STORAGE_TYPE, StorageUtil.STORAGE_TYPES);
		option.onChange = onStorageTypeChange;
		addOption(option);
		#end
		
		#if mobile
		if (!funkin.mobile.native.AdUtil.removed)
		{
			var option:Option = new Option('Ads Status', 'Shows what the ads are doing. Press to reload them.\n' + funkin.mobile.native.AdUtil.status(), 'storageType', BUTTON);
			option.callback = () -> {
				FlxG.sound.play(Paths.sound('confirmMenu'));
				funkin.mobile.native.AdUtil.retryNow();
			};
			addOption(option);
		}
		
		if (funkin.mobile.native.AdUtil.enabled)
		{
			final minutes = Std.int(funkin.mobile.native.AdUtil.adBreakMinutes);
			final left = funkin.mobile.native.AdUtil.breakMinutesLeft;
			var option:Option = new Option('Ad Break', 'Watch one rewarded ad to play ' + minutes + ' minutes without any ads.'
				+ (left > 0 ? '\nAd break active: ' + left + ' minutes left.' : '\nThe time adds up if you watch more than one.'), 'storageType', BUTTON);
			option.callback = () -> {
				funkin.mobile.native.AdUtil.watchForBreak((earned) -> {
					FlxG.sound.play(Paths.sound(earned ? 'confirmMenu' : 'cancelMenu'));
					if (earned) funkin.mobile.haptics.Haptics.confirm();
				});
			};
			addOption(option);
		}
		
		if (funkin.mobile.native.AdUtil.privacyOptionsRequired())
		{
			var option:Option = new Option('Ad Privacy Options', 'Opens the ad consent form so you can change\nhow your data is used for ads.', 'storageType', BUTTON);
			option.callback = () -> {
				FlxG.sound.play(Paths.sound('confirmMenu'));
				funkin.mobile.native.AdUtil.showPrivacyOptions();
			};
			addOption(option);
		}
		
		var option:Option = new Option('Rate the Game', 'Opens the store review screen so you can rate the game.', 'storageType', BUTTON);
		option.callback = () -> {
			FlxG.sound.play(Paths.sound('confirmMenu'));
			funkin.mobile.native.ReviewUtil.request(true);
		};
		addOption(option);
		
		var option:Option = new Option('Repair Game Files', 'Checks every game file again and copies back anything\nthat is missing or broken. Your mods are kept.', 'storageType', BUTTON);
		option.callback = funkin.mobile.backend.StorageUtil.repair;
		addOption(option);
		#end
		
		super();
	}
	
	#if android
	function onStorageTypeChange():Void
	{
		StorageUtil.setStorageType(ClientPrefs.storageType);
	}
	
	override function update(elapsed:Float)
	{
		if (closeAfterPrompt && subState == null)
		{
			closeAfterPrompt = false;
			finishClose();
			return;
		}
		
		super.update(elapsed);
	}
	
	override function close()
	{
		if (prompted || !StorageUtil.needsRestart())
		{
			finishClose();
			return;
		}
		
		prompted = true;
		
		final type = StorageUtil.getStorageType();
		final available = StorageUtil.isStorageTypeAvailable(type);
		final text = available ? 'Restart now to move the game\nfiles to $type storage?' : '$type storage is not available yet.\nGrant the storage permission and restart,\nor the game will keep using ${StorageUtil.getActiveStorageType()}.';
		
		openSubState(new RestartPrompt(text, StorageUtil.restartApp, () -> closeAfterPrompt = true));
	}
	#elseif mobile
	override function close()
	{
		finishClose();
	}
	#end
	
	#if mobile
	function finishClose():Void
	{
		super.close();
		applyScreenStyle();
	}
	#end
}
