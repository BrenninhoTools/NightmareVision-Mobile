package org.nightmarevision;

import android.app.Activity;
import android.view.View;

import java.lang.reflect.Field;

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

	public static void setBannerVisible(final boolean visible)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;

		activity.runOnUiThread(new Runnable()
		{
			public void run()
			{
				try
				{
					Field field = Admob.class.getDeclaredField("adView");
					field.setAccessible(true);
					Object view = field.get(null);

					if (view instanceof View)
					{
						View banner = (View) view;
						banner.setVisibility(visible ? View.VISIBLE : View.GONE);
						if (visible) banner.bringToFront();
					}
				}
				catch (Throwable ignored) {}
			}
		});
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
