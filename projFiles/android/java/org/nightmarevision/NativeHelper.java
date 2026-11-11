package org.nightmarevision;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Build;
import android.os.PowerManager;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.provider.OpenableColumns;
import android.util.DisplayMetrics;
import android.view.DisplayCutout;
import android.view.InputDevice;
import android.view.WindowInsets;
import android.view.WindowManager;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.Toast;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

import org.haxe.extension.Extension;

public class NativeHelper extends Extension
{
	private static final int PICK_REQUEST_CODE = 4201;

	private static final int SAVE_REQUEST_CODE = 4202;

	private static volatile String saveState = "idle";

	private static volatile String savedName = "";

	private static String saveSource = "";

	private static final String IMPORT_FOLDER = "imports";

	private static volatile String pickState = "idle";

	private static volatile String pickedFiles = "";

	private static Context getContext()
	{
		if (Extension.mainContext != null) return Extension.mainContext;
		return Extension.mainActivity;
	}

	private static Vibrator vibrator;

	private static boolean vibratorChecked = false;

	private static Vibrator getVibrator()
	{
		if (vibratorChecked) return vibrator;
		vibratorChecked = true;

		try
		{
			Context context = getContext();
			if (context == null) return null;

			Vibrator found = null;

			if (Build.VERSION.SDK_INT >= 31)
			{
				android.os.VibratorManager manager = (android.os.VibratorManager) context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
				if (manager != null) found = manager.getDefaultVibrator();
			}

			if (found == null) found = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
			if (found != null && found.hasVibrator()) vibrator = found;
		}
		catch (Throwable e)
		{
			vibrator = null;
		}

		return vibrator;
	}

	private static final java.util.concurrent.ExecutorService hapticExecutor = java.util.concurrent.Executors.newSingleThreadExecutor();

	private static final long HAPTIC_STALE_MS = 60;

	public static void haptic(final int type, final float intensity)
	{
		if (intensity <= 0) return;

		final long queued = android.os.SystemClock.uptimeMillis();

		hapticExecutor.execute(new Runnable()
		{
			@Override
			public void run()
			{
				if (android.os.SystemClock.uptimeMillis() - queued > HAPTIC_STALE_MS) return;
				playHaptic(type, Math.min(5f, intensity));
			}
		});
	}

	private static void deliver(Vibrator target, VibrationEffect effect)
	{
		if (Build.VERSION.SDK_INT >= 33)
		{
			target.vibrate(effect, android.os.VibrationAttributes.createForUsage(android.os.VibrationAttributes.USAGE_MEDIA));
			return;
		}

		target.vibrate(effect);
	}

	private static int primitiveFor(Vibrator target, int type)
	{
		if (Build.VERSION.SDK_INT < 30) return -1;

		int[] candidates;
		switch (type)
		{
			case 0:
				candidates = Build.VERSION.SDK_INT >= 31 ? new int[] {VibrationEffect.Composition.PRIMITIVE_LOW_TICK, VibrationEffect.Composition.PRIMITIVE_TICK} : new int[] {VibrationEffect.Composition.PRIMITIVE_TICK};
				break;
			case 1:
				candidates = new int[] {VibrationEffect.Composition.PRIMITIVE_TICK, VibrationEffect.Composition.PRIMITIVE_CLICK};
				break;
			case 2:
				candidates = new int[] {VibrationEffect.Composition.PRIMITIVE_CLICK, VibrationEffect.Composition.PRIMITIVE_TICK};
				break;
			default:
				candidates = Build.VERSION.SDK_INT >= 31 ? new int[] {VibrationEffect.Composition.PRIMITIVE_THUD, VibrationEffect.Composition.PRIMITIVE_CLICK} : new int[] {VibrationEffect.Composition.PRIMITIVE_CLICK};
				break;
		}

		for (int primitive : candidates)
			if (target.areAllPrimitivesSupported(primitive)) return primitive;

		return -1;
	}

	private static long scaled(long milliseconds, float boost)
	{
		return Math.max(1, Math.round(milliseconds * Math.min(3f, boost)));
	}

