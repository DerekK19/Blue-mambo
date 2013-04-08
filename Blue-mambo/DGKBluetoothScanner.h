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
typedef void(^DGKBluetoothConnectSuccessBlockType)();
typedef void(^DGKBluetoothConnectTimeoutBlockType)();
typedef void(^DGKBluetoothDisconnectSuccessBlockType)();

@interface DGKBluetoothScanner : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (readonly) CBCentralManagerState state;

- (void)startScanningWithTimeout:(NSTimeInterval)seconds
               onFoundPeripheral:(DGKBluetoothScanSuccessBlockType)block
                      onTimedOut:(DGKBluetoothScanTimeoutBlockType)timeout;
- (void)stopScanning;

- (void)connectPeripheral:(CBPeripheral *)peripheral
                  timeout:(NSTimeInterval)seconds
                onConnect:(DGKBluetoothConnectSuccessBlockType)peripheral
             onDisconnect:(DGKBluetoothDisconnectSuccessBlockType)peripheral
               onTimedOut:(DGKBluetoothConnectTimeoutBlockType)timeout;
- (void)disconnect:(CBPeripheral *)peripheral;

@end
