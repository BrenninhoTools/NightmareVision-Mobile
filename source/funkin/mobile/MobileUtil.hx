package funkin.mobile;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.util.FlxColor;

class MobileUtil
{
	public static inline final BUTTON_MARGIN:Float = 20;

	public static var buttonAlpha:Float = 0.75;

	public static function createCamera():FlxCamera
	{
		final camera = new FlxCamera();
		camera.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(camera, false);
		return camera;
	}

	public static function createBackButton(?camera:FlxCamera):TouchButton
	{
		final button = new TouchButton(0, 0, ['back'], 2).loadAtlas('mobile/backButton', 'back');
		button.scale.set(0.55, 0.55);
		button.updateHitbox();
		button.setPosition(FlxG.width - button.width - BUTTON_MARGIN, FlxG.height - button.height - BUTTON_MARGIN);
		button.alpha = buttonAlpha;
		attachCamera(button, camera);
		return button;
	}

	public static function createPauseButton(?camera:FlxCamera):TouchButton
	{
		final button = new TouchButton(0, 0, ['pause'], 2).loadAtlas('mobile/pauseButton', 'pause');
		button.scale.set(0.85, 0.85);
		button.updateHitbox();
		button.setPosition(FlxG.width - button.width - BUTTON_MARGIN, BUTTON_MARGIN);
		button.alpha = buttonAlpha;
		attachCamera(button, camera);
		return button;
	}

	static function attachCamera(button:TouchButton, ?camera:FlxCamera):Void
	{
		if (camera == null)
		{
			camera = createCamera();
			button.ownedCamera = camera;
		}

		button.cameras = [camera];
	}
}
