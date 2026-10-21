package funkin.states.options;

import funkin.states.options.Option;
#if android
import funkin.mobile.StorageUtil;
import funkin.mobile.RestartPrompt;
#end

class MobileOptionsSubState extends BaseOptionsMenu
{
	#if android
	var closeAfterPrompt:Bool = false;
	
	var prompted:Bool = false;
	#end
	
	public function new()
	{
		title = 'Mobile Options';
		rpcTitle = 'Mobile Options Menu';
		
		var option:Option = new Option('Invisible Hitbox', 'If checked, the hitbox lanes stay invisible while you play,\nbut they still work.', 'invisibleHitbox', BOOL, false);
		addOption(option);
		
		var option:Option = new Option('Invisible Pause Button', 'If checked, the pause button is hidden during songs,\nbut tapping its corner still pauses.', 'invisiblePauseButton', BOOL, false);
		addOption(option);
		
		var option:Option = new Option('Haptics', 'If checked, the device vibrates when you hit notes,\ntap menu options and scroll with touch.', 'haptics', BOOL, true);
		option.onChange = () -> funkin.mobile.Haptics.preview(ClientPrefs.hapticsIntensity);
		addOption(option);
		
		var option:Option = new Option('Haptics Intensity', 'How strong the vibration feels.', 'hapticsIntensity', PERCENT, 0.6);
		option.minValue = 0.1;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = () -> funkin.mobile.Haptics.preview(ClientPrefs.hapticsIntensity);
		addOption(option);
		
		#if android
		ClientPrefs.storageType = StorageUtil.getStorageType();
		
		var option:Option = new Option('Storage Type', 'Where the game files are kept. Data: Android/data, External: NightmareVision folder,\nMedia: Android/media, Obb: Android/obb. Current: ' + StorageUtil.getInfo() + '.',
			'storageType', STRING, StorageUtil.DEFAULT_STORAGE_TYPE, StorageUtil.STORAGE_TYPES);
		option.onChange = onStorageTypeChange;
		addOption(option);
		#end
		
		#if mobile
		var option:Option = new Option('Repair Game Files', 'Checks every game file again and copies back anything\nthat is missing or broken. Your mods are kept.', 'storageType', BUTTON);
		option.callback = funkin.mobile.StorageUtil.repair;
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
			super.close();
			return;
		}
		
		super.update(elapsed);
	}
	
	override function close()
	{
		if (prompted || !StorageUtil.needsRestart())
		{
			super.close();
			return;
		}
		
		prompted = true;
		
		final type = StorageUtil.getStorageType();
		final available = StorageUtil.isStorageTypeAvailable(type);
		final text = available ? 'Restart now to move the game\nfiles to $type storage?' : '$type storage is not available yet.\nGrant the storage permission and restart,\nor the game will keep using ${StorageUtil.getActiveStorageType()}.';
		
		openSubState(new RestartPrompt(text, StorageUtil.restartApp, () -> closeAfterPrompt = true));
	}
	#end
}
