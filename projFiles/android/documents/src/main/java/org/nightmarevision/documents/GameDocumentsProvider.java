package org.nightmarevision.documents;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract.Document;
import android.provider.DocumentsContract.Root;
import android.provider.DocumentsProvider;
import android.webkit.MimeTypeMap;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

public class GameDocumentsProvider extends DocumentsProvider
{
	public static final String ROOT_ID = "nightmarevision";

	private static final String[] DEFAULT_ROOT_PROJECTION = new String[] {
		Root.COLUMN_ROOT_ID, Root.COLUMN_FLAGS, Root.COLUMN_ICON, Root.COLUMN_TITLE, Root.COLUMN_SUMMARY, Root.COLUMN_DOCUMENT_ID, Root.COLUMN_AVAILABLE_BYTES, Root.COLUMN_MIME_TYPES
	};

	private static final String[] DEFAULT_DOCUMENT_PROJECTION = new String[] {
		Document.COLUMN_DOCUMENT_ID, Document.COLUMN_MIME_TYPE, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_LAST_MODIFIED, Document.COLUMN_FLAGS, Document.COLUMN_SIZE
	};

	private File base;

	@Override
	public boolean onCreate()
	{
		return true;
	}

	private File getBase()
	{
		if (base == null)
		{
			Context context = getContext();
			File dir = context != null ? context.getExternalFilesDir(null) : null;
			if (dir == null && context != null) dir = context.getFilesDir();
			base = dir;
		}
		return base;
	}

	public static String documentIdFor(File root, File file)
	{
		String rootPath = root.getAbsolutePath();
		String path = file.getAbsolutePath();
		if (path.equals(rootPath)) return ROOT_ID;
		return ROOT_ID + path.substring(rootPath.length());
	}

	private String getDocumentId(File file)
	{
		return documentIdFor(getBase(), file);
	}

	private File getFile(String documentId) throws FileNotFoundException
	{
		File root = getBase();
		if (root == null) throw new FileNotFoundException("No storage");

		if (documentId.equals(ROOT_ID)) return root;
		if (!documentId.startsWith(ROOT_ID + "/")) throw new FileNotFoundException(documentId);

		File file = new File(root, documentId.substring(ROOT_ID.length() + 1));
		try
		{
			if (!file.getCanonicalPath().startsWith(root.getCanonicalPath())) throw new FileNotFoundException(documentId);
		}
		catch (IOException e)
		{
			throw new FileNotFoundException(documentId);
		}
		return file;
	}

	@Override
	public Cursor queryRoots(String[] projection)
	{
		MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_ROOT_PROJECTION);
		File root = getBase();
		if (root == null) return result;

		Context context = getContext();
		ApplicationInfo info = context.getApplicationInfo();
		CharSequence label = info.loadLabel(context.getPackageManager());

