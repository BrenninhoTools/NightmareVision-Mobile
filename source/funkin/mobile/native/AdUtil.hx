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
	MAIN_MENU;
	STORY_MENU;
	FREEPLAY;
}

typedef AdRule =
{
	var every:Int;
	var cooldown:Float;
	var delay:Float;
	var banner:Bool;
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

	public static final rules:Map<AdPlacement, AdRule> = [
		SONG_END => {every: 1, cooldown: 60, delay: 0, banner: false},
		PAUSE => {every: 2, cooldown: 240, delay: 0.45, banner: true},
		MAIN_MENU => {every: 3, cooldown: 180, delay: 0.8, banner: true},
		STORY_MENU => {every: 2, cooldown: 180, delay: 0.8, banner: true},
		FREEPLAY => {every: 2, cooldown: 180, delay: 0.8, banner: true}
	];

	public static var minSecondsBetweenAds:Float = 60;

	public static var firstAdDelay:Float = 30;

	public static var maxInterstitialsPerSession:Int = 25;

	public static var adExpireSeconds:Float = 3300;

	public static var adBreakMinutes:Float = 30;

	public static var bannerHideDelay:Float = 0.5;

	public static var bannerAlign:Int = 7;

	public static var retryDelays:Array<Float> = [10, 30, 60, 120, 300];

	public static var startDelay:Float = 2.5;

	public static var maxInitAttempts:Int = 3;

	public static var blockedLaunches:Int = 3;

	public static var initTimeout:Float = 30;

	public static var stableSeconds:Float = 45;

	public static var ready(default, null):Bool = false;

	public static var lastError(default, null):String = '';

	public static var removed(get, never):Bool;

	public static var blocked(default, null):Bool = false;

	public static var showing(default, null):Bool = false;

	public static var shownThisSession(default, null):Int = 0;

	public static var interstitialLoaded(get, never):Bool;

	public static var rewardedLoaded(get, never):Bool;

	public static var bannerVisible(get, never):Bool;

	public static var testMode(get, never):Bool;

	public static var enabled(get, never):Bool;

	public static var onBreak(get, never):Bool;

	public static var breakMinutesLeft(get, never):Int;

	static var initialized:Bool = false;

	static var scheduled:Bool = false;

	static var startTime:Float = 0;

	static var lastAdTime:Float = 0;

	static var interstitialTime:Float = -1;

	static var rewardedTime:Float = -1;

	static var interstitialLoading:Bool = false;

	static var rewardedLoading:Bool = false;

	static var interstitialRetries:Int = 0;

	static var rewardedRetries:Int = 0;

	static var bannerRetries:Int = 0;

	static var bannerCreated:Bool = false;

	static var bannerLoaded:Bool = false;

	static var bannerShown:Bool = false;

	static var bannerOffSince:Float = -1;

	static var bannerRetryAt:Float = 0;

	static var rewardCallback:Null<Bool->Void> = null;

	static var rewardEarned:Bool = false;

	static var savedMute:Bool = false;

	static final active:Array<AdPlacement> = [];

	static final counters:Map<AdPlacement, Int> = [];

	static final lastShown:Map<AdPlacement, Float> = [];

	static final timers:Map<AdPlacement, haxe.Timer> = [];

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
		return !blocked && !ClientPrefs.adsRemoved && !PurchaseUtil.owns(REMOVE_ADS_PRODUCT);
		#else
		return false;
		#end
	}

	static function get_removed():Bool
	{
		#if (mobile && extension_admob)
		return ClientPrefs.adsRemoved || PurchaseUtil.owns(REMOVE_ADS_PRODUCT);
		#else
		return ClientPrefs.adsRemoved;
		#end
	}

	static function get_onBreak():Bool
	{
		return ClientPrefs.adBreakUntil > Date.now().getTime();
	}

	static function get_breakMinutesLeft():Int
	{
		final left = ClientPrefs.adBreakUntil - Date.now().getTime();
		return left > 0 ? Math.ceil(left / 60000) : 0;
	}

	static function get_bannerVisible():Bool
	{
		return bannerShown && bannerLoaded;
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

	static inline function ruleFor(placement:AdPlacement):AdRule
	{
		return rules.get(placement) ?? {every: 1, cooldown: 120, delay: 0, banner: false};
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
			ClientPrefs.adsBlockedLaunches++;
			if (ClientPrefs.adsBlockedLaunches <= blockedLaunches)
			{
				ClientPrefs.flush();
				blocked = true;
				lastError = 'Paused after ' + maxInitAttempts + ' starts that closed the game';
				funkin.mobile.android.logcat.LogcatUtil.warn('Ads: ' + lastError);
				return;
			}

			ClientPrefs.adsInitAttempts = maxInitAttempts - 1;
			ClientPrefs.adsBlockedLaunches = 0;
		}

		ClientPrefs.adsInitAttempts++;
		ClientPrefs.flush();
		watchLifecycle();

		initialized = true;
		startTime = now();
		funkin.mobile.android.logcat.LogcatUtil.mark('Ads: init');

		try
		{
			FlxG.signals.preUpdate.add(update);

			#if android
			final method:Null<Dynamic> = lime.system.JNI.createStaticMethod('org/nightmarevision/AdsHelper', 'init', '(ZZZLorg/haxe/lime/HaxeObject;)V');
			if (method != null) method(testMode, false, false, new AdsCallback());
			else
			{
				Admob.onEvent.add(queue);
				Admob.init(testMode, false, false);
			}
			#else
			Admob.onEvent.add(queue);
			Admob.init(testMode, false, false);
			#end
		}
		catch (e:Dynamic)
		{
			initialized = false;
			FlxG.signals.preUpdate.remove(update);
			lastError = 'Init failed: ' + e;
			funkin.mobile.android.logcat.LogcatUtil.warn('Ads init failed: ' + e);
		}

		haxe.Timer.delay(markStable, Std.int(stableSeconds * 1000));
		haxe.Timer.delay(() -> if (initialized && !ready)
		{
			lastError = 'No answer from AdMob after ' + Std.int(initTimeout) + 's';
			funkin.mobile.android.logcat.LogcatUtil.warn('Ads: ' + lastError);
		}, Std.int(initTimeout * 1000));
		#end
	}

	static function markStable():Void
	{
		if (ClientPrefs.adsInitAttempts == 0 && ClientPrefs.adsBlockedLaunches == 0) return;

		ClientPrefs.adsInitAttempts = 0;
		ClientPrefs.adsBlockedLaunches = 0;
		ClientPrefs.flush();
	}

	static var watching:Bool = false;

	static function watchLifecycle():Void
	{
		if (watching) return;
		watching = true;

		final application = lime.app.Application.current;
		if (application == null) return;

		application.onExit.add((_) -> markStable());
		if (application.window != null) application.window.onDeactivate.add(markStable);
	}

	public static function retryNow():Void
	{
		#if (mobile && extension_admob)
		ClientPrefs.adsInitAttempts = 0;
		ClientPrefs.adsBlockedLaunches = 0;
		ClientPrefs.flush();

		blocked = false;
		lastError = '';
		bannerRetryAt = 0;
		interstitialRetries = rewardedRetries = bannerRetries = 0;

		if (ready)
		{
			loadInterstitial();
			loadRewarded();
			return;
		}

		if (!initialized && !scheduled) start();
		#end
	}

	public static function status():String
	{
		#if (mobile && extension_admob)
		if (removed) return 'Removed';
		if (blocked) return 'Paused: ' + lastError;
		if (onBreak) return 'Ad break, ' + breakMinutesLeft + ' min left';
		if (!initialized) return scheduled ? 'Starting' : (lastError.length > 0 ? lastError : 'Not started');
		if (!ready) return lastError.length > 0 ? lastError : 'Connecting to AdMob';

		final parts = [
			(testMode ? 'Test ads' : 'Real ads'),
			'Interstitial ' + (interstitialLoaded ? 'ready' : (interstitialLoading ? 'loading' : 'waiting')),
			'Banner ' + (bannerLoaded ? 'ready' : (bannerCreated ? 'loading' : 'waiting')),
			'Rewarded ' + (rewardedLoaded ? 'ready' : (rewardedLoading ? 'loading' : 'waiting'))
		];
		return parts.join(', ') + (lastError.length > 0 ? '\nLast error: ' + lastError : '');
		#else
		return 'Not available';
		#end
	}

	public static function open(placement:AdPlacement):Void
	{
		#if (mobile && extension_admob)
		if (!active.contains(placement)) active.push(placement);
		if (!ready || !enabled) return;

		final rule = ruleFor(placement);
		final count = (counters.get(placement) ?? 0) + 1;
		counters.set(placement, count);
		if (count < rule.every || !canShow(placement)) return;

		cancelTimer(placement);

		if (rule.delay <= 0)
		{
			present(placement);
			return;
		}

		timers.set(placement, haxe.Timer.delay(() -> {
			timers.remove(placement);
			FlxG.signals.preUpdate.addOnce(() -> if (active.contains(placement)) present(placement));
		}, Std.int(rule.delay * 1000)));
		#end
	}

	public static function close(placement:AdPlacement):Void
	{
		active.remove(placement);
		cancelTimer(placement);
	}

	public static inline function pauseOpened():Void
	{
		open(PAUSE);
	}

	public static inline function pauseClosed():Void
	{
		close(PAUSE);
	}

	public static function songCompleted():Void
	{
		#if (mobile && extension_admob)
		if (!ready || !enabled) return;

		ClientPrefs.adSongs++;
		if (ClientPrefs.adSongs < ruleFor(SONG_END).every) return;

		if (canShow(SONG_END) && present(SONG_END)) ClientPrefs.adSongs = 0;
		#end
	}

	public static function canShow(placement:AdPlacement):Bool
	{
		if (!ready || !enabled || onBreak || showing || !interstitialLoaded) return false;
		if (shownThisSession >= maxInterstitialsPerSession) return false;

		final time = now();
		if (time - startTime < firstAdDelay) return false;
		if (lastAdTime > 0 && time - lastAdTime < minSecondsBetweenAds) return false;

		final last = lastShown.get(placement) ?? 0;
		return last <= 0 || time - last >= ruleFor(placement).cooldown;
	}

	static function present(placement:AdPlacement):Bool
	{
		if (!canShow(placement) || !showInterstitial()) return false;

		counters.set(placement, 0);
		lastShown.set(placement, now());
		funkin.mobile.android.logcat.LogcatUtil.info('Ad shown: ' + placement);
		return true;
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

	public static function watchForBreak(onFinished:Bool->Void):Bool
	{
		return showRewarded((earned) -> {
			if (earned)
			{
				final base = Math.max(Date.now().getTime(), ClientPrefs.adBreakUntil);
				ClientPrefs.adBreakUntil = base + adBreakMinutes * 60000;
				ClientPrefs.flush();
			}
			onFinished(earned);
		});
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

		for (placement in [for (key in timers.keys()) key])
			cancelTimer(placement);
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

	static function cancelTimer(placement:AdPlacement):Void
	{
		final timer = timers.get(placement);
		if (timer == null) return;
		timer.stop();
		timers.remove(placement);
	}

	static function wantsBanner():Bool
	{
		if (!ready || !enabled || onBreak || showing) return false;

		for (placement in active)
			if (ruleFor(placement).banner) return true;

		return false;
	}

	static function createBanner():Void
	{
		#if (mobile && extension_admob)
		if (bannerCreated || !ready || !enabled) return;

		bannerCreated = true;
		bannerLoaded = false;
		bannerShown = true;
		try
		{
			Admob.showBanner(bannerUnit(), AdmobBannerSize.BANNER, (bannerAlign : AdmobBannerAlign));
		}
		catch (e:Dynamic)
		{
			bannerCreated = false;
			bannerShown = false;
		}
		#end
	}

	static function destroyBanner():Void
	{
		#if (mobile && extension_admob)
		if (!bannerCreated) return;

		bannerCreated = false;
		bannerLoaded = false;
		bannerShown = false;
		try
		{
			Admob.hideBanner();
		}
		catch (e:Dynamic) {}
		#end
	}

	static function setBannerShown(visible:Bool, force:Bool = false):Void
	{
		if (!bannerCreated || (!force && bannerShown == visible)) return;
		bannerShown = visible;

		#if android
		try
		{
			final method:Null<Dynamic> = lime.system.JNI.createStaticMethod('org/nightmarevision/AdsHelper', 'setBannerVisible', '(Z)V');
			if (method != null) method(visible);
		}
		catch (e:Dynamic) {}
		#end
	}

	static function syncBanner():Void
	{
		final wanted = wantsBanner();

		if (!bannerCreated && ready && enabled && now() >= bannerRetryAt && (wanted #if android || true #end))
		{
			createBanner();
			#if android
			if (!wanted) setBannerShown(false, true);
			#end
		}

		if (wanted)
		{
			bannerOffSince = -1;
			#if android
			setBannerShown(true);
			#end
			return;
		}

		if (!bannerCreated) return;

		if (bannerOffSince < 0) bannerOffSince = now();
		if (now() - bannerOffSince < bannerHideDelay && !showing) return;

		#if android
		if (enabled) setBannerShown(false);
		else destroyBanner();
		#else
		destroyBanner();
		#end
	}

	static function update():Void
	{
		#if (mobile && extension_admob)
		process();
		#end
		syncBanner();
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
				lastError = '';
				markStable();
				funkin.mobile.android.logcat.LogcatUtil.info('Ads ready: ' + value);
				loadInterstitial();
				loadRewarded();

			case 'INIT_FAILED':
				initialized = false;
				lastError = 'Init failed: ' + value;
				FlxG.signals.preUpdate.remove(update);
				funkin.mobile.android.logcat.LogcatUtil.warn('Ads init failed: ' + value);

			case AdmobEvent.CONSENT_FAIL:
				funkin.mobile.android.logcat.LogcatUtil.warn('Ads consent failed: ' + value);

			case AdmobEvent.BANNER_LOADED:
				bannerLoaded = true;
				bannerRetries = 0;
				setBannerShown(wantsBanner(), true);

			case AdmobEvent.BANNER_FAILED_TO_LOAD:
				if (value != null && value.indexOf('Hide previous banner') >= 0) return;
				lastError = 'Banner: ' + value;
				funkin.mobile.android.logcat.LogcatUtil.warn('Banner failed: ' + value);
				destroyBanner();
				if (retryDelays.length > 0) bannerRetryAt = now() + retryDelays[Std.int(Math.min(bannerRetries, retryDelays.length - 1))];
				bannerRetries++;

			case AdmobEvent.INTERSTITIAL_LOADED:
				interstitialLoading = false;
				interstitialTime = now();
				interstitialRetries = 0;

			case AdmobEvent.INTERSTITIAL_FAILED_TO_LOAD:
				interstitialLoading = false;
				interstitialTime = -1;
				lastError = 'Interstitial: ' + value;
				funkin.mobile.android.logcat.LogcatUtil.warn('Interstitial failed: ' + value);
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
				lastError = 'Rewarded: ' + value;
				funkin.mobile.android.logcat.LogcatUtil.warn('Rewarded failed: ' + value);
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
		funkin.mobile.haptics.Haptics.suspend('ad');
		savedMute = FlxG.sound.muted;
		FlxG.sound.muted = true;
		syncBanner();
	}

	static function endShowing(shown:Bool):Void
	{
		if (!showing) return;
		showing = false;
		funkin.mobile.haptics.Haptics.resume('ad');
		FlxG.sound.muted = savedMute;

		if (shown)
		{
			lastAdTime = now();
			shownThisSession++;
			ClientPrefs.flush();
		}
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
