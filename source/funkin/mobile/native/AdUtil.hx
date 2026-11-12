package funkin.mobile.native;

#if (mobile && extension_admob)
import extension.admob.Admob;
import extension.admob.AdmobEvent;
#end

import flixel.FlxG;

class AdUtil
{
	public static final REMOVE_ADS_PRODUCT:String = 'remove_ads';

	static final TEST_INTERSTITIAL_ANDROID:String = 'ca-app-pub-3940256099942544/1033173712';

	static final TEST_INTERSTITIAL_IOS:String = 'ca-app-pub-3940256099942544/4411468910';

	static final TEST_REWARDED_ANDROID:String = 'ca-app-pub-3940256099942544/5224354917';

	static final TEST_REWARDED_IOS:String = 'ca-app-pub-3940256099942544/1712485313';

	public static var songsBetweenAds:Int = 3;

	public static var minSecondsBetweenAds:Float = 180;

	public static var firstAdDelay:Float = 120;

	public static var retryDelays:Array<Float> = [10, 30, 60, 120];

	public static var ready(default, null):Bool = false;

	public static var interstitialLoaded(default, null):Bool = false;

	public static var rewardedLoaded(default, null):Bool = false;

	public static var showing(default, null):Bool = false;

	public static var testMode(get, never):Bool;

	public static var enabled(get, never):Bool;

	static var initialized:Bool = false;

	static var songsSinceAd:Int = 0;

	static var lastAdTime:Float = 0;

	static var startTime:Float = 0;

	static var interstitialRetries:Int = 0;

	static var rewardedRetries:Int = 0;

	static var rewardCallback:Null<Bool->Void> = null;

	static var rewardEarned:Bool = false;

	static var savedVolume:Float = 1;

	static var savedMute:Bool = false;

	static var pending:Array<{name:String, value:Null<String>}> = [];

	#if target.threaded
	static final lock:sys.thread.Mutex = new sys.thread.Mutex();
	#end

	static function get_testMode():Bool
	{
		return interstitialUnit() == defaultInterstitial();
	}

	static function get_enabled():Bool
	{
		#if (mobile && extension_admob)
		return !PurchaseUtil.owns(REMOVE_ADS_PRODUCT);
		#else
		return false;
		#end
	}

	public static function init():Void
	{
		#if (mobile && extension_admob)
		if (initialized || !enabled) return;
		initialized = true;
		startTime = haxe.Timer.stamp();

		try
		{
			Admob.onEvent.add(queue);
			FlxG.signals.preUpdate.add(process);
			Admob.init(testMode, false, false);
		}
		catch (e:Dynamic)
		{
			initialized = false;
			funkin.mobile.android.logcat.LogcatUtil.warn('Ads init failed: ' + e);
		}
		#end
	}

	public static function songCompleted():Void
	{
		#if (mobile && extension_admob)
		if (!ready || !enabled) return;

		songsSinceAd++;
		if (songsSinceAd < songsBetweenAds) return;

		final now = haxe.Timer.stamp();
		if (now - startTime < firstAdDelay) return;
		if (lastAdTime > 0 && now - lastAdTime < minSecondsBetweenAds) return;

		if (showInterstitial()) songsSinceAd = 0;
		#end
	}

	public static function showInterstitial():Bool
	{
		#if (mobile && extension_admob)
		if (!ready || !enabled || showing || !interstitialLoaded) return false;

		interstitialLoaded = false;
		showing = true;
		muteGame();
		Admob.showInterstitial();
		return true;
		#else
		return false;
		#end
	}

	public static function showRewarded(onFinished:Bool->Void):Bool
	{
		#if (mobile && extension_admob)
		if (!ready || showing || !rewardedLoaded)
		{
			onFinished(false);
			return false;
		}

		rewardedLoaded = false;
		rewardEarned = false;
		rewardCallback = onFinished;
		showing = true;
		muteGame();
		Admob.showRewarded();
		return true;
		#else
		onFinished(false);
		return false;
		#end
	}

	public static function privacyOptionsRequired():Bool
	{
		#if (mobile && extension_admob)
		try
		{
			return ready && Admob.isPrivacyOptionsRequired();
		}
		catch (e:Dynamic) {}
		#end

		return false;
	}

	public static function showPrivacyOptions():Bool
	{
		#if (mobile && extension_admob)
		if (!initialized) return false;

		try
		{
			Admob.showPrivacyOptionsForm();
			return true;
		}
		catch (e:Dynamic) {}
		#end

		return false;
	}