	private static void playConfirm(Vibrator target, float intensity, float boost)
	{
		long first = scaled(70, boost);
		long second = scaled(150, boost);
		long tail = scaled(60, boost);

		if (Build.VERSION.SDK_INT >= 26)
		{
			if (target.hasAmplitudeControl())
			{
				int strong = Math.max(1, Math.min(255, Math.round(intensity * 255)));
				int soft = Math.max(1, Math.round(strong * 0.6f));
				deliver(target, VibrationEffect.createWaveform(new long[] {0, first, 45, second, 30, tail}, new int[] {0, strong, 0, strong, 0, soft}, -1));
			}
			else
			{
				deliver(target, VibrationEffect.createWaveform(new long[] {0, first, 45, second}, -1));
			}
			return;
		}

		target.cancel();
		target.vibrate(new long[] {0, first, 45, second}, -1);
	}

	private static void playRumble(Vibrator target, float intensity, float boost)
	{
		long duration = scaled(110, boost);

		if (Build.VERSION.SDK_INT >= 26)
		{
			int amplitude = VibrationEffect.DEFAULT_AMPLITUDE;
			if (target.hasAmplitudeControl()) amplitude = Math.max(1, Math.min(255, Math.round(intensity * 255)));
			deliver(target, VibrationEffect.createOneShot(duration, amplitude));
			return;
		}

		target.vibrate(duration);
	}

	private static void playHaptic(int type, float intensity)
	{
		try
		{
			Vibrator target = getVibrator();
			if (target == null) return;

			float boost = Math.max(1f, intensity);
			intensity = Math.min(1f, intensity);

			if (type == 5)
			{
				playConfirm(target, intensity, boost);
				return;
			}

			if (type == 6)
			{
				playRumble(target, intensity, boost);
				return;
			}

			int primitive = primitiveFor(target, type);
			if (primitive >= 0)
			{
				VibrationEffect.Composition composition = VibrationEffect.startComposition().addPrimitive(primitive, intensity);
				if (type == 4) composition.addPrimitive(primitive, intensity * 0.8f, 60);
				int repeats = Math.min(4, Math.round(boost) - 1);
				for (int i = 0; i < repeats; i++)
					composition.addPrimitive(primitive, intensity, 25);
				deliver(target, composition.compose());
				return;
			}

			if (Build.VERSION.SDK_INT >= 29 && intensity >= 0.85f && boost <= 1.05f && type != 4)
			{
				int effect;
				switch (type)
				{
					case 0: case 1: effect = VibrationEffect.EFFECT_TICK; break;
					case 2: effect = VibrationEffect.EFFECT_CLICK; break;
					default: effect = VibrationEffect.EFFECT_HEAVY_CLICK; break;
				}
				deliver(target, VibrationEffect.createPredefined(effect));
				return;
			}

			int duration;
			switch (type)
			{
				case 0: duration = 5; break;
				case 1: duration = 9; break;
				case 2: duration = 16; break;
				default: duration = 30; break;
			}

			if (Build.VERSION.SDK_INT >= 26)
			{
				int amplitude = VibrationEffect.DEFAULT_AMPLITUDE;
				if (target.hasAmplitudeControl()) amplitude = Math.max(1, Math.min(255, Math.round(intensity * 255)));

				if (type == 4) deliver(target, VibrationEffect.createWaveform(new long[] {0, scaled(12, boost), 60, scaled(12, boost)}, new int[] {0, amplitude, 0, amplitude}, -1));
				else deliver(target, VibrationEffect.createOneShot(scaled(duration, boost), amplitude));
			}
			else
			{
				target.cancel();
				target.vibrate(Math.max(1, Math.round(duration * intensity * Math.min(3f, boost))));
			}
		}
		catch (Throwable e) {}
	}

	public static boolean hasVibrator()
	{
		return getVibrator() != null;
	}

	public static void vibrate(final int milliseconds)
	{
		vibrateWith(milliseconds, -1);
	}

	public static void vibrateWith(final int milliseconds, final int amplitude)
	{
		try
		{
			Vibrator target = getVibrator();
			if (target == null || milliseconds <= 0) return;

			if (Build.VERSION.SDK_INT >= 26)
			{
				int strength = VibrationEffect.DEFAULT_AMPLITUDE;
				if (amplitude > 0 && target.hasAmplitudeControl()) strength = Math.max(1, Math.min(255, amplitude));
				target.vibrate(VibrationEffect.createOneShot(milliseconds, strength));
			}
			else
			{
				target.vibrate(milliseconds);
			}
		}
		catch (Throwable e) {}
	}

	private static volatile String safeInsets = "0,0,0,0";

	public static void setScreenStyle(final boolean full)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					if (Build.VERSION.SDK_INT >= 28)
					{
						WindowManager.LayoutParams params = activity.getWindow().getAttributes();
						params.layoutInDisplayCutoutMode = full ? WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES : WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER;
						activity.getWindow().setAttributes(params);
					}

