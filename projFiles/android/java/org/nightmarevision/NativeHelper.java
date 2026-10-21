package org.nightmarevision;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.provider.OpenableColumns;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

import org.haxe.extension.Extension;

public class NativeHelper extends Extension
{
	private static final int PICK_REQUEST_CODE = 4201;

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

			Vibrator found = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
			if (found != null && found.hasVibrator()) vibrator = found;
		}
		catch (Throwable e)
		{
			vibrator = null;
		}

		return vibrator;
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
}
