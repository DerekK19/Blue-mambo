//
//  DGKBBroadcastController.h
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 DGKB. All rights reserved.
//

@interface DGKBBroadcastController : UIViewController <CBPeripheralManagerDelegate>

@property (nonatomic, strong) IBOutlet UILabel *hostBluetoothStatus;

// label which displays peripheral manager activity
@property (weak, nonatomic) IBOutlet UILabel *peripheralManagerStatus;

// Area for displaying log report
@property (weak, nonatomic) IBOutlet UITextView *reportLog;

// Disconnect
@property (nonatomic, strong) IBOutlet UIButton *disconnectButton;

- (IBAction)didPressDisconnectButton:(id)sender;

@end
