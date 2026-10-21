package;

import funkin.FunkinAssets;

import flixel.FlxState;
import flixel.FlxG;
import flixel.input.keyboard.FlxKey;

import funkin.backend.math.Vector3;

/**
 * Initiation state that prepares backend classes and returns to menus when finished
 * 
 * There is no need to open this beyond the first time
 */
@:nullSafety(Strict)
class Init extends FlxState
{
	override public function create():Void
	{
		// load settings/save
		step('controls');
		funkin.input.Controls.init();
		
		#if mobile
		funkin.mobile.TouchInput.init();
		#end
		
		step('prefs');
		ClientPrefs.load();
		
		step('highscore');
		funkin.data.Highscore.load();
		
		if (FlxG.save.data.weekCompleted != null) funkin.states.StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		
		FlxSprite.defaultAntialiasing = ClientPrefs.globalAntialiasing;
		
		step('discord');
		DiscordClient.init();
		
		#if MODS_ALLOWED
		step('global mods');
		funkin.Mods.pushGlobalMods();
		step('top mod');
		funkin.Mods.loadTopMod();
		#end
		
		// set some flixel settings
		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = ClientPrefs.muteKeys;
		FlxG.sound.volumeDownKeys = ClientPrefs.volumeDownKeys;
		FlxG.sound.volumeUpKeys = ClientPrefs.volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];
		FlxG.mouse.visible = false;
		FlxG.plugins.drawOnTop = true;
		
		step('scale mode');
		FlxG.scaleMode = new funkin.backend.FunkinRatioScaleMode();
		FlxG.signals.preStateSwitch.add((cast FlxG.scaleMode : funkin.backend.FunkinRatioScaleMode).resetSize);
		
		step('music');
		FlxG.sound.music = new extensions.flixel.FlxSoundEx();
		FlxG.sound.music.persist = true;
		
		FlxG.autoPause = ClientPrefs.autoPause;
		
		step('scripts');
		funkin.scripts.FunkinScript.init();
		
		// ready backends
		step('hot reload');
		funkin.backend.plugins.HotReloadPlugin.init();
		
		step('mod plugin');
		funkin.backend.plugins.ModPlugin.init();
		
		step('debug text');
		funkin.backend.plugins.DebugTextPlugin.init();
		
		step('fullscreen');
		funkin.backend.plugins.FullScreenPlugin.init();
		
		#if VIDEOS_ALLOWED
		step('video');
		funkin.video.FunkinVideoSprite.init();
		#end
		
		#if FEATURE_DEBUG_TRACY
		funkin.utils.WindowUtil.initTracy();
		#end
		
		step('populate mods');
		funkin.backend.plugins.ModPlugin.instance.populate();
		
		FunkinAssets.cache.currentTrackedSounds.addPermanentKey('assets/music/freakyMenu.ogg');
		
		step('super.create');
		super.create();
		
		final nextState:Class<FlxState> = Main.startMeta.skipSplash || !ClientPrefs.toggleSplashScreen ? Main.startMeta.initialState : Splash;
		step('switch to ' + Type.getClassName(nextState));
		FlxG.switchState(() -> Type.createInstance(nextState, []));
	}
	
	static inline function step(name:String):Void
	{
		#if mobile
		funkin.mobile.LogcatUtil.mark('Init: ' + name);
		#end
	}
}
