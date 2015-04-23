//
//  DGKBListenController.h
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 DGKB. All rights reserved.
//

/**
 @interface DGKBListenController
 @addtogroup Controllers
 @{
 */
/**
 @brief Bluetooth Listener
 
 Listens for Bluetooth peripherals
 */
@interface DGKBListenController : UIViewController <CBCentralManagerDelegate>

/// @brief Initiates scanning
@property (weak, nonatomic) IBOutlet UIButton *scanButton;

/// @brief Animates when central manager scanning, connecting, etc.
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *centralManagerActivityIndicator;

/// @brief Label that displays the Bluetooth state
@property (weak, nonatomic) IBOutlet UILabel *hostBluetoothStatus;

/// @brief Label that displays central manager activity
@property (weak, nonatomic) IBOutlet UILabel *centralManagerStatus;

/// @brief Area for displaying log report
@property (weak, nonatomic) IBOutlet UITextView *reportLog;

/// @brief Disconnects
@property (nonatomic, strong) IBOutlet UIButton *disconnectButton;

/**
 @brief The scan button was pressed
 @param sender Sender of the action
 */
- (IBAction)didPressScanButton:(id)sender;
/**
 @brief The disconnect button was pressed
 @param sender Sender of the action
 */
- (IBAction)didPressDisconnectButton:(id)sender;

@end

/** @} */
