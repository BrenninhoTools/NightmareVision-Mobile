package funkin.api;

#if DISCORD_ALLOWED
import sys.thread.Mutex;
import sys.thread.Thread;

import hxdiscord_rpc.Types.DiscordEventHandlers;
import hxdiscord_rpc.Types.DiscordUser;
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types.DiscordRichPresence;

class DiscordClient
{
	/**
	 * NightmareVisions specific id
	 */
	public static final NMV_ID:String = '1252033037680513115';

	public static final MOBILE_ID:String = '1540653184530251847';

	public static final DEFAULT_ID:String = #if android MOBILE_ID #else NMV_ID #end;
	
	public static final ICON_URL:String = 'https://raw.githubusercontent.com/BrenninhoTools/NightmareVision-Mobile/dev/projFiles/icon/iconOG.png';

	static inline final TICK_INTERVAL:Float = 0.5;

	static inline final SEND_INTERVAL:Float = 1.5;

	static inline final RETRY_INTERVAL:Float = 10;

	/**
	 * Additional thread to run discord tasks without lagspikes
	 */
	static var thread:Null<Thread> = null;

	static final lock:Mutex = new Mutex();

	/**
	 * internal bool to check if the discord RPC is initiated
	 */
	static var initiated:Bool = false;

	static var hooked:Bool = false;

	static var connected:Bool = false;

	static var pending:Bool = false;

	static var forced:Bool = false;

	static var lastSent:Float = -1e9;

	static var lastKey:String = '';

	static var retryAt:Float = 0;

	static var presenceDetails:Null<String> = 'In the Menus';

	static var presenceState:Null<String> = null;

	static var presenceSmallImage:Null<String> = null;

	static var presenceLargeImage:Null<String> = resolveImage('icon');

	static var presenceLargeText:Null<String> = null;

	static var presenceStart:Int = 0;

	static var presenceEnd:Int = 0;

	/**
	 * The current discord RPC id
	 *
	 * change this to set it to display your own mod
	 */
	public static var rpcId(default, set):String = DEFAULT_ID;

	/**
	 * The active RPC presence.
	 *
	 * use `changePresence` to change the displayed presence
	 */
	public static final discordPresence:DiscordRichPresence = new DiscordRichPresence();

	/**
	 * The string value of the currently connected discord user.
	 * Only used for gags in individual mods, it serves no real purpose.
	 */
	public static var username:String = 'Unknown';

	public static var supported(get, never):Bool;

	static function get_supported():Bool
	{
		return Discord.IsSupported();
	}

	/**
	 * Initiates the discord thread and hooks to `rpcId`
	 */
	public static function init()
	{
		if (!ClientPrefs.discordEnabled || !supported)
		{
			close();
			return;
		}

		lock.acquire();
		if (!initiated)
		{
			final discordEventHandlers = new DiscordEventHandlers();

			discordEventHandlers.ready = cpp.Function.fromStaticFunction(onReady);
			discordEventHandlers.errored = cpp.Function.fromStaticFunction(onError);
			discordEventHandlers.disconnected = cpp.Function.fromStaticFunction(onDisconnect);

			Discord.Initialize(rpcId, cpp.RawPointer.addressOf(discordEventHandlers), true, null);

			initiated = true;
			connected = false;
			lastKey = '';
			pending = true;
			forced = true;
		}
		lock.release();

		if (thread == null) thread = Thread.create(loop);

		hookLifecycle();
	}

	static function loop():Void
	{
		while (true)
		{
			lock.acquire();
			if (initiated)
			{
				#if DISCORD_DISABLE_IO_THREAD
				Discord.UpdateConnection();
				#end
				Discord.RunCallbacks();
				flush();
			}
			lock.release();

			Sys.sleep(TICK_INTERVAL);
		}
	}

	static function hookLifecycle():Void
	{
		if (hooked) return;
		hooked = true;

		FlxG.stage.window.onClose.add(close);
		lime.app.Application.current?.onExit.add((_) -> close());

		#if mobile
		FlxG.stage.window.onActivate.add(refresh);
		#end
	}

	/**
	 * Sends the current presence again, even when nothing changed
	 */
	public static function refresh():Void
	{
		lock.acquire();
		if (initiated)
		{
			pending = true;
			forced = true;
		}
		lock.release();
	}

	/**
	 * Shuts down the current discord RPC connection
	 */
	public static function close():Void
	{
		lock.acquire();
		if (initiated)
		{
			Discord.Shutdown();
			Logger.log('user [$username] has disconnected.', NOTICE);
		}

		username = 'Unknown';
		initiated = false;
		connected = false;
		pending = false;
		forced = false;
		lastKey = '';
		retryAt = 0;
		lock.release();
	}

