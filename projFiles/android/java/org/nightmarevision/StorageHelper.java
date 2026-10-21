package org.nightmarevision;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

import org.haxe.extension.Extension;

public class StorageHelper
{
	private static final int BUFFER_SIZE = 256 * 1024;

	private static final int PERMISSION_REQUEST_CODE = 4100;

	private static final byte[] buffer = new byte[BUFFER_SIZE];

	public static final String TYPE_DATA = "DATA";

	public static final String TYPE_EXTERNAL = "EXTERNAL";

	public static final String TYPE_MEDIA = "MEDIA";

	public static final String TYPE_OBB = "OBB";

	public static final String TYPE_INTERNAL = "INTERNAL";

	public static final String DEFAULT_TYPE = TYPE_MEDIA;

	public static final String EXTERNAL_FOLDER = "NightmareVision";

	private static final String TYPE_FILE = "storage-type.txt";

	private static final String LAST_DIRECTORY_FILE = "storage-last.txt";

	private static final String[] FALLBACK_ORDER = {TYPE_MEDIA, TYPE_DATA, TYPE_OBB};

	private static final String[] COPY_MARKERS = {"assets", ".copy-manifest.txt", ".copy-version", ".copy-status", ".storage-manifest.json"};

	private static File cachedGameDirectory;

	private static String activeType = "";

	private static String previousDirectory = "";

	public static String normalizeType(String type)
	{
		if (type == null) return DEFAULT_TYPE;

		String value = type.trim().toUpperCase(java.util.Locale.ROOT);
		if (value.equals(TYPE_DATA) || value.equals(TYPE_EXTERNAL) || value.equals(TYPE_MEDIA) || value.equals(TYPE_OBB)) return value;
		return DEFAULT_TYPE;
	}

	public static String getStorageType()
	{
		Context context = getContext();
		if (context == null) return DEFAULT_TYPE;
		return readStorageType(context);
	}

	static String readStorageType(Context context)
	{
		try
		{
			return normalizeType(readLine(new File(context.getFilesDir(), TYPE_FILE)));
		}
		catch (Throwable e)
		{
			return DEFAULT_TYPE;
		}
	}

	public static void setStorageType(String type)
	{
		try
		{
			Context context = getContext();
			if (context == null) return;
			writeLine(new File(context.getFilesDir(), TYPE_FILE), normalizeType(type));
		}
		catch (Throwable e) {}
	}

	public static String getActiveStorageType()
	{
		Context context = getContext();
		if (context != null) resolveGameDirectory(context);
		return activeType;
	}

	public static String getPreviousDirectory()
	{
		Context context = getContext();
		if (context != null) resolveGameDirectory(context);
		return previousDirectory;
	}

	public static String getStorageTypeDirectory(String type)
	{
		try
		{
			Context context = getContext();
			if (context == null) return "";

			File dir = locateType(context, normalizeType(type));
			return dir != null ? dir.getAbsolutePath() : "";
		}
		catch (Throwable e)
		{
			return "";
		}
	}

	public static boolean isStorageTypeAvailable(String type)
	{
		try
		{
			Context context = getContext();
			if (context == null) return false;

			String normalized = normalizeType(type);
			if (normalized.equals(TYPE_EXTERNAL) && !hasAllFilesAccess()) return false;

			return prepareType(context, normalized) != null;
		}
		catch (Throwable e)
		{
			return false;
		}
	}

	public static synchronized File resolveGameDirectory(Context context)
	{
		if (cachedGameDirectory != null) return cachedGameDirectory;
		if (context == null) return null;

		String preferred = readStorageType(context);
		File dir = prepareType(context, preferred);

		if (dir != null)
		{
			activeType = preferred;
		}
		else
		{
			for (String type : FALLBACK_ORDER)
			{
				if (type.equals(preferred)) continue;

				dir = prepareType(context, type);
				if (dir != null)
				{
					activeType = type;
					break;
				}
			}
		}

		if (dir == null)
		{
			try
			{
				dir = context.getFilesDir();
				activeType = TYPE_INTERNAL;
			}
			catch (Throwable e)
			{
				return null;
			}
		}

		try
		{
			File last = new File(context.getFilesDir(), LAST_DIRECTORY_FILE);
			previousDirectory = readLine(last);
			if (!dir.getAbsolutePath().equals(previousDirectory)) writeLine(last, dir.getAbsolutePath());
			else previousDirectory = "";
		}
		catch (Throwable e)
		{
			previousDirectory = "";
		}

		ensureNoMedia(dir);

		cachedGameDirectory = dir;
		return dir;
	}

