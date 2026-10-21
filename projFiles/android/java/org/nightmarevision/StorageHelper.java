package org.nightmarevision;

import android.content.res.AssetManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

import org.haxe.extension.Extension;

public class StorageHelper
{
	private static final int BUFFER_SIZE = 256 * 1024;

	private static final byte[] buffer = new byte[BUFFER_SIZE];

	private static AssetManager getAssetManager()
	{
		if (Extension.assetManager != null) return Extension.assetManager;
		if (Extension.mainContext != null) return Extension.mainContext.getAssets();
		return null;
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
}
