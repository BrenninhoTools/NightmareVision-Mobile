package funkin.backend;

import haxe.CallStack;
import haxe.io.Path;

import openfl.Lib;
import openfl.errors.Error;
import openfl.events.ErrorEvent;
import openfl.events.UncaughtErrorEvent;

import flixel.FlxG;
import flixel.addons.transition.FlxTransitionableState;

class AntiCrash
{
	public static var crashWindow:Float = 10;

	public static var maxCrashesInWindow:Int = 3;

	public static var lastReport(default, null):String = '';

	public static var lastReportPath(default, null):String = '';

	static var initialized:Bool = false;

	static var handling:Bool = false;

	static var crashTimes:Array<Float> = [];

	public static function init():Void
	{
		if (initialized) return;
		initialized = true;

		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);

		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(onCriticalError);
		#end
	}

	public static function guard(name:String, func:Void->Void):Bool
	{
		try
		{
			func();
			return true;
		}
		catch (e:haxe.Exception)
		{
			handle('$name: ${e.message}', formatStack(cast e.stack), false);
		}

		return false;
	}

	static function onCriticalError(message:String):Void
	{
		final report = buildReport('Critical error: $message', formatStack(CallStack.callStack()));
		save(report);
		throw Std.string(message);
	}

	static function onUncaughtError(event:UncaughtErrorEvent):Void
	{
		event.preventDefault();
		event.stopPropagation();
		event.stopImmediatePropagation();

		handle(describe(event.error), formatStack(CallStack.exceptionStack(true)), true);
	}

	static function handle(message:String, stack:String, recover:Bool):Void
	{
		final report = buildReport(message, stack);
		save(report);

		if (handling || isCrashLoop())
		{
			fatal(report);
			return;
		}

		if (!recover || FlxG.game == null || FlxG.state == null) return;

		handling = true;

		try
		{
			FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = true;

			if (Std.isOfType(FlxG.state, FallbackState))
			{
				handling = false;
				fatal(report);
				return;
			}

			FlxG.state.persistentUpdate = FlxG.state.persistentDraw = false;

			FlxG.sound?.music?.stop();

			final shortReport = summarize(report);
			FlxG.switchState(() -> new FallbackState(shortReport, recoverToMenu));
		}
		catch (e:Dynamic)
		{
			handling = false;
			fatal(report);
			return;
		}

		handling = false;
	}

	static function recoverToMenu():Void
	{
		FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = true;

		try
		{
			FlxG.switchState(() -> new funkin.states.MainMenuState());
		}
		catch (e:Dynamic)
		{
			fatal(lastReport);
		}
	}

	static function isCrashLoop():Bool
	{
		final now = haxe.Timer.stamp();

		crashTimes.push(now);

		while (crashTimes.length > 0 && now - crashTimes[0] > crashWindow)
			crashTimes.shift();

		return crashTimes.length >= maxCrashesInWindow;
	}

	static function fatal(report:String):Void
	{
		final message = summarize(report) + (lastReportPath.length > 0 ? '\n\nSaved to: $lastReportPath' : '');

		try
		{
			lime.app.Application.current?.window?.alert(message, 'NightmareVision crashed');
		}
		catch (e:Dynamic) {}

		#if sys
		Sys.exit(1);
		#end
	}

	static function buildReport(message:String, stack:String):String
	{
		var stateName = 'N/A';

		try
		{
			if (FlxG.state != null) stateName = Type.getClassName(Type.getClass(FlxG.state)) ?? 'N/A';
		}
		catch (e:Dynamic) {}

		final lines:Array<String> = [];
		lines.push('NightmareVision ${Main.NMV_VERSION} (app ${lime.app.Application.current?.meta?.get('version') ?? '?'})');
		lines.push('Platform: ${lime.system.System.platformLabel ?? 'unknown'} ${lime.system.System.platformVersion ?? ''}');
		lines.push('Device: ${lime.system.System.deviceVendor ?? ''} ${lime.system.System.deviceModel ?? ''}');
		lines.push('Date: ${Date.now().toString()}');
		lines.push('State: $stateName');
		lines.push('');
		lines.push('Exception: $message');
		lines.push('');
		lines.push('Callstack:');
		lines.push(stack.length > 0 ? stack : 'N/A');

		return lastReport = lines.join('\n');
	}

	static function summarize(report:String):String
	{
		final lines = report.split('\n');
		final start = lines.indexOf('') + 1;
		final body = lines.slice(start, start + 12).join('\n');
		return body.length > 900 ? body.substr(0, 900) + '...' : body;
	}

	static function save(report:String):Void
	{
		#if sys
		try
		{
			final folder = Path.join([getLogDirectory(), 'crash']);
			if (!sys.FileSystem.exists(folder)) sys.FileSystem.createDirectory(folder);

			final file = Path.join([folder, 'crash-' + DateTools.format(Date.now(), '%Y-%m-%d_%H-%M-%S') + '.txt']);
			sys.io.File.saveContent(file, report);
			lastReportPath = file;
		}
		catch (e:Dynamic) {}
		#end
	}

	static function getLogDirectory():String
	{
		#if mobile
		if (funkin.mobile.StorageUtil.directory.length > 0) return funkin.mobile.StorageUtil.directory;
		return lime.system.System.applicationStorageDirectory;
		#elseif sys
		return Sys.getCwd();
		#else
		return '';
		#end
	}

	static function describe(error:Dynamic):String
	{
		if (Std.isOfType(error, Error)) return (cast error : Error).message;
		if (Std.isOfType(error, ErrorEvent)) return (cast error : ErrorEvent).text;
		if (Std.isOfType(error, haxe.Exception)) return (cast error : haxe.Exception).message;
		return Std.string(error);
	}

	static function formatStack(stack:Array<StackItem>):String
	{
		final buffer = new StringBuf();

		for (item in stack)
		{
			formatItem(buffer, item);
			buffer.add('\n');
		}

		return buffer.toString().trim();
	}

	static function formatItem(buffer:StringBuf, item:StackItem):Void
	{
		switch (item)
		{
			case CFunction:
				buffer.add('C function');
			case Module(m):
				buffer.add('Module $m');
			case FilePos(s, file, line, column):
				if (s != null)
				{
					formatItem(buffer, s);
					buffer.add(' ');
				}
				buffer.add('($file:$line)');
			case Method(classname, method):
				buffer.add('$classname.$method');
			case LocalFunction(v):
				buffer.add('local function #$v');
		}
	}
}
