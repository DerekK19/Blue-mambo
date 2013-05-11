//
//  DGKBBluetoothScanner.h
//  Blue-mambo
//
//  Created by Derek Knight on 7/04/13.
//  Copyright (c) 2013 DGKB. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^DGKBBluetoothScanSuccessBlockType)(CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI);
typedef void(^DGKBBluetoothScanTimeoutBlockType)();
typedef void(^DGKBBluetoothConnectSuccessBlockType)();
typedef void(^DGKBBluetoothConnectTimeoutBlockType)();
typedef void(^DGKBBluetoothDisconnectSuccessBlockType)();
typedef void(^DGKBBluetoothDiscoverSuccessBlockType)(CBPeripheral *peripheral);
typedef void(^DGKBBluetoothCharacteristicsSuccessBlockType)(CBService *service);
typedef void(^DGKBBluetoothCharacteristicChangeBlockType)(CBCharacteristic *characteristic);

@interface DGKBBluetoothScanner : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (readonly) CBCentralManagerState state;

- (void)startScanningWithTimeout:(NSTimeInterval)seconds
               onFoundPeripheral:(DGKBBluetoothScanSuccessBlockType)block
                      onTimedOut:(DGKBBluetoothScanTimeoutBlockType)timeout;
- (void)stopScanning;

- (void)connectPeripheral:(CBPeripheral *)peripheral
                  timeout:(NSTimeInterval)seconds
                onConnect:(DGKBBluetoothConnectSuccessBlockType)peripheral
             onDisconnect:(DGKBBluetoothDisconnectSuccessBlockType)peripheral
               onTimedOut:(DGKBBluetoothConnectTimeoutBlockType)timeout;
- (void)disconnect:(CBPeripheral *)peripheral;

- (void)discoverServices:(CBPeripheral *)peripheral
               withUUIDs:(NSArray *)serviceUUIDs
               onFoundServices:(DGKBBluetoothDiscoverSuccessBlockType)block;

- (void)getCharacteristics:(CBService *)service
                 withUUIDS:(NSArray *)characteristicUUIDs
                andTimeout:(NSTimeInterval)seconds
    onFoundCharacteristics:(DGKBBluetoothCharacteristicsSuccessBlockType)foundBlock
   onChangedCharacteristic:(DGKBBluetoothCharacteristicChangeBlockType)changeBlock;

@end
