package org.nightmarevision;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Build;
import android.os.Bundle;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.Locale;

import org.haxe.extension.Extension;

public class CrashLogger extends Extension
{
	private static final String FOLDER = "logcat";

	private static final String SESSION_FILE = "session.txt";

	private static final String MARKER_FILE = ".running";

	private static final int MAX_FILES = 12;

	private static File directory;

	private static Process liveProcess;

	private static boolean started = false;

	public CrashLogger()
	{
		start();
	}

	@Override
	public void onCreate(Bundle savedInstanceState)
	{
		start();
	}

	@Override
	public void onDestroy()
	{
		stop();
	}

	public static String getLogDirectory()
	{
		return directory != null ? directory.getAbsolutePath() : "";
	}

	public static synchronized void start()
	{
		if (started) return;

		try
		{
			Context context = Extension.mainContext != null ? Extension.mainContext : Extension.mainActivity;
			if (context == null) return;

			directory = resolveDirectory(context);
			if (directory == null) return;

			started = true;

			String stamp = new SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(new Date());

			File marker = new File(directory, MARKER_FILE);
			File session = new File(directory, SESSION_FILE);
			boolean crashed = marker.exists();

			if (session.exists() && session.length() > 0)
				session.renameTo(new File(directory, (crashed ? "crash-session-" : "session-") + stamp + ".txt"));

			if (crashed)
				runToFile(new String[] {"logcat", "-d", "-v", "threadtime", "-b", "main", "-b", "system", "-b", "crash"}, new File(directory, "crash-buffer-" + stamp + ".txt"));

			writeText(new File(directory, "device.txt"), describeDevice(context));
			writeText(marker, stamp);

			prune();
			startLive(session);
			installJavaHandler();
		}
		catch (Throwable e) {}
	}

	public static synchronized void stop()
	{
		try
		{
			if (directory != null) new File(directory, MARKER_FILE).delete();
		}
		catch (Throwable e) {}

		try
		{
			if (liveProcess != null) liveProcess.destroy();
		}
		catch (Throwable e) {}

		liveProcess = null;
	}

	private static File resolveDirectory(Context context)
	{
		File base = StorageHelper.resolveGameDirectory(context);
		if (base == null) return null;

		File dir = new File(base, FOLDER);
		if (!dir.exists()) dir.mkdirs();
		return dir.exists() ? dir : null;
	}

	private static void startLive(File session)
	{
		try
		{
			String since = new SimpleDateFormat("MM-dd HH:mm:ss.000", Locale.US).format(new Date(System.currentTimeMillis() - 2000));
			liveProcess = new ProcessBuilder("logcat", "-v", "threadtime", "-b", "main", "-b", "system", "-b", "crash", "-T", since, "-f", session.getAbsolutePath())
				.redirectErrorStream(true)
				.start();
		}
		catch (Throwable e)
		{
			liveProcess = null;
		}
	}

	private static void installJavaHandler()
	{
		final Thread.UncaughtExceptionHandler previous = Thread.getDefaultUncaughtExceptionHandler();

		Thread.setDefaultUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler()
		{
			@Override
			public void uncaughtException(Thread thread, Throwable error)
			{
				try
				{
					StringWriter writer = new StringWriter();
					error.printStackTrace(new PrintWriter(writer));

					String stamp = new SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(new Date());
					writeText(new File(directory, "java-crash-" + stamp + ".txt"), "Thread: " + thread.getName() + "\n\n" + writer.toString());
				}
				catch (Throwable ignored) {}

				if (previous != null) previous.uncaughtException(thread, error);
			}
		});
	}

	private static String describeDevice(Context context)
	{
		StringBuilder builder = new StringBuilder();

		builder.append("Manufacturer: ").append(Build.MANUFACTURER).append('\n');
		builder.append("Model: ").append(Build.MODEL).append('\n');
		builder.append("Android: ").append(Build.VERSION.RELEASE).append(" (SDK ").append(Build.VERSION.SDK_INT).append(")\n");
		builder.append("ABIs: ").append(Arrays.toString(Build.SUPPORTED_ABIS)).append('\n');

		try
		{
			ApplicationInfo info = context.getApplicationInfo();
			builder.append("Package: ").append(context.getPackageName()).append('\n');
			builder.append("Native library dir: ").append(info.nativeLibraryDir).append('\n');

			File libs = new File(info.nativeLibraryDir);
			String[] names = libs.list();
			if (names != null)
			{
				Arrays.sort(names);
				for (String name : names)
					builder.append("  ").append(name).append(" (").append(new File(libs, name).length()).append(" bytes)\n");
			}
			else
			{
				builder.append("  <empty or not extracted>\n");
			}
		}
		catch (Throwable e)
		{
			builder.append("Native libraries: ").append(e.toString()).append('\n');
		}

		return builder.toString();
	}

	private static void runToFile(String[] command, File output)
	{
		try
		{
			Process process = new ProcessBuilder(command).redirectErrorStream(true).start();
			InputStream input = process.getInputStream();
			OutputStream stream = new FileOutputStream(output, false);

			byte[] buffer = new byte[64 * 1024];
			int read;
			while ((read = input.read(buffer)) != -1)
				stream.write(buffer, 0, read);

			stream.close();
			input.close();
			process.waitFor();

			if (output.length() == 0) output.delete();
		}
		catch (Throwable e) {}
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

	private static void prune()
	{
		try
		{
			File[] files = directory.listFiles();
			if (files == null) return;

			Arrays.sort(files, new java.util.Comparator<File>()
			{
				@Override
				public int compare(File a, File b)
				{
					return Long.compare(a.lastModified(), b.lastModified());
				}
			});

			int count = 0;
			for (File file : files)
				if (isArchive(file)) count++;

			for (File file : files)
			{
				if (count <= MAX_FILES) break;
				if (!isArchive(file)) continue;
				file.delete();
				count--;
			}
		}
		catch (Throwable e) {}
	}

	private static boolean isArchive(File file)
	{
		String name = file.getName();
		return name.startsWith("crash-") || name.startsWith("session-") || name.startsWith("java-crash-");
	}
}
