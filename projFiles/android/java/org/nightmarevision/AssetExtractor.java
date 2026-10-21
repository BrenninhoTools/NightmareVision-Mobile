package org.nightmarevision;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.res.AssetManager;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.haxe.extension.Extension;

public class AssetExtractor extends Extension
{
	public static final String STATUS_FILE = ".copy-status";

	private static final String MANIFEST_FILE = ".copy-manifest.txt";

	private static final String VERSION_FILE = ".copy-version";

	private static final String ERROR_FILE = "copy-errors.txt";

	private static final String[] ROOTS = {"assets", "content"};

	private static final String[] ALWAYS_UPDATE = {"assets/"};

	private static final int BUFFER_SIZE = 256 * 1024;

	private static volatile String status = "idle";

	private static volatile int total = 0;

	private static volatile int done = 0;

	private static File gameDirectory;

	private static boolean started = false;

	private static TextView overlay;

	public AssetExtractor()
	{
		start();
	}

	@Override
	public void onCreate(Bundle savedInstanceState)
	{
		start();
	}

	public static String getGameDirectory()
	{
		Context context = getContext();
		if (context == null) return "";
		File dir = resolveGameDirectory(context);
		return dir != null ? dir.getAbsolutePath() : "";
	}

	public static String getStatus()
	{
		return status;
	}

	public static int getProgress()
	{
		return done;
	}

	public static int getTotal()
	{
		return total;
	}

	private static Context getContext()
	{
		if (Extension.mainContext != null) return Extension.mainContext;
		return Extension.mainActivity;
	}

	public static synchronized void start()
	{
		if (started) return;

		final Context context = getContext();
		if (context == null) return;

		gameDirectory = resolveGameDirectory(context);
		if (gameDirectory == null) return;

		started = true;
		status = "running";
		writeText(new File(gameDirectory, STATUS_FILE), "running");

		showOverlay();

		Thread worker = new Thread(new Runnable()
		{
			@Override
			public void run()
			{
				String result = "done";

				try
				{
					extract(context);
				}
				catch (Throwable e)
				{
					result = "error " + e;
				}

				status = result;
				writeText(new File(gameDirectory, STATUS_FILE), result);
				hideOverlay();
			}
		}, "AssetExtractor");

		worker.setPriority(Thread.MAX_PRIORITY);
		worker.start();
	}

	static File resolveGameDirectory(Context context)
	{
		try
		{
			File[] media = context.getExternalMediaDirs();
			if (media != null)
			{
				for (File dir : media)
				{
					if (dir == null) continue;
					if (!dir.exists()) dir.mkdirs();
					if (dir.isDirectory() && dir.canWrite()) return dir;
				}
			}
		}
		catch (Throwable e) {}

		try
		{
			File dir = context.getExternalFilesDir(null);
			if (dir != null)
			{
				if (!dir.exists()) dir.mkdirs();
				if (dir.isDirectory() && dir.canWrite()) return dir;
			}
		}
		catch (Throwable e) {}

		try
		{
			return context.getFilesDir();
		}
		catch (Throwable e)
		{
			return null;
		}
	}

	private static void extract(Context context) throws Exception
	{
		AssetManager assets = Extension.assetManager != null ? Extension.assetManager : context.getAssets();

		List<String> files = new ArrayList<String>();
		for (String root : ROOTS)
			collect(assets, root, files);

		total = files.size();
		done = 0;

		Map<String, Long> manifest = readManifest();
		String version = getVersion(context);
		File versionFile = new File(gameDirectory, VERSION_FILE);
		boolean updated = !version.equals(readText(versionFile));

		List<String> failed = new ArrayList<String>();
		byte[] buffer = new byte[BUFFER_SIZE];
		long lastSave = System.currentTimeMillis();

		for (String path : files)
		{
			File target = new File(gameDirectory, path);

			if (needsCopy(path, target, manifest, updated))
			{
				long size = copy(assets, path, target, buffer);

				if (size < 0) size = copy(assets, path, target, buffer);

				if (size >= 0) manifest.put(path, size);
				else failed.add(path);
			}
			else if (!manifest.containsKey(path))
			{
				manifest.put(path, target.length());
			}

			done++;
			updateOverlay();

			if (System.currentTimeMillis() - lastSave > 1500)
			{
				writeManifest(manifest);
				lastSave = System.currentTimeMillis();
			}
		}

		writeManifest(manifest);

		File errors = new File(gameDirectory, ERROR_FILE);

		if (failed.isEmpty())
		{
			writeText(versionFile, version);
			errors.delete();
		}
		else
		{
			StringBuilder builder = new StringBuilder();
			for (String path : failed)
				builder.append(path).append('\n');
			writeText(errors, builder.toString());
		}
	}

