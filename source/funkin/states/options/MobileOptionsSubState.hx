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
		
		#if android
		ClientPrefs.storageType = StorageUtil.getStorageType();
		
		var option:Option = new Option('Storage Type', 'Where the game files are kept. Data: Android/data, External: NightmareVision folder,\nMedia: Android/media, Obb: Android/obb. Current: ' + StorageUtil.getActiveStorageType() + '.',
			'storageType', STRING, StorageUtil.DEFAULT_STORAGE_TYPE, StorageUtil.STORAGE_TYPES);
		option.onChange = onStorageTypeChange;
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
