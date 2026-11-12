package funkin.mobile.android.util;

import funkin.mobile.backend.StorageUtil;
import funkin.mobile.haptics.Haptics;
import funkin.mobile.input.TouchButton;
import funkin.mobile.native.NativeUtil;
import funkin.mobile.util.MobileUtil;

import flixel.FlxCamera;
import flixel.FlxG;

class DataFolderUtil
{
	public static inline final STORAGE_TYPE:String = 'Data';

	public static inline final CONTENT_FOLDER:String = 'content';

	public static inline final ICON:String = 'mobile/folderButton';

	public static var buttonScale:Float = 0.6;

	public static var available(get, never):Bool;

	public static function open(?folder:String):Bool
	{
		#if android
		final opened = NativeUtil.openDataFolder(folder ?? CONTENT_FOLDER);
		if (!opened) NativeUtil.toast('Could not open the game folder');
		return opened;
		#else
		return false;
		#end
	}

	public static function createButton(?camera:FlxCamera):Null<TouchButton>
	{
		if (!available) return null;

		final button = new TouchButton(0, 0, [], 2);
		button.loadGraphic(Paths.image(ICON));
		button.scale.set(buttonScale, buttonScale);
		button.updateHitbox();
		button.alpha = MobileUtil.buttonAlpha;
		if (camera != null) button.cameras = [camera];

		button.onDown.add(() -> {
			button.scale.set(buttonScale * 0.9, buttonScale * 0.9);
			button.alpha = 1;
		});
		button.onUp.add(() -> {
			button.scale.set(buttonScale, buttonScale);
			button.alpha = MobileUtil.buttonAlpha;
			FlxG.sound.play(Paths.sound('scrollMenu'));
			Haptics.button();
			open(CONTENT_FOLDER);
		});

		MobileUtil.anchor(button, 0, 0.5);
		return button;
	}

	static function get_available():Bool
	{
		#if android
		return StorageUtil.getActiveStorageType() == STORAGE_TYPE;
		#else
		return false;
		#end
	}
}
