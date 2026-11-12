package funkin.mobile.native;

#if (mobile && extension_admob)
import extension.admob.Admob;
import extension.admob.AdmobBannerAlign;
import extension.admob.AdmobBannerSize;
import extension.admob.AdmobEvent;
#end

import flixel.FlxG;

enum AdPlacement
{
	SONG_END;
	PAUSE;
}

class AdUtil
{
	public static final REMOVE_ADS_PRODUCT:String = 'remove_ads';

	static final TEST_INTERSTITIAL_ANDROID:String = 'ca-app-pub-3940256099942544/1033173712';

	static final TEST_INTERSTITIAL_IOS:String = 'ca-app-pub-3940256099942544/4411468910';

	static final TEST_REWARDED_ANDROID:String = 'ca-app-pub-3940256099942544/5224354917';

	static final TEST_REWARDED_IOS:String = 'ca-app-pub-3940256099942544/1712485313';

	static final TEST_BANNER_ANDROID:String = 'ca-app-pub-3940256099942544/6300978111';

	static final TEST_BANNER_IOS:String = 'ca-app-pub-3940256099942544/2934735716';

	public static var songsBetweenAds:Int = 1;

	public static var pausesBetweenAds:Int = 2;

	public static var minSecondsBetweenAds:Float = 45;

	public static var minSecondsBetweenSongAds:Float = 60;

	public static var minSecondsBetweenPauseAds:Float = 240;

	public static var firstAdDelay:Float = 30;

	public static var pauseAdDelay:Float = 0.45;

	public static var maxInterstitialsPerSession:Int = 25;

	public static var adExpireSeconds:Float = 3300;

	public static var pauseBanner:Bool = true;

	public static var retryDelays:Array<Float> = [10, 30, 60, 120, 300];

	public static var ready(default, null):Bool = false;

	public static var interstitialLoaded(get, never):Bool;

	public static var rewardedLoaded(get, never):Bool;

	public static var bannerVisible(default, null):Bool = false;

	public static var showing(default, null):Bool = false;

	public static var testMode(get, never):Bool;

	public static var enabled(get, never):Bool;

	public static var shownThisSession(default, null):Int = 0;

	static var initialized:Bool = false;

	static var interstitialTime:Float = -1;

	static var rewardedTime:Float = -1;

	static var interstitialLoading:Bool = false;

	static var rewardedLoading:Bool = false;

	static var pausesSinceAd:Int = 0;

	static var lastAdTime:Float = 0;

	static var lastPauseAdTime:Float = 0;

	static var lastSongAdTime:Float = 0;

	static var startTime:Float = 0;

	static var interstitialRetries:Int = 0;

	static var rewardedRetries:Int = 0;

	static var bannerRetries:Int = 0;

	static var rewardCallback:Null<Bool->Void> = null;

	static var rewardEarned:Bool = false;

	static var savedMute:Bool = false;

	static var paused:Bool = false;

	static var pauseTimer:Null<haxe.Timer> = null;

	static var pending:Array<{name:String, value:Null<String>}> = [];

	#if target.threaded
	static final lock:sys.thread.Mutex = new sys.thread.Mutex();
	#end

	static function get_testMode():Bool
	{
		return interstitialUnit() == (#if ios TEST_INTERSTITIAL_IOS #else TEST_INTERSTITIAL_ANDROID #end);
	}

	static function get_enabled():Bool
	{
		#if (mobile && extension_admob)
		return !ClientPrefs.adsRemoved && !PurchaseUtil.owns(REMOVE_ADS_PRODUCT);
		#else
		return false;
		#end
	}

	static function get_interstitialLoaded():Bool
	{
		return interstitialTime >= 0 && now() - interstitialTime < adExpireSeconds;
	}

	static function get_rewardedLoaded():Bool
	{
		return rewardedTime >= 0 && now() - rewardedTime < adExpireSeconds;
	}

	static inline function now():Float
	{
		return haxe.Timer.stamp();
	}

	public static function init():Void
	{
		#if (mobile && extension_admob)
		if (initialized || !enabled) return;
		initialized = true;
		startTime = now();

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

		ClientPrefs.adSongs++;
		if (ClientPrefs.adSongs < songsBetweenAds) return;
		if (!canShow(SONG_END)) return;

		if (showInterstitial())
		{
			ClientPrefs.adSongs = 0;
			lastSongAdTime = now();
		}
		#end
	}

	public static function pauseOpened():Void
	{
		#if (mobile && extension_admob)
		paused = true;
		if (!ready || !enabled) return;

		if (pauseBanner) showBanner();

		pausesSinceAd++;
		if (pausesSinceAd < pausesBetweenAds || !canShow(PAUSE)) return;

		cancelPauseTimer();
		pauseTimer = haxe.Timer.delay(() -> {
			pauseTimer = null;
			FlxG.signals.preUpdate.addOnce(() -> {
				if (!paused || !canShow(PAUSE)) return;
				if (showInterstitial())
				{
					pausesSinceAd = 0;
					lastPauseAdTime = now();
				}
			});
		}, Std.int(pauseAdDelay * 1000));
		#end
	}

	public static function pauseClosed():Void
	{
		#if (mobile && extension_admob)
		paused = false;
		cancelPauseTimer();
		hideBanner();
		#end
	}

	public static function canShow(placement:AdPlacement):Bool
	{
		if (!ready || !enabled || showing || !interstitialLoaded) return false;
		if (shownThisSession >= maxInterstitialsPerSession) return false;

		final time = now();
		if (time - startTime < firstAdDelay) return false;
		if (lastAdTime > 0 && time - lastAdTime < minSecondsBetweenAds) return false;

		return switch (placement)
		{
			case PAUSE: lastPauseAdTime <= 0 || time - lastPauseAdTime >= minSecondsBetweenPauseAds;
			case SONG_END: lastSongAdTime <= 0 || time - lastSongAdTime >= minSecondsBetweenSongAds;
		}
	}

	public static function showInterstitial():Bool
	{
		#if (mobile && extension_admob)
		if (!ready || !enabled || showing) return false;

		if (!interstitialLoaded)
		{
			interstitialTime = -1;
			loadInterstitial();
			return false;
		}

		interstitialTime = -1;
		beginShowing();
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
			if (!rewardedLoaded) loadRewarded();
			onFinished(false);
			return false;
		}

		rewardedTime = -1;
		rewardEarned = false;
		rewardCallback = onFinished;
		beginShowing();
		Admob.showRewarded();
		return true;
		#else
		onFinished(false);
		return false;
		#end
	}

