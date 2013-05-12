//
//  DGKBAppDelegate.h
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 DGKB. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 @mainpage
 @author Derek Knight
 @date Started April 2013
 
 Blue Mambo App
 
 A Bluetooth client/server running on an iDevice (iPad)
 */
/**
 @defgroup Classes Miscellaneous classes
 */
/**
 @interface DGKBAppDelegate
 @addtogroup Classes
 @{
 */
/**
 @brief App Delegate
 
 This is a standard iOS Application, so this, the App Delegate is effectively the main entry point
 */
@interface DGKBAppDelegate : UIResponder <UIApplicationDelegate>

/// The main window
@property (strong, nonatomic) UIWindow *window;

@end

/** @} */
