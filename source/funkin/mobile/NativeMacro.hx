package funkin.mobile;

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
		final root = Path.normalize(Path.join([Path.directory(file), '..', '..', '..']));
		final folder = Path.join([root, 'projFiles', 'ios']);
		
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
