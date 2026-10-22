#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <GameController/GameController.h>

#include <string>

static NSString *nmvPickState = @"idle";
static NSString *nmvPickedFiles = @"";
static std::string nmvStateBuffer;
static std::string nmvFilesBuffer;

static UIViewController *nmvTopController()
{
	UIWindow *window = nil;

	for (UIScene *scene in [UIApplication sharedApplication].connectedScenes)
	{
		if (![scene isKindOfClass:[UIWindowScene class]]) continue;

		for (UIWindow *candidate in ((UIWindowScene *)scene).windows)
		{
			if (candidate.isKeyWindow)
			{
				window = candidate;
				break;
			}
		}

		if (window != nil) break;
	}

	if (window == nil) window = [UIApplication sharedApplication].windows.firstObject;

	UIViewController *controller = window.rootViewController;
	while (controller.presentedViewController != nil)
		controller = controller.presentedViewController;

	return controller;
}

static NSString *nmvImportFolder()
{
	NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
	NSString *folder = [documents stringByAppendingPathComponent:@"imports"];
	[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
	return folder;
}

@interface NMVDocumentPickerDelegate : NSObject <UIDocumentPickerDelegate>
@end

@implementation NMVDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
	NSMutableArray<NSString *> *paths = [NSMutableArray array];
	NSString *folder = nmvImportFolder();
	NSFileManager *manager = [NSFileManager defaultManager];

	for (NSURL *url in urls)
	{
		BOOL scoped = [url startAccessingSecurityScopedResource];
		NSString *target = [folder stringByAppendingPathComponent:url.lastPathComponent];

		[manager removeItemAtPath:target error:nil];

		if ([manager copyItemAtURL:url toURL:[NSURL fileURLWithPath:target] error:nil])
			[paths addObject:target];

		if (scoped) [url stopAccessingSecurityScopedResource];
	}

	nmvPickedFiles = [paths componentsJoinedByString:@"\n"];
	nmvPickState = paths.count > 0 ? @"done" : @"cancel";
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
	nmvPickState = @"cancel";
}

@end

static NMVDocumentPickerDelegate *nmvPickerDelegate = nil;

static NSString *nmvSaveState = @"idle";
static NSString *nmvSavedName = @"";
static NSString *nmvSaveSource = @"";
static std::string nmvSaveStateBuffer;
static std::string nmvSavedNameBuffer;

@interface NMVSavePickerDelegate : NSObject <UIDocumentPickerDelegate>
@end

@implementation NMVSavePickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
	NSURL *url = urls.firstObject;
	nmvSavedName = url != nil ? url.lastPathComponent : @"";
	nmvSaveState = url != nil ? @"done" : @"cancel";
	[[NSFileManager defaultManager] removeItemAtPath:nmvSaveSource error:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
	nmvSaveState = @"cancel";
	[[NSFileManager defaultManager] removeItemAtPath:nmvSaveSource error:nil];
}

@end

static NMVSavePickerDelegate *nmvSaveDelegate = nil;

extern "C" void nmv_native_save_file(const char *sourcePath, const char *fileName)
{
	if (sourcePath == NULL)
	{
		nmvSaveState = @"cancel";
		return;
	}

	nmvSaveState = @"pending";
	nmvSavedName = @"";

	NSString *source = [NSString stringWithUTF8String:sourcePath];
	NSString *name = fileName != NULL ? [NSString stringWithUTF8String:fileName] : source.lastPathComponent;

	dispatch_async(dispatch_get_main_queue(), ^{
		NSFileManager *manager = [NSFileManager defaultManager];
		NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
		[manager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];

		NSString *staged = [folder stringByAppendingPathComponent:(name.length > 0 ? name : source.lastPathComponent)];
		[manager removeItemAtPath:staged error:nil];

		if (![manager moveItemAtPath:source toPath:staged error:nil] && ![manager copyItemAtPath:source toPath:staged error:nil])
		{
			nmvSaveState = @"error";
			return;
		}

		nmvSaveSource = staged;

		UIViewController *controller = nmvTopController();
		if (controller == nil)
		{
			nmvSaveState = @"error";
			return;
		}

		UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[[NSURL fileURLWithPath:staged]] asCopy:YES];

		if (nmvSaveDelegate == nil) nmvSaveDelegate = [[NMVSavePickerDelegate alloc] init];
		picker.delegate = nmvSaveDelegate;

		[controller presentViewController:picker animated:YES completion:nil];
	});
}

extern "C" const char *nmv_native_save_state()
{
	nmvSaveStateBuffer = [nmvSaveState UTF8String];
	return nmvSaveStateBuffer.c_str();
}

extern "C" const char *nmv_native_saved_name()
{
	nmvSavedNameBuffer = [nmvSavedName UTF8String];
	return nmvSavedNameBuffer.c_str();
}

