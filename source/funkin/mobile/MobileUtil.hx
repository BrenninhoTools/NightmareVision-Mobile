package funkin.mobile;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.util.FlxColor;

class MobileUtil
{
	public static inline final BUTTON_MARGIN:Float = 20;

	public static inline final BUTTON_SPACING:Float = 12;

	public static var buttonAlpha:Float = 0.75;

	public static var backScale:Float = 0.66;

	public static var pauseScale:Float = 0.85;

	public static var arrowScale:Float = 0.5;
	
	public static var optionsScale:Float = 0.55;

	public static function createCamera():FlxCamera
	{
		final camera = new FlxCamera();
		camera.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(camera, false);
		return camera;
	}

	public static function createButton(image:String, prefix:String, actions:Array<String>, scale:Float, ?camera:FlxCamera):TouchButton
	{
		final button = new TouchButton(0, 0, actions, 2).loadAtlas('mobile/$image', prefix);
		button.scale.set(scale, scale);
		button.updateHitbox();
		button.alpha = buttonAlpha;
		attachCamera(button, camera);
		return button;
	}

	public static function createBackButton(?camera:FlxCamera):TouchButton
	{
		final button = createButton('backButton', 'back', ['back'], backScale, camera);
		button.setPosition(FlxG.width - button.width - BUTTON_MARGIN, FlxG.height - button.height - BUTTON_MARGIN);
		return button;
	}

	public static function createPauseButton(?camera:FlxCamera):TouchButton
	{
		final button = createButton('pauseButton', 'pause', ['pause'], pauseScale, camera);
		button.setPosition(FlxG.width - button.width - BUTTON_MARGIN, BUTTON_MARGIN);
		return button;
	}

	public static function createArrowButtons(?camera:FlxCamera, ?rightEdge:Float, ?bottom:Float):{left:TouchButton, right:TouchButton}
	{
		camera ??= createCamera();

		final left = createButton('arrowLeftButton', 'arrowLeft', [], arrowScale, camera);
		final right = createButton('arrowRightButton', 'arrowRight', [], arrowScale, camera);

		final edge = rightEdge ?? FlxG.width - BUTTON_MARGIN;
		final base = bottom ?? FlxG.height - BUTTON_MARGIN;

		right.setPosition(edge - right.width, base - right.height);
		left.setPosition(right.x - BUTTON_SPACING - left.width, base - left.height);

		return {left: left, right: right};
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
