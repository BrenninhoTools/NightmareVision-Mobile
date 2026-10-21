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
import java.util.Collections;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
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

	private static final int BUFFER_SIZE = 512 * 1024;

	private static final int MAX_THREADS = 4;

	private static final long MIN_FREE_BYTES = 64L * 1024L * 1024L;

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
		final AssetManager assets = Extension.assetManager != null ? Extension.assetManager : context.getAssets();

		final Map<String, Long> manifest = new ConcurrentHashMap<String, Long>(readManifest());
		final String version = getVersion(context);
		final File versionFile = new File(gameDirectory, VERSION_FILE);
		final boolean updated = !version.equals(readText(versionFile));

		List<String> files;

		if (!updated && !manifest.isEmpty())
		{
			files = new ArrayList<String>(manifest.keySet());
		}
		else
		{
			files = new ArrayList<String>();
			for (String root : ROOTS)
				collect(assets, root, files);
		}

		final List<String> pending = new ArrayList<String>();

		for (String path : files)
		{
			File target = new File(gameDirectory, path);

			if (needsCopy(path, target, manifest, updated)) pending.add(path);
			else if (!manifest.containsKey(path)) manifest.put(path, target.length());
		}

		total = pending.size();
		done = 0;

		if (pending.isEmpty())
		{
			if (updated) writeManifest(manifest);
			writeText(versionFile, version);
			new File(gameDirectory, ERROR_FILE).delete();
			return;
		}

		long freeBytes = gameDirectory.getUsableSpace();
		if (freeBytes > 0 && freeBytes < MIN_FREE_BYTES)
			throw new Exception("not enough free storage (" + (freeBytes / (1024L * 1024L)) + " MB available)");

				createDirectories(pending);
		showOverlay();

		final AtomicInteger cursor = new AtomicInteger(0);
		final AtomicInteger completed = new AtomicInteger(0);
		final List<String> failed = Collections.synchronizedList(new ArrayList<String>());
		final AtomicLong lastSave = new AtomicLong(System.currentTimeMillis());

		int threads = Math.max(2, Math.min(MAX_THREADS, Runtime.getRuntime().availableProcessors()));
		Thread[] workers = new Thread[threads];

		for (int t = 0; t < threads; t++)
		{
			workers[t] = new Thread(new Runnable()
			{
				@Override
				public void run()
				{
					byte[] buffer = new byte[BUFFER_SIZE];

					while (true)
					{
						int index = cursor.getAndIncrement();
						if (index >= pending.size()) break;

						String path = pending.get(index);
						File target = new File(gameDirectory, path);

						long size = copy(assets, path, target, buffer);
						if (size < 0) size = copy(assets, path, target, buffer);

						if (size >= 0) manifest.put(path, size);
						else failed.add(path);

						done = completed.incrementAndGet();
						updateOverlay();

						long now = System.currentTimeMillis();
						long previous = lastSave.get();
						if (now - previous > 1500 && lastSave.compareAndSet(previous, now)) writeManifest(manifest);
					}
				}
			}, "AssetExtractor-" + t);

			workers[t].start();
		}

		for (Thread worker : workers)
			worker.join();

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
			synchronized (failed)
			{
				for (String path : failed)
					builder.append(path).append('\n');
			}
			writeText(errors, builder.toString());
		}
	}

	private static void createDirectories(List<String> paths)
	{
		java.util.HashSet<String> created = new java.util.HashSet<String>();

		for (String path : paths)
		{
			int slash = path.lastIndexOf('/');
			if (slash <= 0) continue;

			String folder = path.substring(0, slash);
			if (!created.add(folder)) continue;

			File dir = new File(gameDirectory, folder);
			if (!dir.isDirectory()) dir.mkdirs();
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
			output.add(path);
			return;
		}

		for (String child : children)
			collect(assets, path + "/" + child, output);
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

	private static synchronized void writeManifest(Map<String, Long> manifest)
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

	private static volatile long lastOverlayUpdate = 0;

	private static void updateOverlay()
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null || overlay == null) return;

		long now = System.currentTimeMillis();
		if (now - lastOverlayUpdate < 100 && done != total) return;
		lastOverlayUpdate = now;

		final int percent = total > 0 ? (int) (done * 100L / total) : 100;
		final String text = "Copying game files... " + percent + "%\n" + done + " / " + total;

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
