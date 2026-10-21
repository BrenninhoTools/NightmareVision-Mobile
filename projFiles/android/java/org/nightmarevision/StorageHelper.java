package org.nightmarevision;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

import org.haxe.extension.Extension;

public class StorageHelper
{
	private static final int BUFFER_SIZE = 256 * 1024;

	private static final int PERMISSION_REQUEST_CODE = 4100;

	private static final byte[] buffer = new byte[BUFFER_SIZE];

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
