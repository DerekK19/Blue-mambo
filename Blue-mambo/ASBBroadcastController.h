//
//  ASBBroadcastController.h
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 ASB. All rights reserved.
//

@interface ASBBroadcastController : UIViewController <CBPeripheralManagerDelegate>

@property (nonatomic, strong) IBOutlet UILabel *hostBluetoothStatus;

// label which displays peripheral manager activity
@property (weak, nonatomic) IBOutlet UILabel *peripheralManagerStatus;

@end