	static File locateType(Context context, String type)
	{
		try
		{
			if (type.equals(TYPE_DATA)) return context.getExternalFilesDir(null);

			if (type.equals(TYPE_OBB)) return context.getObbDir();

			if (type.equals(TYPE_EXTERNAL))
			{
				if (!Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState())) return null;
				return new File(Environment.getExternalStorageDirectory(), EXTERNAL_FOLDER);
			}

			File[] media = context.getExternalMediaDirs();
			if (media != null)
			{
				for (File dir : media)
					if (dir != null) return dir;
			}
		}
		catch (Throwable e) {}

		return null;
	}

	static File prepareType(Context context, String type)
	{
		if (type.equals(TYPE_EXTERNAL) && !hasAllFilesAccess()) return null;

		File dir = locateType(context, type);
		return isWritable(dir) ? dir : null;
	}

	static void ensureNoMedia(File dir)
	{
		try
		{
			File marker = new File(dir, ".nomedia");
			if (!marker.exists()) new FileOutputStream(marker, false).close();
		}
		catch (Throwable e) {}
	}

	static boolean isWritable(File dir)
	{
		if (dir == null) return false;

		try
		{
			if (!dir.isDirectory() && !dir.mkdirs() && !dir.isDirectory()) return false;

			File probe = new File(dir, ".write-test");
			FileOutputStream stream = new FileOutputStream(probe, false);
			stream.write('k');
			stream.close();

			boolean valid = probe.isFile() && probe.length() == 1;
			probe.delete();
			return valid;
		}
		catch (Throwable e)
		{
			return false;
		}
	}

	public static void cleanOtherLocations()
	{
		final Context context = getContext();
		if (context == null) return;

		final File active = resolveGameDirectory(context);
		if (active == null) return;

		new Thread(new Runnable()
		{
			@Override
			public void run()
			{
				String[] types = {TYPE_DATA, TYPE_MEDIA, TYPE_OBB, TYPE_EXTERNAL};

				for (String type : types)
				{
					try
					{
						if (type.equals(TYPE_EXTERNAL) && !hasAllFilesAccess()) continue;

						File dir = locateType(context, type);
						if (dir == null || !dir.isDirectory() || dir.getAbsolutePath().equals(active.getAbsolutePath())) continue;

						for (String marker : COPY_MARKERS)
							deleteRecursive(new File(dir, marker));
					}
					catch (Throwable e) {}
				}
			}
		}, "StorageCleaner").start();
	}

	static void deleteRecursive(File file)
	{
		if (file == null || !file.exists()) return;

		File[] children = file.isDirectory() ? file.listFiles() : null;
		if (children != null)
		{
			for (File child : children)
				deleteRecursive(child);
		}

		file.delete();
	}

	public static void restartApp()
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
					Intent intent = activity.getPackageManager().getLaunchIntentForPackage(activity.getPackageName());
					if (intent == null) return;

					intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
					activity.startActivity(intent);
					activity.finishAffinity();

					new Handler(Looper.getMainLooper()).postDelayed(new Runnable()
					{
						@Override
						public void run()
						{
							android.os.Process.killProcess(android.os.Process.myPid());
							System.exit(0);
						}
					}, 250);
				}
				catch (Throwable e) {}
			}
		});
	}

	static String readLine(File file)
	{
		try
		{
			if (!file.isFile()) return "";

			BufferedReader reader = new BufferedReader(new InputStreamReader(new FileInputStream(file), "UTF-8"));
			String line = reader.readLine();
			reader.close();
			return line != null ? line.trim() : "";
		}
		catch (Throwable e)
		{
			return "";
		}
	}

	static void writeLine(File file, String text)
	{
		try
		{
			FileOutputStream stream = new FileOutputStream(file, false);
			stream.write(text.getBytes("UTF-8"));
			stream.close();
		}
		catch (Throwable e) {}
	}

	private static AssetManager getAssetManager()
	{
		if (Extension.assetManager != null) return Extension.assetManager;
		if (Extension.mainContext != null) return Extension.mainContext.getAssets();
		return null;
	}

	private static Context getContext()
	{
		if (Extension.mainContext != null) return Extension.mainContext;
		return Extension.mainActivity;
	}

	public static synchronized int copyAsset(String assetPath, String destinationPath)
	{
		AssetManager assets = getAssetManager();
		if (assets == null || assetPath == null || destinationPath == null) return -1;

		File destination = new File(destinationPath);
		File temp = new File(destinationPath + ".copying");

		InputStream input = null;
		OutputStream output = null;

		try
		{
			File parent = destination.getParentFile();
			if (parent != null && !parent.exists() && !parent.mkdirs() && !parent.exists()) return -1;

			input = assets.open(assetPath, AssetManager.ACCESS_STREAMING);
			output = new FileOutputStream(temp, false);

			long total = 0;
			int read;

			while ((read = input.read(buffer)) != -1)
			{
				output.write(buffer, 0, read);
				total += read;
			}

			output.flush();
			output.close();
			output = null;

			if (temp.length() != total) return -1;

			if (destination.exists() && !destination.delete()) return -1;
			if (!temp.renameTo(destination)) return -1;

			return total > Integer.MAX_VALUE ? Integer.MAX_VALUE : (int) total;
		}
		catch (Throwable e)
		{
			return -1;
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

			if (temp.exists()) temp.delete();
		}
	}

	public static boolean assetExists(String assetPath)
	{
		AssetManager assets = getAssetManager();
		if (assets == null || assetPath == null) return false;

		try
		{
			InputStream input = assets.open(assetPath, AssetManager.ACCESS_STREAMING);
			input.close();
			return true;
		}
		catch (Throwable e)
		{
			return false;
		}
	}

	public static String getMediaDirectory()
	{
		try
		{
			Context context = getContext();
			if (context == null) return "";

			File[] dirs = context.getExternalMediaDirs();
			if (dirs == null) return "";

			for (File dir : dirs)
			{
				if (dir == null) continue;
				if (!dir.exists()) dir.mkdirs();
				if (dir.exists() && dir.canWrite()) return dir.getAbsolutePath();
			}
		}
		catch (Throwable e) {}

		return "";
	}

	public static String getExternalFilesDirectory()
	{
		try
		{
			Context context = getContext();
			if (context == null) return "";

			File dir = context.getExternalFilesDir(null);
			if (dir == null) return "";
			if (!dir.exists()) dir.mkdirs();
			return dir.getAbsolutePath();
		}
		catch (Throwable e)
		{
			return "";
		}
	}

	public static String getInternalFilesDirectory()
	{
		try
		{
			Context context = getContext();
			if (context == null) return "";

			File dir = context.getFilesDir();
			return dir != null ? dir.getAbsolutePath() : "";
		}
		catch (Throwable e)
		{
			return "";
		}
	}

	public static int getFreeSpaceMB(String path)
	{
		try
		{
			File file = new File(path);
			while (file != null && !file.exists()) file = file.getParentFile();
			if (file == null) return -1;
			long bytes = file.getUsableSpace();
			return (int) Math.min(Integer.MAX_VALUE, bytes / (1024L * 1024L));
		}
		catch (Throwable e)
		{
			return -1;
		}
	}

	public static int getSdkVersion()
	{
		return Build.VERSION.SDK_INT;
	}

	public static boolean hasPermission(String permission)
	{
		try
		{
			Context context = getContext();
			if (context == null || permission == null) return false;
			if (Build.VERSION.SDK_INT < 23) return true;
			return context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED;
		}
		catch (Throwable e)
		{
			return false;
		}
	}

	public static boolean hasAllFilesAccess()
	{
		try
		{
			if (Build.VERSION.SDK_INT >= 30) return Environment.isExternalStorageManager();
			return hasPermission("android.permission.WRITE_EXTERNAL_STORAGE");
		}
		catch (Throwable e)
		{
			return false;
		}
	}

	public static void requestPermissions(String permissions)
	{
		try
		{
			final Activity activity = Extension.mainActivity;
			if (activity == null || permissions == null || Build.VERSION.SDK_INT < 23) return;

			final List<String> missing = new ArrayList<String>();

			for (String permission : permissions.split(","))
			{
				String name = permission.trim();
				if (name.length() == 0) continue;
				if (!name.contains(".")) name = "android.permission." + name;
				if (!hasPermission(name)) missing.add(name);
			}

			if (missing.isEmpty()) return;

			activity.runOnUiThread(new Runnable()
			{
				@Override
				public void run()
				{
					try
					{
						activity.requestPermissions(missing.toArray(new String[0]), PERMISSION_REQUEST_CODE);
					}
					catch (Throwable e) {}
				}
			});
		}
		catch (Throwable e) {}
	}

	public static void requestAllFilesAccess()
	{
		try
		{
			final Activity activity = Extension.mainActivity;
			if (activity == null || Build.VERSION.SDK_INT < 30 || Environment.isExternalStorageManager()) return;

			activity.runOnUiThread(new Runnable()
			{
				@Override
				public void run()
				{
					try
					{
						Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
						intent.setData(Uri.parse("package:" + activity.getPackageName()));
						activity.startActivity(intent);
					}
					catch (Throwable e)
					{
						try
						{
							activity.startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
						}
						catch (Throwable ignored) {}
					}
				}
			});
		}
		catch (Throwable e) {}
	}
}
