package funkin.mobile.util;

import funkin.mobile.ui.ScreenStyle;
import funkin.mobile.input.TouchButton;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.util.FlxColor;

typedef AnchorInfo =
{
	var object:FlxObject;
	var horizontal:Float;
	var vertical:Float;
	var offsetX:Float;
	var offsetY:Float;
}

class MobileUtil
{
	static final anchors:Array<AnchorInfo> = [];

	static var anchorsHooked:Bool = false;

	public static var uiScale(get, never):Float;

	public static var safeWidth(get, never):Float;

	public static var safeHeight(get, never):Float;

	public static function anchor(object:FlxObject, horizontal:Float, vertical:Float, offsetX:Float = 0, offsetY:Float = 0, track:Bool = true):FlxObject
	{
		if (object == null) return object;

		placeAnchored(object, horizontal, vertical, offsetX, offsetY);
		if (!track) return object;

		hookAnchors();

		for (info in anchors)
		{
			if (info.object == object)
			{
				info.horizontal = horizontal;
				info.vertical = vertical;
				info.offsetX = offsetX;
				info.offsetY = offsetY;
				return object;
			}
		}

		anchors.push({object: object, horizontal: horizontal, vertical: vertical, offsetX: offsetX, offsetY: offsetY});
		return object;
	}

	public static function release(object:FlxObject):Void
	{
		var index = anchors.length;
		while (index-- > 0)
			if (anchors[index].object == object) anchors.splice(index, 1);
	}

	public static function refreshAnchors():Void
	{
		var index = anchors.length;
		while (index-- > 0)
		{
			final info = anchors[index];
			if (info.object == null || !info.object.exists)
			{
				anchors.splice(index, 1);
				continue;
			}

			placeAnchored(info.object, info.horizontal, info.vertical, info.offsetX, info.offsetY);
		}
	}

	static function placeAnchored(object:FlxObject, horizontal:Float, vertical:Float, offsetX:Float, offsetY:Float):Void
	{
		final left = leftEdge();
		final top = topEdge();
		object.x = left + (rightEdge() - object.width - left) * horizontal + offsetX;
		object.y = top + (bottomEdge() - object.height - top) * vertical + offsetY;
	}

	static function hookAnchors():Void
	{
		if (anchorsHooked) return;
		anchorsHooked = true;

		ScreenStyle.onChange.add(refreshAnchors);
		FlxG.signals.gameResized.add((_, _) -> refreshAnchors());
		FlxG.signals.preStateSwitch.add(() -> anchors.resize(0));
	}

	public static function fadeButtons(buttons:Array<TouchButton>, alpha:Float, duration:Float = 0.2):Void
	{
		for (button in buttons)
		{
			if (button == null || !button.exists) continue;
			FlxTween.cancelTweensOf(button, ['alpha']);
			FlxTween.tween(button, {alpha: alpha}, duration, {ease: FlxEase.quadOut});
		}
	}

	public static function scaled(value:Float):Float
	{
		return value * uiScale;
	}

	static function get_uiScale():Float
	{
		final stage = FlxG.stage;
		if (stage == null || stage.stageHeight <= 0) return 1;

		final inches = stage.stageHeight / Math.max(1, lime.system.System.getDisplay(0)?.dpi ?? 160);
		return inches < 2.6 ? 1.15 : (inches > 4.5 ? 0.9 : 1);
	}

	static function get_safeWidth():Float
	{
		return rightEdge() - leftEdge();
	}

	static function get_safeHeight():Float
	{
		return bottomEdge() - topEdge();
	}

	public static inline final BUTTON_MARGIN:Float = 20;

	public static inline final BUTTON_SPACING:Float = 12;

	public static var buttonAlpha:Float = 0.75;

	public static var backScale:Float = 0.66;

	public static var pauseScale:Float = 0.85;

	public static var arrowScale:Float = 0.5;
	
	public static var optionsScale:Float = 0.55;

	public static function leftEdge():Float
	{
		return BUTTON_MARGIN + ScreenStyle.safeLeft;
	}
	
	public static function rightEdge():Float
	{
		return FlxG.width - BUTTON_MARGIN - ScreenStyle.safeRight;
	}
	
	public static function topEdge():Float
	{
		return BUTTON_MARGIN + ScreenStyle.safeTop;
	}
	
	public static function bottomEdge():Float
	{
		return FlxG.height - BUTTON_MARGIN - ScreenStyle.safeBottom;
	}
	
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
		button.persistent = true;
		anchor(button, 1, 1);
		return button;
	}

	public static function createPauseButton(?camera:FlxCamera):TouchButton
	{
		final button = createButton('pauseButton', 'pause', ['pause'], pauseScale, camera);
		anchor(button, 1, 0);
		return button;
	}

	public static function createArrowButtons(?camera:FlxCamera, ?rightEdge:Float, ?bottom:Float):{left:TouchButton, right:TouchButton}
	{
		camera ??= createCamera();

		final left = createButton('arrowLeftButton', 'arrowLeft', [], arrowScale, camera);
		final right = createButton('arrowRightButton', 'arrowRight', [], arrowScale, camera);

		if (rightEdge == null && bottom == null)
		{
			anchor(right, 1, 1);
			anchor(left, 1, 1, -(right.width + BUTTON_SPACING), 0);
			return {left: left, right: right};
		}

		final edge = rightEdge ?? MobileUtil.rightEdge();
		final base = bottom ?? bottomEdge();

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
