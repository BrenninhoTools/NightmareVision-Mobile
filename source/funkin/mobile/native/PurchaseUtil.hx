package funkin.mobile.native;

#if (android && extension_iapcore)
import extension.iapcore.android.IAPAndroid;
import extension.iapcore.android.IAPConnectionState;
import extension.iapcore.android.IAPPurchase;
import extension.iapcore.android.IAPPurchaseState;
import extension.iapcore.android.IAPResponseCode;
import extension.iapcore.android.IAPResult;
#elseif (ios && extension_iapcore)
import extension.iapcore.ios.IAPIOS;
import extension.iapcore.ios.IAPPurchase;
import extension.iapcore.ios.IAPPurchaseState;
#end

enum RestoreResult
{
	RESTORED(count:Int);
	NOTHING;
	FAILED(reason:String);
	UNSUPPORTED;
}

class PurchaseUtil
{
	public static var restoreTimeout:Float = 15;

	public static var iosSettleTime:Float = 2.5;

	public static var restoring(default, null):Bool = false;

	public static var available(get, never):Bool;

	static var initialized:Bool = false;

	static var callback:Null<RestoreResult->Void> = null;

	static var restored:Array<String> = [];

	static var timeoutTimer:Null<haxe.Timer> = null;

	static var settleTimer:Null<haxe.Timer> = null;

	public static function init():Void
	{
		if (initialized) return;

		#if (android && extension_iapcore)
		initialized = true;

		IAPAndroid.onBillingSetupFinished.add((result:IAPResult) -> {
			if (!restoring) return;
			if (result.getResponseCode() == IAPResponseCode.OK) IAPAndroid.queryPurchases();
			else finish(FAILED(result.getDebugMessage()));
		});

		IAPAndroid.onBillingServiceDisconnected.add(() -> {
			if (restoring) finish(FAILED('Store connection lost'));
		});

		IAPAndroid.onQueryPurchasesResponse.add((result:IAPResult, purchases:Array<IAPPurchase>) -> {
			if (!restoring) return;
			if (result.getResponseCode() != IAPResponseCode.OK)
			{
				finish(FAILED(result.getDebugMessage()));
				return;
			}

			for (purchase in purchases)
			{
				if (purchase.getPurchaseState() != IAPPurchaseState.PURCHASED) continue;
				if (!purchase.isAcknowledged()) IAPAndroid.acknowledgePurchase(purchase.getPurchaseToken());
				for (product in purchase.getProducts())
					remember(product);
			}

			finish(restored.length > 0 ? RESTORED(restored.length) : NOTHING);
		});

		IAPAndroid.init();
		#elseif (ios && extension_iapcore)
		initialized = true;

		IAPIOS.onPurchasesUpdated.add((purchases:Array<IAPPurchase>) -> {
			for (purchase in purchases)
			{
				final state = purchase.getTransactionState();
				if (state == IAPPurchaseState.RESTORED || state == IAPPurchaseState.PURCHASED)
				{
					remember(purchase.getPaymentProductIdentifier());
					IAPIOS.finishPurchase(purchase);
				}
				else if (state == IAPPurchaseState.FAILED)
				{
					IAPIOS.finishPurchase(purchase);
				}
			}

			if (restoring) scheduleSettle();
		});

		IAPIOS.init();
		#end
	}

	public static function restore(onComplete:RestoreResult->Void):Void
	{
		if (restoring)
		{
			callback = onComplete;
			return;
		}

		if (!available)
		{
			onComplete(UNSUPPORTED);
			return;
		}

		init();

		restoring = true;
		callback = onComplete;
		restored = [];

		timeoutTimer?.stop();
		timeoutTimer = haxe.Timer.delay(() -> finish(restored.length > 0 ? RESTORED(restored.length) : FAILED('The store did not respond')), Std.int(restoreTimeout * 1000));

		try
		{
			#if (android && extension_iapcore)
			if (IAPAndroid.getConnectionState() == IAPConnectionState.CONNECTED) IAPAndroid.queryPurchases();
			else IAPAndroid.startConnection();
			#elseif (ios && extension_iapcore)
			if (!IAPIOS.canMakePurchases())
			{
				finish(FAILED('Purchases are disabled on this device'));
				return;
			}
			IAPIOS.restorePurchases();
			scheduleSettle(Std.int(restoreTimeout * 600));
			#end
		}
		catch (e:Dynamic)
		{
			finish(FAILED(Std.string(e)));
		}
	}

	public static function owns(product:String):Bool
	{
		return ClientPrefs.purchases != null && ClientPrefs.purchases.contains(product);
	}

	static function remember(product:String):Void
	{
		if (product == null || product.length == 0) return;
		if (!restored.contains(product)) restored.push(product);

		ClientPrefs.purchases ??= [];
		if (!ClientPrefs.purchases.contains(product)) ClientPrefs.purchases.push(product);

		if (product == AdUtil.REMOVE_ADS_PRODUCT) AdUtil.purchasesChanged();
	}

	static function scheduleSettle(?delay:Int):Void
	{
		settleTimer?.stop();
		settleTimer = haxe.Timer.delay(() -> finish(restored.length > 0 ? RESTORED(restored.length) : NOTHING), delay ?? Std.int(iosSettleTime * 1000));
	}

	static function finish(result:RestoreResult):Void
	{
		if (!restoring) return;

		restoring = false;
		timeoutTimer?.stop();
		timeoutTimer = null;
		settleTimer?.stop();
		settleTimer = null;

		ClientPrefs.flush();

		final done = callback;
		callback = null;
		if (done != null) done(result);
	}

	static function get_available():Bool
	{
		#if ((android || ios) && extension_iapcore)
		return true;
		#else
		return false;
		#end
	}
}
