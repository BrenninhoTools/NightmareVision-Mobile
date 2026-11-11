package funkin.mobile.native;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;

class NativeMacro
{
	public static function build():Null<Array<Field>>
	{
		if (!Context.defined('ios')) return null;
		
		final cls = Context.getLocalClass().get();
		final file = sys.FileSystem.absolutePath(Context.getPosInfos(cls.pos).file);
		var root = Path.directory(file);
		while (root.length > 1 && !sys.FileSystem.exists(Path.join([root, 'projFiles', 'ios'])))
		{
			final parent = Path.directory(root);
			if (parent == root || parent.length == 0) break;
			root = parent;
		}
		final folder = Path.join([Path.normalize(root), 'projFiles', 'ios']);
		
		final xml = '<files id="nmv-native-ios" dir="$folder">'
			+ '<compilerflag value="-fobjc-arc"/>'
			+ '<file name="NativeHelper.mm"/>'
			+ '</files>'
			+ '<target id="haxe"><files id="nmv-native-ios"/></target>';
			
		cls.meta.add(':buildXml', [macro $v{xml}], cls.pos);
		
		return null;
	}
}
#end