	#if (mobile && extension_admob)
	static function queue(event:AdmobEvent):Void
	{
		if (event == null) return;

		#if target.threaded
		lock.acquire();
		#end
		pending.push({name: event.name, value: event.value});
		#if target.threaded
		lock.release();
		#end
	}

	static function process():Void
	{
		if (pending.length == 0) return;

		#if target.threaded
		lock.acquire();
		#end
		final events = pending;
		pending = [];
		#if target.threaded
		lock.release();
		#end

		for (event in events)
			handle(event.name, event.value);
	}

	static function handle(name:String, value:Null<String>):Void
	{
		switch (name)
		{
			case AdmobEvent.INIT_OK:
				ready = true;
				loadInterstitial();
				loadRewarded();

			case AdmobEvent.CONSENT_FAIL:
				funkin.mobile.android.logcat.LogcatUtil.warn('Ads consent failed: ' + value);

			case AdmobEvent.INTERSTITIAL_LOADED:
				interstitialLoaded = true;
				interstitialRetries = 0;

			case AdmobEvent.INTERSTITIAL_FAILED_TO_LOAD:
				interstitialLoaded = false;
				retry(() -> loadInterstitial(), interstitialRetries++);

			case AdmobEvent.INTERSTITIAL_FAILED_TO_SHOW:
				finishShowing();
				loadInterstitial();

			case AdmobEvent.INTERSTITIAL_DISMISSED:
				lastAdTime = haxe.Timer.stamp();
				finishShowing();
				loadInterstitial();

			case AdmobEvent.REWARDED_LOADED:
				rewardedLoaded = true;
				rewardedRetries = 0;

			case AdmobEvent.REWARDED_FAILED_TO_LOAD:
				rewardedLoaded = false;
				retry(() -> loadRewarded(), rewardedRetries++);

			case AdmobEvent.REWARDED_EARNED:
				rewardEarned = true;

			case AdmobEvent.REWARDED_FAILED_TO_SHOW:
				finishShowing();
				finishReward(false);
				loadRewarded();

			case AdmobEvent.REWARDED_DISMISSED:
				lastAdTime = haxe.Timer.stamp();
				finishShowing();
				finishReward(rewardEarned);
				loadRewarded();

			default:
		}
	}

	static function loadInterstitial():Void
	{
		if (!ready || !enabled || interstitialLoaded) return;
		Admob.loadInterstitial(interstitialUnit());
	}

	static function loadRewarded():Void
	{
		if (!ready || rewardedLoaded) return;
		Admob.loadRewarded(rewardedUnit());
	}

	static function retry(action:Void->Void, attempt:Int):Void
	{
		if (retryDelays.length == 0) return;

		final delay = retryDelays[Std.int(Math.min(attempt, retryDelays.length - 1))];
		haxe.Timer.delay(() -> FlxG.signals.preUpdate.addOnce(action), Std.int(delay * 1000));
	}

	static function finishReward(earned:Bool):Void
	{
		final callback = rewardCallback;
		rewardCallback = null;
		rewardEarned = false;
		if (callback != null) callback(earned);
	}

	static function muteGame():Void
	{
		savedVolume = FlxG.sound.volume;
		savedMute = FlxG.sound.muted;
		FlxG.sound.muted = true;
	}

	static function finishShowing():Void
	{
		if (!showing) return;
		showing = false;
		FlxG.sound.muted = savedMute;
		FlxG.sound.volume = savedVolume;
	}
	#end

	static function interstitialUnit():String
	{
		final custom:Null<String> = #if android haxe.macro.Compiler.getDefine('ADMOB_ANDROID_INTERSTITIAL') #elseif ios haxe.macro.Compiler.getDefine('ADMOB_IOS_INTERSTITIAL') #else null #end;
		return custom != null && custom.length > 1 ? custom : defaultInterstitial();
	}

	static function rewardedUnit():String
	{
		final custom:Null<String> = #if android haxe.macro.Compiler.getDefine('ADMOB_ANDROID_REWARDED') #elseif ios haxe.macro.Compiler.getDefine('ADMOB_IOS_REWARDED') #else null #end;
		return custom != null && custom.length > 1 ? custom : #if ios TEST_REWARDED_IOS #else TEST_REWARDED_ANDROID #end;
	}

	static inline function defaultInterstitial():String
	{
		return #if ios TEST_INTERSTITIAL_IOS #else TEST_INTERSTITIAL_ANDROID #end;
	}
}