	private static boolean needsCopy(String path, File target, Map<String, Long> manifest, boolean updated)
	{
		if (!target.isFile() || target.length() == 0) return true;

		Long recorded = manifest.get(path);
		boolean always = isAlwaysUpdated(path);

		if (always && (recorded == null || recorded != target.length())) return true;

		if (updated)
		{
			if (always) return true;
			return recorded != null && recorded == target.length();
		}

		return false;
	}

	private static boolean isAlwaysUpdated(String path)
	{
		for (String prefix : ALWAYS_UPDATE)
			if (path.startsWith(prefix)) return true;
		return false;
	}

	private static void collect(AssetManager assets, String path, List<String> output)
	{
		String[] children;

		try
		{
			children = assets.list(path);
		}
		catch (Throwable e)
		{
			children = null;
		}

		if (children == null || children.length == 0)
		{
			if (isFile(assets, path)) output.add(path);
			return;
		}

		for (String child : children)
			collect(assets, path + "/" + child, output);
	}

	private static boolean isFile(AssetManager assets, String path)
	{
		try
		{
			InputStream input = assets.open(path, AssetManager.ACCESS_STREAMING);
			input.close();
			return true;
		}
		catch (Throwable e)
		{
			return false;
		}
	}

	private static long copy(AssetManager assets, String path, File target, byte[] buffer)
	{
		File temp = new File(target.getAbsolutePath() + ".copying");
		InputStream input = null;
		OutputStream output = null;

		try
		{
			File parent = target.getParentFile();
			if (parent != null && !parent.isDirectory() && !parent.mkdirs() && !parent.isDirectory()) return -1;

			input = assets.open(path, AssetManager.ACCESS_STREAMING);
			output = new FileOutputStream(temp, false);

			long size = 0;
			int read;
			while ((read = input.read(buffer)) != -1)
			{
				output.write(buffer, 0, read);
				size += read;
			}

			output.flush();
			output.close();
			output = null;

			if (temp.length() != size) return -1;
			if (target.exists() && !target.delete()) return -1;
			if (!temp.renameTo(target)) return -1;

			return size;
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

	private static String getVersion(Context context)
	{
		try
		{
			PackageInfo info = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
			return info.versionName + "|" + info.lastUpdateTime;
		}
		catch (Throwable e)
		{
			return "unknown";
		}
	}

	private static Map<String, Long> readManifest()
	{
		Map<String, Long> manifest = new HashMap<String, Long>();

		try
		{
			File file = new File(gameDirectory, MANIFEST_FILE);
			if (!file.isFile()) return manifest;

			BufferedReader reader = new BufferedReader(new InputStreamReader(new FileInputStream(file), "UTF-8"));
			String line;
			while ((line = reader.readLine()) != null)
			{
				int tab = line.lastIndexOf('\t');
				if (tab <= 0) continue;

				try
				{
					manifest.put(line.substring(0, tab), Long.parseLong(line.substring(tab + 1)));
				}
				catch (Throwable ignored) {}
			}
			reader.close();
		}
		catch (Throwable e) {}

		return manifest;
	}

	private static void writeManifest(Map<String, Long> manifest)
	{
		StringBuilder builder = new StringBuilder();
		for (Map.Entry<String, Long> entry : manifest.entrySet())
			builder.append(entry.getKey()).append('\t').append(entry.getValue()).append('\n');

		File temp = new File(gameDirectory, MANIFEST_FILE + ".tmp");
		writeText(temp, builder.toString());

		File target = new File(gameDirectory, MANIFEST_FILE);
		target.delete();
		temp.renameTo(target);
	}

	private static String readText(File file)
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

	private static void writeText(File file, String text)
	{
		try
		{
			OutputStream stream = new FileOutputStream(file, false);
			stream.write(text.getBytes("UTF-8"));
			stream.close();
		}
		catch (Throwable e) {}
	}

	private static void showOverlay()
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
					overlay = new TextView(activity);
					overlay.setBackgroundColor(Color.BLACK);
					overlay.setTextColor(Color.WHITE);
					overlay.setTextSize(18);
					overlay.setGravity(Gravity.CENTER);
					overlay.setText("Preparing game files...");
					activity.addContentView(overlay, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
				}
				catch (Throwable e)
				{
					overlay = null;
				}
			}
		});
	}

	private static void updateOverlay()
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null || overlay == null || (done % 10 != 0 && done != total)) return;

		final String text = "Copying game files...\n" + done + " / " + total;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					if (overlay != null) overlay.setText(text);
				}
				catch (Throwable e) {}
			}
		});
	}

	private static void hideOverlay()
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
					if (overlay != null && overlay.getParent() instanceof ViewGroup)
						((ViewGroup) overlay.getParent()).removeView(overlay);
				}
				catch (Throwable e) {}

				overlay = null;
			}
		});
	}
}
