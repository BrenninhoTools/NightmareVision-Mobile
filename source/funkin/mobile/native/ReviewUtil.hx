package funkin.mobile.native;

#if (android && extension_iarcore)
import extension.iarcore.android.IARAndroid;
#elseif (ios && extension_iarcore)
import extension.iarcore.ios.IARIOS;
#end

class ReviewUtil
{
	public static var songsBeforeAsking:Int = 5;

	public static var daysBetweenAsks:Float = 30;

	public static var busy(default, null):Bool = false;

	static var initialized:Bool = false;

	public static function init():Void
	{
		#if (android && extension_iarcore)
		if (initialized) return;
		initialized = true;

		try
		{
			IARAndroid.onReviewCompleted.add((_) -> busy = false);
			IARAndroid.onReviewError.add((error) -> {
				busy = false;
				funkin.mobile.android.logcat.LogcatUtil.warn('Review error: ' + error);
			});
			IARAndroid.init();
		}
		catch (e:Dynamic)
		{
			initialized = false;
		}
		#end
	}

	public static function request(manual:Bool = false):Bool
	{
		if (busy) return false;

		#if (android && extension_iarcore)
		init();
		busy = true;
		IARAndroid.requestAndLaunchReviewFlow();
		#elseif (ios && extension_iarcore)
		IARIOS.requestReview();
		#else
		return false;
		#end

		ClientPrefs.reviewLastAsked = Date.now().getTime();
		ClientPrefs.flush();

		if (manual)
		{
			#if android
			haxe.Timer.delay(() -> busy = false, 5000);
			#end
		}

		return true;
	}

	public static function songCompleted():Void
	{
		ClientPrefs.reviewSongs++;

		if (ClientPrefs.reviewSongs < songsBeforeAsking) return;

		final elapsed = Date.now().getTime() - ClientPrefs.reviewLastAsked;
		if (ClientPrefs.reviewLastAsked > 0 && elapsed < daysBetweenAsks * 86400000) return;

		ClientPrefs.reviewSongs = 0;
		request();
	}
}