	public static function showBanner():Void
	{
		#if (mobile && extension_admob)
		if (!ready || !enabled || bannerVisible) return;

		bannerVisible = true;
		try
		{
			Admob.showBanner(bannerUnit(), AdmobBannerSize.BANNER, AdmobBannerAlign.BOTTOM_RIGHT);
		}
		catch (e:Dynamic)
		{
			bannerVisible = false;
		}
		#end
	}

	public static function hideBanner():Void
	{
		#if (mobile && extension_admob)
		if (!bannerVisible) return;

		bannerVisible = false;
		try
		{
			Admob.hideBanner();
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function removeAds():Void
	{
		ClientPrefs.adsRemoved = true;
		ClientPrefs.flush();
		purchasesChanged();
	}

	public static function purchasesChanged():Void
	{
		if (enabled) return;

		cancelPauseTimer();
		hideBanner();
		interstitialTime = -1;
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

	static function cancelPauseTimer():Void
	{
		if (pauseTimer == null) return;
		pauseTimer.stop();
		pauseTimer = null;
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
				if (paused && pauseBanner) showBanner();

			case AdmobEvent.CONSENT_FAIL:
				funkin.mobile.android.logcat.LogcatUtil.warn('Ads consent failed: ' + value);

			case AdmobEvent.BANNER_LOADED:
				bannerRetries = 0;
				if (!paused) hideBanner();

			case AdmobEvent.BANNER_FAILED_TO_LOAD:
				bannerVisible = false;
				if (paused) retry(() -> if (paused) showBanner(), bannerRetries++);

			case AdmobEvent.INTERSTITIAL_LOADED:
				interstitialLoading = false;
				interstitialTime = now();
				interstitialRetries = 0;

			case AdmobEvent.INTERSTITIAL_FAILED_TO_LOAD:
				interstitialLoading = false;
				interstitialTime = -1;
				retry(loadInterstitial, interstitialRetries++);

			case AdmobEvent.INTERSTITIAL_FAILED_TO_SHOW:
				endShowing(false);
				loadInterstitial();

			case AdmobEvent.INTERSTITIAL_DISMISSED:
				endShowing(true);
				loadInterstitial();

			case AdmobEvent.REWARDED_LOADED:
				rewardedLoading = false;
				rewardedTime = now();
				rewardedRetries = 0;

			case AdmobEvent.REWARDED_FAILED_TO_LOAD:
				rewardedLoading = false;
				rewardedTime = -1;
				retry(loadRewarded, rewardedRetries++);

			case AdmobEvent.REWARDED_EARNED:
				rewardEarned = true;

			case AdmobEvent.REWARDED_FAILED_TO_SHOW:
				endShowing(false);
				finishReward(false);
				loadRewarded();

			case AdmobEvent.REWARDED_DISMISSED:
				endShowing(true);
				finishReward(rewardEarned);
				loadRewarded();

			default:
		}
	}

	static function loadInterstitial():Void
	{
		if (!ready || !enabled || interstitialLoading || interstitialLoaded) return;
		interstitialLoading = true;
		Admob.loadInterstitial(interstitialUnit());
	}

	static function loadRewarded():Void
	{
		if (!ready || rewardedLoading || rewardedLoaded) return;
		rewardedLoading = true;
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

	static function beginShowing():Void
	{
		showing = true;
		savedMute = FlxG.sound.muted;
		FlxG.sound.muted = true;
		if (bannerVisible)
		{
			hideBanner();
			bannerVisible = false;
		}
	}

	static function endShowing(shown:Bool):Void
	{
		if (!showing) return;
		showing = false;
		FlxG.sound.muted = savedMute;

		if (shown)
		{
			lastAdTime = now();
			shownThisSession++;
			ClientPrefs.flush();
		}

		if (paused && pauseBanner) showBanner();
	}
	#end

	static function pick(custom:Null<String>, fallback:String):String
	{
		return custom != null && custom.length > 0 ? custom : fallback;
	}

	static function interstitialUnit():String
	{
		#if ios
		return pick(AdUnits.IOS_INTERSTITIAL, TEST_INTERSTITIAL_IOS);
		#else
		return pick(AdUnits.ANDROID_INTERSTITIAL, TEST_INTERSTITIAL_ANDROID);
		#end
	}

	static function rewardedUnit():String
	{
		#if ios
		return pick(AdUnits.IOS_REWARDED, TEST_REWARDED_IOS);
		#else
		return pick(AdUnits.ANDROID_REWARDED, TEST_REWARDED_ANDROID);
		#end
	}

	static function bannerUnit():String
	{
		#if ios
		return pick(AdUnits.IOS_BANNER, TEST_BANNER_IOS);
		#else
		return pick(AdUnits.ANDROID_BANNER, TEST_BANNER_ANDROID);
		#end
	}
}
