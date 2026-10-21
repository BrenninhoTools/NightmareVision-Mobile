package external.memory;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;

class MemoryMacro
{
	public static function build():Null<Array<Field>>
	{
		final cls = Context.getLocalClass().get();
		final file = sys.FileSystem.absolutePath(Context.getPosInfos(cls.pos).file);
		final directory = Path.normalize(Path.directory(file));
		
		cls.meta.add(':buildXml', [macro $v{'<include name="$directory/build.xml" />'}], cls.pos);
		
		return null;
	}
}
#end