extern "C" void nmv_native_reset_save()
{
	nmvSaveState = @"idle";
	nmvSavedName = @"";
}

static UIImpactFeedbackGenerator *nmvImpactGenerators[3];

static UIImpactFeedbackGenerator *nmvImpactGenerator(int milliseconds)
{
	int index = milliseconds >= 40 ? 2 : (milliseconds >= 20 ? 1 : 0);
	if (nmvImpactGenerators[index] == nil)
	{
		UIImpactFeedbackStyle style = index == 2 ? UIImpactFeedbackStyleHeavy : (index == 1 ? UIImpactFeedbackStyleMedium : UIImpactFeedbackStyleLight);
		nmvImpactGenerators[index] = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
	}
	return nmvImpactGenerators[index];
}

extern "C" void nmv_native_vibrate_intensity(int milliseconds, double intensity)
{
	if (milliseconds <= 0 || intensity <= 0) return;

	CGFloat value = (CGFloat)(intensity > 1 ? 1 : intensity);

	dispatch_async(dispatch_get_main_queue(), ^{
		UIImpactFeedbackGenerator *generator = nmvImpactGenerator(milliseconds);
		[generator impactOccurredWithIntensity:value];
		[generator prepare];
	});
}

extern "C" int nmv_native_external_input()
{
	int result = 0;

	@autoreleasepool
	{
		if (@available(iOS 14.0, *))
		{
			if (GCKeyboard.coalescedKeyboard != nil) result |= 1;
		}

		for (GCController *controller in [GCController controllers])
		{
			if (controller.extendedGamepad != nil || controller.microGamepad != nil)
			{
				result |= 2;
				break;
			}
		}
	}

	return result;
}

extern "C" void nmv_native_exclude_from_backup(const char *path)
{
	if (path == NULL) return;

	@autoreleasepool
	{
		NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
		if (url == nil || ![[NSFileManager defaultManager] fileExistsAtPath:url.path]) return;
		[url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
	}
}

extern "C" long long nmv_native_free_space()
{
	@autoreleasepool
	{
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
		NSNumber *free = attributes[NSFileSystemFreeSize];
		return free != nil ? [free longLongValue] : -1;
	}
}

extern "C" void nmv_native_vibrate(int milliseconds)
{
	nmv_native_vibrate_intensity(milliseconds, 1.0);
}

extern "C" void nmv_native_toast(const char *message, int longDuration)
{
	if (message == NULL) return;

	NSString *text = [NSString stringWithUTF8String:message];
	double seconds = longDuration ? 3.0 : 1.6;

	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *controller = nmvTopController();
		if (controller == nil) return;

		UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:text preferredStyle:UIAlertControllerStyleAlert];
		[controller presentViewController:alert animated:YES completion:nil];

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[alert dismissViewControllerAnimated:YES completion:nil];
		});
	});
}

extern "C" void nmv_native_pick_files(const char *extensions, int multiple)
{
	nmvPickState = @"pending";
	nmvPickedFiles = @"";

	NSString *list = extensions != NULL ? [NSString stringWithUTF8String:extensions] : @"";

	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *controller = nmvTopController();
		if (controller == nil)
		{
			nmvPickState = @"cancel";
			return;
		}

		NSMutableArray<UTType *> *types = [NSMutableArray array];

		for (NSString *extension in [list componentsSeparatedByString:@","])
		{
			NSString *trimmed = [extension stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if (trimmed.length == 0) continue;

			UTType *type = [UTType typeWithFilenameExtension:trimmed];
			if (type != nil) [types addObject:type];
		}

		if (types.count == 0) [types addObject:UTTypeItem];

		UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
		picker.allowsMultipleSelection = multiple != 0;

		if (nmvPickerDelegate == nil) nmvPickerDelegate = [[NMVDocumentPickerDelegate alloc] init];
		picker.delegate = nmvPickerDelegate;

		[controller presentViewController:picker animated:YES completion:nil];
	});
}

extern "C" const char *nmv_native_pick_state()
{
	nmvStateBuffer = [nmvPickState UTF8String];
	return nmvStateBuffer.c_str();
}

extern "C" const char *nmv_native_picked_files()
{
	nmvFilesBuffer = [nmvPickedFiles UTF8String];
	return nmvFilesBuffer.c_str();
}

extern "C" void nmv_native_reset_pick()
{
	nmvPickState = @"idle";
	nmvPickedFiles = @"";
}

extern "C" void nmv_native_share_file(const char *path)
{
	if (path == NULL) return;

	NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];

	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *controller = nmvTopController();
		if (controller == nil) return;

		UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
		share.popoverPresentationController.sourceView = controller.view;
		share.popoverPresentationController.sourceRect = CGRectMake(controller.view.bounds.size.width / 2, controller.view.bounds.size.height / 2, 1, 1);
		[controller presentViewController:share animated:YES completion:nil];
	});
}