		MatrixCursor.RowBuilder row = result.newRow();
		row.add(Root.COLUMN_ROOT_ID, ROOT_ID);
		row.add(Root.COLUMN_DOCUMENT_ID, ROOT_ID);
		row.add(Root.COLUMN_SUMMARY, "Game files and mods");
		row.add(Root.COLUMN_FLAGS, Root.FLAG_SUPPORTS_CREATE | Root.FLAG_SUPPORTS_IS_CHILD | Root.FLAG_LOCAL_ONLY);
		row.add(Root.COLUMN_TITLE, label != null ? label.toString() : "NightmareVision");
		row.add(Root.COLUMN_MIME_TYPES, "*/*");
		row.add(Root.COLUMN_AVAILABLE_BYTES, root.getFreeSpace());
		row.add(Root.COLUMN_ICON, info.icon);
		return result;
	}

	@Override
	public Cursor queryDocument(String documentId, String[] projection) throws FileNotFoundException
	{
		MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
		addRow(result, getFile(documentId));
		return result;
	}

	@Override
	public Cursor queryChildDocuments(String parentDocumentId, String[] projection, String sortOrder) throws FileNotFoundException
	{
		MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
		File parent = getFile(parentDocumentId);
		File[] children = parent.listFiles();
		if (children != null)
			for (File child : children)
				addRow(result, child);
		return result;
	}

	@Override
	public ParcelFileDescriptor openDocument(String documentId, String mode, CancellationSignal signal) throws FileNotFoundException
	{
		return ParcelFileDescriptor.open(getFile(documentId), ParcelFileDescriptor.parseMode(mode));
	}

	@Override
	public boolean isChildDocument(String parentDocumentId, String documentId)
	{
		return documentId.equals(parentDocumentId) || documentId.startsWith(parentDocumentId + "/");
	}

	@Override
	public String createDocument(String parentDocumentId, String mimeType, String displayName) throws FileNotFoundException
	{
		File parent = getFile(parentDocumentId);
		File file = new File(parent, displayName);
		int index = 1;
		while (file.exists())
			file = new File(parent, appendIndex(displayName, index++));

		try
		{
			boolean created = Document.MIME_TYPE_DIR.equals(mimeType) ? file.mkdirs() : file.createNewFile();
			if (!created) throw new FileNotFoundException("Could not create " + displayName);
		}
		catch (IOException e)
		{
			throw new FileNotFoundException(e.getMessage());
		}

		return getDocumentId(file);
	}

	@Override
	public void deleteDocument(String documentId) throws FileNotFoundException
	{
		File file = getFile(documentId);
		if (!deleteRecursive(file)) throw new FileNotFoundException("Could not delete " + documentId);
	}

	@Override
	public String renameDocument(String documentId, String displayName) throws FileNotFoundException
	{
		File file = getFile(documentId);
		File target = new File(file.getParentFile(), displayName);
		if (target.exists() || !file.renameTo(target)) throw new FileNotFoundException("Could not rename " + documentId);
		return getDocumentId(target);
	}

	@Override
	public String getDocumentType(String documentId) throws FileNotFoundException
	{
		return mimeTypeOf(getFile(documentId));
	}

	private void addRow(MatrixCursor result, File file)
	{
		int flags = 0;
		if (file.isDirectory())
		{
			if (file.canWrite()) flags |= Document.FLAG_DIR_SUPPORTS_CREATE;
		}
		else if (file.canWrite())
		{
			flags |= Document.FLAG_SUPPORTS_WRITE;
		}

		if (file.canWrite() && !file.equals(getBase())) flags |= Document.FLAG_SUPPORTS_DELETE | Document.FLAG_SUPPORTS_RENAME;

		MatrixCursor.RowBuilder row = result.newRow();
		row.add(Document.COLUMN_DOCUMENT_ID, getDocumentId(file));
		row.add(Document.COLUMN_DISPLAY_NAME, file.equals(getBase()) ? "NightmareVision" : file.getName());
		row.add(Document.COLUMN_SIZE, file.length());
		row.add(Document.COLUMN_MIME_TYPE, mimeTypeOf(file));
		row.add(Document.COLUMN_LAST_MODIFIED, file.lastModified());
		row.add(Document.COLUMN_FLAGS, flags);
	}

	private static String mimeTypeOf(File file)
	{
		if (file.isDirectory()) return Document.MIME_TYPE_DIR;

		String name = file.getName();
		int dot = name.lastIndexOf('.');
		if (dot >= 0)
		{
			String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(name.substring(dot + 1).toLowerCase());
			if (mime != null) return mime;
		}
		return "application/octet-stream";
	}

	private static String appendIndex(String name, int index)
	{
		int dot = name.lastIndexOf('.');
		if (dot <= 0) return name + " (" + index + ")";
		return name.substring(0, dot) + " (" + index + ")" + name.substring(dot);
	}

	private static boolean deleteRecursive(File file)
	{
		File[] children = file.isDirectory() ? file.listFiles() : null;
		if (children != null)
			for (File child : children)
				deleteRecursive(child);
		return file.delete() || !file.exists();
	}
}
