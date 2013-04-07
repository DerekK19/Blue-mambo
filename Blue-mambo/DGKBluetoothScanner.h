//
//  DGKBluetoothScanner.h
//  Blue-mambo
//
//  Created by Derek Knight on 7/04/13.
//  Copyright (c) 2013 ASB. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^DGKBluetoothScanSuccessBlockType)(CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI);
typedef void(^DGKBluetoothScanTimeoutBlockType)();

@interface DGKBluetoothScanner : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

- (void)startScanningWithTimeout:(NSTimeInterval)seconds
               onFoundPeripheral:(DGKBluetoothScanSuccessBlockType)block
                      onTimedOut:(DGKBluetoothScanTimeoutBlockType)timeout;
- (void)stopScanning;

@end
