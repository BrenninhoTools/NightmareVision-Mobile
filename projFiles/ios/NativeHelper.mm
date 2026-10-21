#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

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

extern "C" void nmv_native_vibrate(int milliseconds)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIImpactFeedbackStyle style = milliseconds >= 40 ? UIImpactFeedbackStyleHeavy : (milliseconds >= 20 ? UIImpactFeedbackStyleMedium : UIImpactFeedbackStyleLight);
		UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
		[generator prepare];
		[generator impactOccurred];
	});
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
