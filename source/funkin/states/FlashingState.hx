package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.effects.FlxFlicker;
import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

class FlashingState extends MusicBeatState
{
	public static var leftState:Bool = false;
	
	var warnText:FlxText;
	
	#if mobile
	var disableText:FlxText;
	
	var ignoreText:FlxText;
	#end
	
	override function create()
	{
		super.create();
		
		var bg:FlxSprite = new FlxSprite().makeScaledGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);
		
		#if mobile
		warnText = new FlxText(0, 0, FlxG.width, "Hey, watch out!\n
			This Mod contains some flashing lights!\n
			Tap DISABLE to turn them off now or go to Options Menu.\n
			Tap IGNORE to keep them on.\n
			You've been warned!", 32);
		#else
		warnText = new FlxText(0, 0, FlxG.width, "Hey, watch out!\n
			This Mod contains some flashing lights!\n
			Press ENTER to disable them now or go to Options Menu.\n
			Press ESCAPE to ignore this message.\n
			You've been warned!", 32);
		#end
		warnText.setFormat(Paths.DEFAULT_FONT, 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		
		#if mobile
		warnText.y -= 70;
		
		disableText = createChoice('DISABLE', FlxG.width * 0.3, 0xFFFF5E5E);
		ignoreText = createChoice('IGNORE', FlxG.width * 0.7, FlxColor.WHITE);
		#end
		
		add(warnText);
	}
	
	#if mobile
	function createChoice(label:String, centerX:Float, color:FlxColor):FlxText
	{
		final choice = new FlxText(0, FlxG.height - 150, 340, label, 48);
		choice.setFormat(Paths.DEFAULT_FONT, 48, color, CENTER, OUTLINE, FlxColor.BLACK);
		choice.borderSize = 3;
		choice.x = centerX - choice.width / 2;
		add(choice);
		return choice;
	}
	#end
	
	override function update(elapsed:Float)
	{
		if (!leftState)
		{
			var accept = controls.ACCEPT;
			var back = controls.BACK;
			
			#if mobile
			if (funkin.mobile.TouchUtil.tapped)
			{
				accept = funkin.mobile.TouchUtil.tappedOn(disableText);
				back = back || funkin.mobile.TouchUtil.tappedOn(ignoreText);
			}
			#end
			
			if (accept || back)
			{
				#if mobile
				FlxTween.tween(disableText, {alpha: 0}, 0.4);
				FlxTween.tween(ignoreText, {alpha: 0}, 0.4);
				#end
				
				leftState = true;
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				if (!back)
				{
					ClientPrefs.flashing = false;
					ClientPrefs.flush();
					FlxG.sound.play(Paths.sound('confirmMenu'));
					
					FlxFlicker.flicker(warnText, 1, 0.1, false, true, function(flk:FlxFlicker) {
						new FlxTimer().start(0.5, function(tmr:FlxTimer) {
							FlxG.switchState(TitleState.new);
						});
					});
				}
				else
				{
					ClientPrefs.flashing = true;
					ClientPrefs.flush();
					FlxG.sound.play(Paths.sound('cancelMenu'));
					FlxTween.tween(warnText, {alpha: 0}, 1,
						{
							onComplete: function(twn:FlxTween) {
								FlxG.switchState(TitleState.new);
							}
						});
				}
			}
		}
		super.update(elapsed);
	}
}
