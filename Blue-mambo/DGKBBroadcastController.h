//
//  DGKBBroadcastController.h
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 DGKB. All rights reserved.
//

/**
 @interface DGKBBroadcastController
 @addtogroup Controllers
 @{
 */
/**
 @brief Bluetooth Peripheral
 
 Broadcasts as a Bluetooth peripheral
 */
@interface DGKBBroadcastController : UIViewController <CBPeripheralManagerDelegate>

/// @brief Label that displays the Bluetooth state
@property (nonatomic, strong) IBOutlet UILabel *hostBluetoothStatus;

/// @brief Label that displays peripheral manager activity
@property (weak, nonatomic) IBOutlet UILabel *peripheralManagerStatus;

/// @brief Area for displaying log report
@property (weak, nonatomic) IBOutlet UITextView *reportLog;

/// @brief Disconnects
@property (nonatomic, strong) IBOutlet UIButton *disconnectButton;

/**
	@brief The disconnect button was pressed
	@param sender Sender of the action
 */
- (IBAction)didPressDisconnectButton:(id)sender;

@end

/** @} */