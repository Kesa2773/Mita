#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>
#import "HUD/RJTHud.h"

#define wallpaperPath @"/var/mobile/Library/SpringBoard/LockBackground.cpbitmap"

#ifdef __cplusplus // this fixes the linking for the C++ compiler
extern "C" {
#endif

CFArrayRef CPBitmapCreateImagesFromData(CFDataRef cpbitmap, void *, int, void *); // taken from the private AppSupport framework

#ifdef __cplusplus
}
#endif

static UITapGestureRecognizer *tapGestureRecognizer;

static void (*orig_viewDidLoad)(UIViewController *, SEL);

static void override_viewDidLoad(UIViewController *self, SEL _cmd) {
    if (orig_viewDidLoad) {
        orig_viewDidLoad(self, _cmd);
    }

    if (tapGestureRecognizer) {
        [self.view removeGestureRecognizer:tapGestureRecognizer]; // be safe lol
    }

    tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tapGestureRecognizer.numberOfTapsRequired = 3;
    [self.view addGestureRecognizer:tapGestureRecognizer];
}

static void handleTap(UITapGestureRecognizer *gesture) {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        CFStringRef langCode = (CFStringRef)CFLocaleGetValue(CFLocaleCopyCurrent(), kCFLocaleLanguageCode);

        __auto_type alertController = [UIAlertController alertControllerWithTitle:@"Mita"
                                                                                 message:(CFStringCompare(langCode, CFSTR("ru"), 0) == kCFCompareEqualTo ? @"Вы хотите сохранить текущие обои?" : @"Do you want to save current wallpaper?")
                                                                          preferredStyle:UIAlertControllerStyleActionSheet];

        __auto_type confirmAction = [UIAlertAction actionWithTitle:(CFStringCompare(langCode, CFSTR("ru"), 0) == kCFCompareEqualTo ? @"Да" : @"Yes")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                CFArrayRef imageArray = CPBitmapCreateImagesFromData((__bridge CFDataRef)[NSData dataWithContentsOfFile:wallpaperPath], NULL, 1, NULL);

                dispatch_async(dispatch_get_main_queue(), ^{
                    RJTHud *hud = [RJTHud show];
                    [hud setText:@"Mita"];
                    [hud setDetailedText:imageArray ? // localizedDescription does not produce anything, so we manually notify the user if something went wrong
                    (CFStringCompare(langCode, CFSTR("ru"), 0) == kCFCompareEqualTo ? @"Обои успешно сохранены" : @"Wallpaper saved successfully") :
                    (CFStringCompare(langCode, CFSTR("ru"), 0) == kCFCompareEqualTo ? @"Не удалось сохранить изображение" : @"Failed to save image")];
                    [hud hideAfterDelay:1.5f];
                    [hud setStyle:RJTHudStyleTextOnly];

                    if (imageArray) {
                        __auto_type image = [UIImage imageWithCGImage:(CGImageRef)CFArrayGetValueAtIndex(imageArray, 0)];
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);

                        CFRelease(imageArray);
                    }
                });

                CFRelease(langCode);
            });
        }];

        __auto_type cancelAction = [UIAlertAction actionWithTitle:(CFStringCompare(langCode, CFSTR("ru"), 0) == kCFCompareEqualTo ? @"Не сейчас" : @"Not now")
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];

        [alertController addAction:confirmAction];
        [alertController addAction:cancelAction];

        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
       // if ( __auto_type keyWindow = UIApplication.sharedApplication.keyWindow) { // extra loop huh? I just hate passing variables, so don't give a fuck
        __auto_type keyWindow = UIApplication.sharedApplication.keyWindow; // C doesn't support initializing variables inside conditions and I'm too lazy to rename the file extension so that the line above compiles, we lost :(((
            if (keyWindow && keyWindow.rootViewController) {
            //if (keyWindow.rootViewController) {
                if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) { // iPad need more care, let's give it
                    alertController.popoverPresentationController.sourceView = keyWindow.rootViewController.view;
                    alertController.popoverPresentationController.sourceRect = CGRectMake(
                        CGRectGetMidX(keyWindow.rootViewController.view.bounds),
                        CGRectGetMidY(keyWindow.rootViewController.view.bounds),
                        1, 1
                    );
                    alertController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [keyWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
                });
            }
        }
        #pragma clang diagnostic pop
  //  }
}

__attribute__((constructor))
static void Mita_load() {
    Class cls = objc_lookUpClass("CSCoverSheetViewController");
    if (cls) {
        Method originalMethod = class_getInstanceMethod(cls, @selector(viewDidLoad));

        if (originalMethod) {
            orig_viewDidLoad = (void (*)(UIViewController *, SEL))method_getImplementation(originalMethod);
            method_setImplementation(originalMethod, (IMP)override_viewDidLoad);
        }

        IMP tapIMP = imp_implementationWithBlock(^(UIViewController *self, UITapGestureRecognizer *gesture) {
            handleTap(gesture);
        });
        class_addMethod(cls, @selector(handleTap:), tapIMP, "v@:@");
    }
}
