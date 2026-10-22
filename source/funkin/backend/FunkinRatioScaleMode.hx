package funkin.backend;

import flixel.system.scaleModes.RatioScaleMode;

class FunkinRatioScaleMode extends RatioScaleMode
{
	@:isVar public var width(get, set):Null<Int> = null;
	@:isVar public var height(get, set):Null<Int> = null;
	
	public override function updateGameSize(Width:Int, Height:Int):Void
	{
		#if mobile
		lastWindowWidth = Width;
		lastWindowHeight = Height;
		#end
		
		var ratio:Float = width / height;
		var realRatio:Float = Width / Height;
		
		var scaleY:Bool = realRatio < ratio;
		if (fillScreen)
		{
			scaleY = !scaleY;
		}
		
		if (scaleY)
		{
			gameSize.x = Width;
			gameSize.y = Math.floor(gameSize.x / ratio);
		}
		else
		{
			gameSize.y = Height;
			gameSize.x = Math.floor(gameSize.y * ratio);
		}
		
		@:privateAccess {
			for (c in FlxG.cameras.list)
			{
				if (c.width == FlxG.width && c.height == FlxG.height)
				{
					c.width = width;
					c.height = height;
				}
			}
			
			FlxG.width = width;
			FlxG.height = height;
		}
	}
	
	public function resetSize()
	{
		width = null;
		height = null;
	}
	
	#if mobile
	var lastWindowWidth:Int = 0;
	
	var lastWindowHeight:Int = 0;
	#end
	
	private function get_width():Null<Int>
	{
		if (this.width != null) return this.width;
		#if mobile
		final stage = FlxG.stage;
		if (stage != null) return funkin.mobile.ScreenStyle.getGameWidth(lastWindowWidth > 0 ? lastWindowWidth : stage.stageWidth, lastWindowHeight > 0 ? lastWindowHeight : stage.stageHeight);
		#end
		return FlxG.initialWidth;
	}
	
	private inline function get_height():Null<Int> return this.height == null ? FlxG.initialHeight : this.height;
	
	private inline function set_width(v:Null<Int>):Null<Int>
	{
		this.width = v;
		@:privateAccess
		FlxG.game.onResize(null);
		return v;
	}
	
	private inline function set_height(v:Null<Int>):Null<Int>
	{
		this.height = v;
		@:privateAccess
		FlxG.game.onResize(null);
		return v;
	}
}
