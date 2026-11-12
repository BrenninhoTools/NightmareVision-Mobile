package org.nightmarevision;

import android.app.Activity;

import org.haxe.extension.Admob;
import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

public class AdsHelper
{
	public static void init(final boolean testingAds, final boolean childDirected, final boolean enableRDP, final HaxeObject callback)
	{
		final Activity activity = Extension.mainActivity;

		if (activity == null)
		{
			report(callback, "INIT_FAILED", "No activity");
			return;
		}

		try
		{
			activity.runOnUiThread(new Runnable()
			{
				public void run()
				{
					try
					{
						Admob.init(testingAds, childDirected, enableRDP, callback);
					}
					catch (Throwable error)
					{
						report(callback, "INIT_FAILED", String.valueOf(error));
					}
				}
			});
		}
		catch (Throwable error)
		{
			report(callback, "INIT_FAILED", String.valueOf(error));
		}
	}

	private static void report(HaxeObject callback, String event, String value)
	{
		if (callback == null) return;

		try
		{
			callback.call("onEvent", new Object[] { event, value });
		}
		catch (Throwable ignored) {}
	}
}
