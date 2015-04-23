//
//  DGKBLogging.h
//  FastMobile
//
//  Created by Derek Knight on 9/03/11.
//  Copyright 2011 DGKB. All rights reserved.
//

/**
 @defgroup Logging Diagnostic Logging
 @addtogroup Logging
 Diagnostic logging (from Objective C code)
 
 There is a similar mechanism for logging diagnostics from JavaScript (DiagnosticsPlugin)
 
 To report diagnostics from Objective C code, in your .m file:\n
 First #define LOW_LEVEL_DEBUG as TRUE\n
 Then import Logging.h

 Subsequently use DEBUGLog or ERRORLog where you might use NSLog
 
 DEBUGLog will only log output if LOW_LEVEL_DEBUG is TRUE, ERRORLog will always log output
 
 DEBUGLog will also log output if the #define SHOW_ALL_DEBUG is set to TRUE in Logging.h

 Example
 @code
 
 #define LOW_LEVEL_DEBUG FALSE
 
 #import "Logging.h"
 
 - void)myFunction
 {
    DEBUGLog(@""); // This records the function name, which is handy
    DEBUGLog(@"Display a message, with argument %d", 1);
    ERRORLog(@"An error occurred: %@, [error description]);
 }
 
 @endcode

 @{
 */

/**
#import "LoggerClient.h"
#import "LoggerCommon.h"
*/

// IMPORTANT: These values should not be checked in as YES - SHOW_ALL_DEBUG, LOW_LEVEL_DEBUG, SHOW_ALL_DEBUG, LOW_LEVEL_DEBUG
// Change this locally for debugging only - logging slows UI down severely
#ifdef DEBUG
/**
 @def LOW_LEVEL_DEBUG
 @brief Set this to TRUE to show low level debug messages
 */
#define SHOW_ALL_DEBUG TRUE
#define LOW_LEVEL_DEBUG FALSE
#else
#define SHOW_ALL_DEBUG FALSE
#define LOW_LEVEL_DEBUG FALSE
#endif



/**
 @note (ex http://www.cimgf.com/2010/05/02/my-current-prefix-pch-file/ ):\n
 As for the do {} while (0) instead of nothing. This is because there are a few rare code situations
 where replacing DLog(@”"); with ; can cause issues. Replacing it with do {} while(0); is safer in
 those rare cases and will get optimized out by the compiler anyway.
 */

#ifdef NSLOGGER_WAS_HERE

#if (LOW_LEVEL_DEBUG == TRUE || SHOW_ALL_DEBUG == TRUE)
#define LIBRARYLog(...) LogMessageF(__FILE__, __LINE__, __PRETTY_FUNCTION__, @"Library", 1, @"%@", [NSString stringWithFormat:__VA_ARGS__])
#define DETAIL_LibraryLog(...) LogMessageF(__FILE__, __LINE__, __PRETTY_FUNCTION__, @"Library", 2, @"%@", [NSString stringWithFormat:__VA_ARGS__])
#else
/**
 @def LIBRARYLog
 @param ... Content to log
 @brief Logs output from library functions
 */
#define LIBRARYLog(...) do {} while(0);
#define DETAIL_LibraryLog(...) do {} while(0);
#endif

#if (LOW_LEVEL_DEBUG == TRUE || SHOW_ALL_DEBUG == TRUE)
#define DEBUGLog(...) LogMessageF(__FILE__, __LINE__, __PRETTY_FUNCTION__, @"Application", 1, @"%@", [NSString stringWithFormat:__VA_ARGS__])
#define DETAIL_DebugLog(...) LogMessageF(__FILE__, __LINE__, __PRETTY_FUNCTION__, @"Application", 2, @"%@", [NSString stringWithFormat:__VA_ARGS__])
#else
#define DEBUGLog(...) do {} while(0);
#define DETAIL_DebugLog(...) do {} while(0);
#endif

#define ERRORLog(...) LogMessageF(__FILE__, __LINE__, __PRETTY_FUNCTION__, @"Error", 0, @"%@", [NSString stringWithFormat:__VA_ARGS__])

#else

#if (LOW_LEVEL_DEBUG == TRUE || SHOW_ALL_DEBUG == TRUE)
#define LIBRARYLog(...) NSLog(@"%s %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])
#define DETAIL_LibraryLog(...) NSLog(@"%s %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])
#define DEBUGLog(...) NSLog(@"%s %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])
#define DETAIL_DebugLog(...) NSLog(@"%s %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])
#else
#define LIBRARYLog(...) do {} while(0);
#define DETAIL_LibraryLog(...) do {} while(0);
#define DEBUGLog(...) do {} while(0);
#define DETAIL_DebugLog(...) do {} while(0);
#endif

#define ERRORLog(...) NSLog(@"%s %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])

#endif

/** @} */