					View decor = activity.getWindow().getDecorView();
					decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
						| View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);

					updateSafeInsets(activity);
					decor.post(new Runnable()
					{
						@Override
						public void run()
						{
							updateSafeInsets(activity);
						}
					});
				}
				catch (Throwable e) {}
			}
		});
	}

	private static void updateSafeInsets(Activity activity)
	{
		try
		{
			if (Build.VERSION.SDK_INT < 28)
			{
				safeInsets = "0,0,0,0";
				return;
			}

			WindowInsets insets = activity.getWindow().getDecorView().getRootWindowInsets();
			DisplayCutout cutout = insets != null ? insets.getDisplayCutout() : null;

			if (cutout == null) safeInsets = "0,0,0,0";
			else safeInsets = cutout.getSafeInsetLeft() + "," + cutout.getSafeInsetTop() + "," + cutout.getSafeInsetRight() + "," + cutout.getSafeInsetBottom();
		}
		catch (Throwable e)
		{
			safeInsets = "0,0,0,0";
		}
	}

	public static String getSafeInsets()
	{
		final Activity activity = Extension.mainActivity;
		if (activity != null)
		{
			activity.runOnUiThread(new Runnable()
			{
				@Override
				public void run()
				{
					updateSafeInsets(activity);
				}
			});
		}

		return safeInsets;
	}

	public static String getDisplaySize()
	{
		try
		{
			Activity activity = Extension.mainActivity;
			if (activity == null) return "0,0";

			DisplayMetrics metrics = new DisplayMetrics();
			activity.getWindowManager().getDefaultDisplay().getRealMetrics(metrics);
			return metrics.widthPixels + "," + metrics.heightPixels;
		}
		catch (Throwable e)
		{
			return "0,0";
		}
	}

	public static int getExternalInput()
	{
		int result = 0;

		try
		{
			for (int id : InputDevice.getDeviceIds())
			{
				InputDevice device = InputDevice.getDevice(id);
				if (device == null || device.isVirtual()) continue;
				if (Build.VERSION.SDK_INT >= 29 && !device.isExternal()) continue;

				int sources = device.getSources();

				if ((sources & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD || (sources & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK)
					result |= 2;
				else if ((sources & InputDevice.SOURCE_KEYBOARD) == InputDevice.SOURCE_KEYBOARD && device.getKeyboardType() == InputDevice.KEYBOARD_TYPE_ALPHABETIC)
					result |= 1;
			}
		}
		catch (Throwable e) {}

		return result;
	}

	public static void toast(final String message, final boolean longDuration)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null || message == null) return;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					Toast.makeText(activity, message, longDuration ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT).show();
				}
				catch (Throwable e) {}
			}
		});
	}

	public static void showKeyboard()
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					View view = Extension.mainView != null ? Extension.mainView : activity.getWindow().getDecorView();
					view.setFocusable(true);
					view.setFocusableInTouchMode(true);
					view.requestFocus();

					InputMethodManager manager = (InputMethodManager) activity.getSystemService(Context.INPUT_METHOD_SERVICE);
					if (manager != null) manager.showSoftInput(view, InputMethodManager.SHOW_IMPLICIT);
				}
				catch (Throwable e) {}
			}
		});
	}

	public static void hideKeyboard()
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					View view = Extension.mainView != null ? Extension.mainView : activity.getWindow().getDecorView();
					InputMethodManager manager = (InputMethodManager) activity.getSystemService(Context.INPUT_METHOD_SERVICE);
					if (manager != null) manager.hideSoftInputFromWindow(view.getWindowToken(), 0);
				}
				catch (Throwable e) {}
			}
		});
	}

	public static void pickFiles(final String mimeTypes, final boolean multiple)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null)
		{
			pickState = "cancel";
			return;
		}

		pickState = "pending";
		pickedFiles = "";

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
					intent.addCategory(Intent.CATEGORY_OPENABLE);
					intent.setType("*/*");

					if (mimeTypes != null && mimeTypes.length() > 0)
						intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.split(","));

					intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple);
					activity.startActivityForResult(intent, PICK_REQUEST_CODE);
				}
				catch (Throwable e)
				{
					pickState = "cancel";
				}
			}
		});
	}

	public static void saveFile(final String sourcePath, final String fileName, final String mimeType)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null || sourcePath == null || !new File(sourcePath).isFile())
		{
			saveState = "cancel";
			return;
		}

		saveState = "pending";
		savedName = "";
		saveSource = sourcePath;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
					intent.addCategory(Intent.CATEGORY_OPENABLE);
					intent.setType(mimeType != null && mimeType.length() > 0 ? mimeType : "application/octet-stream");
					intent.putExtra(Intent.EXTRA_TITLE, fileName != null && fileName.length() > 0 ? fileName : new File(sourcePath).getName());
					activity.startActivityForResult(intent, SAVE_REQUEST_CODE);
				}
				catch (Throwable e)
				{
					saveState = "error";
				}
			}
		});
	}

	public static String getSaveState()
	{
		return saveState;
	}

	public static String getSavedName()
	{
		return savedName;
	}

	public static void resetSave()
	{
		saveState = "idle";
		savedName = "";
	}

	private static void finishSave(final Uri uri)
	{
		new Thread(new Runnable()
		{
			@Override
			public void run()
			{
				Context context = getContext();
				InputStream input = null;
				OutputStream output = null;

				try
				{
					ContentResolver resolver = context.getContentResolver();
					input = new FileInputStream(saveSource);
					output = resolver.openOutputStream(uri, "wt");
					if (output == null) output = resolver.openOutputStream(uri);
					if (output == null) throw new Exception("no output");

					byte[] buffer = new byte[256 * 1024];
					int read;
					while ((read = input.read(buffer)) != -1)
						output.write(buffer, 0, read);

					output.flush();
					savedName = queryName(resolver, uri);
					saveState = "done";
				}
				catch (Throwable e)
				{
					saveState = "error";
				}
				finally
				{
					try
					{
						if (input != null) input.close();
					}
					catch (Throwable e) {}

					try
					{
						if (output != null) output.close();
					}
					catch (Throwable e) {}

					new File(saveSource).delete();
				}
			}
		}, "NativeHelper-Save").start();
	}

	public static String getPickState()
	{
		return pickState;
	}

	public static String getPickedFiles()
	{
		return pickedFiles;
	}

	public static void resetPick()
	{
		pickState = "idle";
		pickedFiles = "";
	}

	@Override
	public boolean onActivityResult(int requestCode, int resultCode, final Intent data)
	{
		if (requestCode == SAVE_REQUEST_CODE)
		{
			if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null)
			{
				new File(saveSource).delete();
				saveState = "cancel";
			}
			else
			{
				finishSave(data.getData());
			}
			return false;
		}

		if (requestCode != PICK_REQUEST_CODE) return true;

		if (resultCode != Activity.RESULT_OK || data == null)
		{
			pickState = "cancel";
			return false;
		}

		final List<Uri> uris = new ArrayList<Uri>();

		if (data.getClipData() != null)
		{
			for (int i = 0; i < data.getClipData().getItemCount(); i++)
				uris.add(data.getClipData().getItemAt(i).getUri());
		}
		else if (data.getData() != null)
		{
			uris.add(data.getData());
		}

		new Thread(new Runnable()
		{
			@Override
			public void run()
			{
				StringBuilder builder = new StringBuilder();

				for (Uri uri : uris)
				{
					String path = importUri(uri);
					if (path == null) continue;
					if (builder.length() > 0) builder.append('\n');
					builder.append(path);
				}

				pickedFiles = builder.toString();
				pickState = pickedFiles.length() > 0 ? "done" : "cancel";
			}
		}, "NativeHelper-Import").start();

		return false;
	}

	private static String importUri(Uri uri)
	{
		Context context = getContext();
		if (context == null || uri == null) return null;

		InputStream input = null;
		OutputStream output = null;

		try
		{
			ContentResolver resolver = context.getContentResolver();
			String name = queryName(resolver, uri);

			File base = AssetExtractor.resolveGameDirectory(context);
			if (base == null) return null;

			File folder = new File(base, IMPORT_FOLDER);
			if (!folder.isDirectory()) folder.mkdirs();

			File target = new File(folder, name);
			input = resolver.openInputStream(uri);
			if (input == null) return null;

			output = new FileOutputStream(target, false);
			byte[] buffer = new byte[256 * 1024];
			int read;
			while ((read = input.read(buffer)) != -1)
				output.write(buffer, 0, read);

			output.flush();
			return target.getAbsolutePath();
		}
		catch (Throwable e)
		{
			return null;
		}
		finally
		{
			try
			{
				if (input != null) input.close();
			}
			catch (Throwable e) {}

			try
			{
				if (output != null) output.close();
			}
			catch (Throwable e) {}
		}
	}

	private static String queryName(ContentResolver resolver, Uri uri)
	{
		String name = null;
		Cursor cursor = null;

		try
		{
			cursor = resolver.query(uri, null, null, null, null);
			if (cursor != null && cursor.moveToFirst())
			{
				int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
				if (index >= 0) name = cursor.getString(index);
			}
		}
		catch (Throwable e) {}
		finally
		{
			if (cursor != null) cursor.close();
		}

		if (name == null || name.length() == 0) name = "imported_" + System.currentTimeMillis();
		return name.replace('/', '_').replace('\\', '_');
	}

	private static <T> T onUiThread(final java.util.concurrent.Callable<T> task, T fallback)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return fallback;

		try
		{
			java.util.concurrent.FutureTask<T> future = new java.util.concurrent.FutureTask<T>(task);
			activity.runOnUiThread(future);
			T result = future.get(500, java.util.concurrent.TimeUnit.MILLISECONDS);
			return result != null ? result : fallback;
		}
		catch (Throwable e)
		{
			return fallback;
		}
	}

	public static String getDeviceModel()
	{
		String manufacturer = Build.MANUFACTURER != null ? Build.MANUFACTURER : "";
		String model = Build.MODEL != null ? Build.MODEL : "";
		if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) return model;
		return (manufacturer + " " + model).trim();
	}

	public static String getOSVersion()
	{
		return "Android " + Build.VERSION.RELEASE + " (API " + Build.VERSION.SDK_INT + ")";
	}

	public static int getBatteryLevel()
	{
		try
		{
			BatteryManager manager = (BatteryManager) Extension.mainContext.getSystemService(Context.BATTERY_SERVICE);
			if (manager == null) return -1;
			int level = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
			return level >= 0 && level <= 100 ? level : -1;
		}
		catch (Throwable e)
		{
			return -1;
		}
	}

	public static boolean isCharging()
	{
		try
		{
			Intent battery = Extension.mainContext.registerReceiver(null, new android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED));
			if (battery == null) return false;
			int status = battery.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
			return status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL;
		}
		catch (Throwable e)
		{
			return false;
		}
	}

	public static boolean isPowerSaveMode()
	{
		try
		{
			PowerManager manager = (PowerManager) Extension.mainContext.getSystemService(Context.POWER_SERVICE);
			return manager != null && manager.isPowerSaveMode();
		}
		catch (Throwable e)
		{
			return false;
		}
	}

	public static void setKeepScreenOn(final boolean value)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					if (value) activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
					else activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
				}
				catch (Throwable e) {}
			}
		});
	}

	public static boolean openURL(final String url)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null || url == null || url.length() == 0) return false;

		try
		{
			Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			activity.startActivity(intent);
			return true;
		}
		catch (Throwable e)
		{
			return false;
		}
	}

	public static void setClipboard(final String text)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					ClipboardManager manager = (ClipboardManager) activity.getSystemService(Context.CLIPBOARD_SERVICE);
					if (manager != null) manager.setPrimaryClip(ClipData.newPlainText("NightmareVision", text != null ? text : ""));
				}
				catch (Throwable e) {}
			}
		});
	}

	public static String getClipboard()
	{
		return onUiThread(new java.util.concurrent.Callable<String>()
		{
			@Override
			public String call()
			{
				final Activity activity = Extension.mainActivity;
				ClipboardManager manager = (ClipboardManager) activity.getSystemService(Context.CLIPBOARD_SERVICE);
				if (manager == null || !manager.hasPrimaryClip()) return "";
				ClipData clip = manager.getPrimaryClip();
				if (clip == null || clip.getItemCount() == 0) return "";
				CharSequence text = clip.getItemAt(0).coerceToText(activity);
				return text != null ? text.toString() : "";
			}
		}, "");
	}

	public static float getRefreshRate()
	{
		Float rate = onUiThread(new java.util.concurrent.Callable<Float>()
		{
			@Override
			public Float call()
			{
				final Activity activity = Extension.mainActivity;
				android.view.Display display = Build.VERSION.SDK_INT >= 30 ? activity.getDisplay() : activity.getWindowManager().getDefaultDisplay();
				if (display == null) return 60f;
				return display.getRefreshRate();
			}
		}, 60f);
		return rate;
	}
}
