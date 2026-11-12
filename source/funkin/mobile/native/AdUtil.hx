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

	public static var bannerVisible(get, never):Bool;

	static var bannerWanted:Bool = false;

	static var bannerCreated:Bool = false;

	static var bannerLoaded:Bool = false;

	public static var showing(default, null):Bool = false;

	public static var testMode(get, never):Bool;

	public static var enabled(get, never):Bool;

	public static var shownThisSession(default, null):Int = 0;

	static var initialized:Bool = false;

	static var scheduled:Bool = false;

	public static var blocked(default, null):Bool = false;

	public static var startDelay:Float = 2.5;

	public static var maxInitAttempts:Int = 2;

	public static var stableSeconds:Float = 45;

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

	static function get_bannerVisible():Bool
	{
		return bannerWanted && bannerLoaded && !showing;
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
		if (initialized || scheduled || !enabled) return;
		scheduled = true;

		haxe.Timer.delay(() -> FlxG.signals.preUpdate.addOnce(start), Std.int(startDelay * 1000));
		#end
	}

	static function start():Void
	{
		#if (mobile && extension_admob)
		scheduled = false;
		if (initialized || !enabled) return;

		final version:String = lime.app.Application.current?.meta.get('version') ?? '';
		if (ClientPrefs.adsGuardVersion != version)
		{
			ClientPrefs.adsGuardVersion = version;
			ClientPrefs.adsInitAttempts = 0;
		}

		if (ClientPrefs.adsInitAttempts >= maxInitAttempts)
		{
			blocked = true;
			funkin.mobile.android.logcat.LogcatUtil.warn('Ads disabled, the last ' + maxInitAttempts + ' starts closed the game');
			return;
		}

		ClientPrefs.adsInitAttempts++;
		ClientPrefs.flush();

		initialized = true;
		startTime = now();
		funkin.mobile.android.logcat.LogcatUtil.mark('Ads: init');

		try
		{
			FlxG.signals.preUpdate.add(process);

			#if android
			final method:Null<Dynamic> = lime.system.JNI.createStaticMethod('org/nightmarevision/AdsHelper', 'init', '(ZZZLorg/haxe/lime/HaxeObject;)V');
			if (method == null) throw 'AdsHelper not found';
			method(testMode, false, false, new AdsCallback());
			#else
			Admob.onEvent.add(queue);
			Admob.init(testMode, false, false);
			#end
		}
		catch (e:Dynamic)
		{
			initialized = false;
			FlxG.signals.preUpdate.remove(process);
			funkin.mobile.android.logcat.LogcatUtil.warn('Ads init failed: ' + e);
		}

		haxe.Timer.delay(markStable, Std.int(stableSeconds * 1000));
		#end
	}

	static function markStable():Void
	{
		if (ClientPrefs.adsInitAttempts == 0) return;

		ClientPrefs.adsInitAttempts = 0;
		ClientPrefs.flush();
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
		bannerWanted = true;
		if (!ready || !enabled) return;

		if (!bannerCreated) createBanner();
		#if android
		setNativeBanner(!showing);
		#end
		#end
	}

	public static function hideBanner():Void
	{
		#if (mobile && extension_admob)
		bannerWanted = false;

		#if android
		setNativeBanner(false);
		#else
		destroyBanner();
		#end
		#end
	}

	static function createBanner():Void
	{
		#if (mobile && extension_admob)
		if (bannerCreated || !ready || !enabled) return;

		bannerCreated = true;
		bannerLoaded = false;
		try
		{
			Admob.showBanner(bannerUnit(), AdmobBannerSize.BANNER, AdmobBannerAlign.BOTTOM_RIGHT);
			#if android
			setNativeBanner(bannerWanted && !showing);
			#end
		}
		catch (e:Dynamic)
		{
			bannerCreated = false;
		}
		#end
	}

	static function destroyBanner():Void
	{
		#if (mobile && extension_admob)
		if (!bannerCreated) return;

		bannerCreated = false;
		bannerLoaded = false;
		try
		{
			Admob.hideBanner();
		}
		catch (e:Dynamic) {}
		#end
	}

	#if android
	static function setNativeBanner(visible:Bool):Void
	{
		if (!bannerCreated) return;

		try
		{
			final method:Null<Dynamic> = lime.system.JNI.createStaticMethod('org/nightmarevision/AdsHelper', 'setBannerVisible', '(Z)V');
			if (method != null) method(visible);
		}
		catch (e:Dynamic) {}
	}
	#end

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
		bannerWanted = false;
		destroyBanner();
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
		if (event != null) push(event.name, event.value);
	}

	@:allow(funkin.mobile.native.AdsCallback)
	static function push(name:String, value:Null<String>):Void
	{
		#if target.threaded
		lock.acquire();
		#end
		pending.push({name: name, value: value});
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
				markStable();
				funkin.mobile.android.logcat.LogcatUtil.info('Ads ready: ' + value);
				loadInterstitial();
				loadRewarded();
				#if android
				if (pauseBanner) createBanner();
				#end
				if (paused && pauseBanner) showBanner();

			case 'INIT_FAILED':
				initialized = false;
				funkin.mobile.android.logcat.LogcatUtil.warn('Ads init failed: ' + value);

			case AdmobEvent.CONSENT_FAIL:
				funkin.mobile.android.logcat.LogcatUtil.warn('Ads consent failed: ' + value);

			case AdmobEvent.BANNER_LOADED:
				bannerLoaded = true;
				bannerRetries = 0;
				#if android
				setNativeBanner(bannerWanted && !showing);
				#else
				if (!bannerWanted) destroyBanner();
				#end

			case AdmobEvent.BANNER_FAILED_TO_LOAD:
				if (value != null && value.indexOf('Hide previous banner') >= 0) return;
				funkin.mobile.android.logcat.LogcatUtil.warn('Banner failed: ' + value);
				destroyBanner();
				retry(() -> {
					#if android
					createBanner();
					#else
					if (bannerWanted) createBanner();
					#end
				}, bannerRetries++);

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

		#if android
		setNativeBanner(false);
		#else
		destroyBanner();
		#end
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

#if (android && extension_admob)
class AdsCallback implements lime.system.JNI.JNISafety
{
	public function new() {}

	@:keep
	@:runOnMainThread
	public function onEvent(event:String, value:String):Void
	{
		AdUtil.push(event, value);
	}
}
#end
