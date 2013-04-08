//
//  ASBListenController.h
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 ASB. All rights reserved.
//

@interface ASBListenController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate>

// initiate scanning
@property (weak, nonatomic) IBOutlet UIButton *scanButton;

// animate when central manager scanning, connecting, etc.
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *centralManagerActivityIndicator;

// displays CBCentralManager status (role of iphone/ipad)
@property (weak, nonatomic) IBOutlet UILabel *hostBluetoothStatus;

// label which displays central manager activity
@property (weak, nonatomic) IBOutlet UILabel *centralManagerStatus;

// Area for displaying log report
@property (weak, nonatomic) IBOutlet UITextView *reportLog;

// Disconnect
@property (nonatomic, strong) IBOutlet UIButton *disconnectButton;

- (IBAction)didPressScanButton:(id)sender;
- (IBAction)didPressDisconnectButton:(id)sender;

@end