	/**
	 * Restarts the current discord RPC connection
	 */
	public static function restart():Void
	{
		close();
		init();
	}

	/**
	 * Triggered when discord connection fails.
	 */
	static function onError(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		Logger.log('Discord Error. [$errorCode: ${(cast message : String)}]');

		retryAt = haxe.Timer.stamp() + RETRY_INTERVAL;
		lastKey = '';
		pending = true;
	}

	/**
	 * Triggered when discord connection is lost.
	 */
	static function onDisconnect(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		Logger.log('Discord Disconnected. [$errorCode: ${(cast message : String)}]');

		connected = false;
		lastKey = '';
	}

	/**
	 * Triggered when discord connection is successfully connected
	 */
	static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void
	{
		final user:String = cast request[0].username;
		final discriminator:String = cast request[0].discriminator;

		username = discriminator != '0' ? '$user#$discriminator' : '$user';
		if (username.length == 0) username = 'Unknown';
		Logger.log('Successfully connected to user [$username]', NOTICE);

		connected = true;
		lastKey = '';
		pending = true;
		forced = true;
	}

	/**
	 * Helper function to change the current RPC presence more easily
	 * @param details
	 * @param state
	 * @param smallImageKey
	 * @param hasStartTimestamp
	 * @param endTimestamp
	 */
	public static function changePresence(details:String = 'In the Menus', ?state:String, ?smallImageKey:String, hasStartTimestamp:Bool = false, ?endTimestamp:Float,
			largeImageKey:String = 'icon'):Void
	{
		final now:Float = Date.now().getTime();
		final start:Float = hasStartTimestamp ? now : 0;
		final end:Float = endTimestamp != null && endTimestamp > 0 ? (hasStartTimestamp ? start : now) + endTimestamp : 0;

		lock.acquire();
		presenceDetails = details;
		presenceState = state;
		presenceSmallImage = smallImageKey;
		presenceLargeImage = resolveImage(largeImageKey);
		presenceLargeText = 'FNF NMV (${Main.NMV_VERSION})' + platformName();
		presenceStart = Std.int(start / 1000);
		presenceEnd = Std.int(end / 1000);
		pending = true;
		lock.release();
	}

	static function resolveImage(key:Null<String>):Null<String>
	{
		#if mobile
		if (key == null || key.length == 0 || key == 'icon') return ICON_URL;
		#end
		return key;
	}
	
	static function platformName():String
	{
		#if android
		return ' - Android';
		#elseif ios
		return ' - iOS';
		#else
		return '';
		#end
	}

	static function presenceKey():String
	{
		return [
			presenceDetails,
			presenceState,
			presenceSmallImage,
			presenceLargeImage,
			presenceLargeText,
			Std.string(presenceStart),
			Std.string(presenceEnd)
		].join('\n');
	}

	static function flush():Void
	{
		if (!pending) return;

		final now = haxe.Timer.stamp();
		if (now - lastSent < SEND_INTERVAL) return;
		if (!forced && now < retryAt) return;

		final key = presenceKey();
		pending = false;
		if (!forced && key == lastKey) return;

		forced = false;
		lastKey = key;
		lastSent = now;

		discordPresence.details = presenceDetails;
		discordPresence.state = presenceState;
		discordPresence.smallImageKey = presenceSmallImage;
		discordPresence.largeImageKey = presenceLargeImage;
		discordPresence.largeImageText = presenceLargeText;
		discordPresence.startTimestamp = presenceStart;
		discordPresence.endTimestamp = presenceEnd;

		Discord.UpdatePresence(cpp.RawConstPointer.addressOf(discordPresence));
	}

	static function set_rpcId(value:String):String
	{
		if (value == null || value.length == 0) value = DEFAULT_ID;
		if (rpcId == value) return rpcId;

		rpcId = value;
		if (initiated) restart();
		return rpcId;
	}
}
#else

/**
 * Dummy class
 *
 * Does nothing but exists for the cases discord is unavailable.
 */
class DiscordClient
{
	public static final NMV_ID:String = '';

	public static final MOBILE_ID:String = '';

	public static final DEFAULT_ID:String = '';
	
	public static final ICON_URL:String = '';

	public static var rpcId(default, set):String = '';

	public static var supported(get, never):Bool;

	static function get_supported():Bool return false;

	public static inline function changePresence(details:String = 'In the Menus', ?state:String, ?smallImageKey:String, hasStartTimestamp:Bool = false, ?endTimestamp:Float,
		largeImageKey:String = 'icon'):Void {}

	public static function close():Void {}

	public static function init():Void {}

	public static function restart():Void {}

	public static function refresh():Void {}

	static function set_rpcId(value:String):String return (rpcId = value);
}
#end
