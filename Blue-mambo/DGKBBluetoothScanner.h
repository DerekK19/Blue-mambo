//
//  DGKBBluetoothScanner.h
//  Blue-mambo
//
//  Created by Derek Knight on 7/04/13.
//  Copyright (c) 2013 DGKB. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 @addtogroup Types
 @{
 */

/**
 @typedef DGKBBluetoothScanSuccessBlockType
 @brief Bluetooth scan success code block
 
 Scanning completed successfully and a peripheral was found
 
 @param peripheral The peripheral
 @param advertisementData The advertisement data for the peripheral
 @param RSSI The RSSI - shows how strong the signal from the peripheral is
 */
typedef void(^DGKBBluetoothScanSuccessBlockType)(CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI);
/**
 @typedef DGKBBluetoothScanTimeoutBlockType
 @brief Bluetooth scanning timeout code block
 
 Scanning completed, but no peripheral was found within the timout period
 */
typedef void(^DGKBBluetoothScanTimeoutBlockType)();
/**
 @typedef DGKBBluetoothConnectSuccessBlockType
 @brief Bluetooth connect success code block
 
 The peripheral was successfully connected
 */
typedef void(^DGKBBluetoothConnectSuccessBlockType)();
/**
 @typedef DGKBBluetoothConnectTimeoutBlockType
 @brief Bluetooth connection timeout code block
 
 Failed to connect the peripheral within the timout period
 */
typedef void(^DGKBBluetoothConnectTimeoutBlockType)();
/**
 @typedef DGKBBluetoothDisconnectSuccessBlockType
 @brief Bluetooth disconnect success code block
 
 The peripheral was successfully disconnected
 */
typedef void(^DGKBBluetoothDisconnectSuccessBlockType)();
/**
 @typedef DGKBBluetoothDiscoverSuccessBlockType
 @brief Bluetooth service discovery success code block
 
 The peripheral's services were successfully discovered
 
 @param peripheral The peripheral
 */
typedef void(^DGKBBluetoothDiscoverSuccessBlockType)(CBPeripheral *peripheral);
/**
 @typedef DGKBBluetoothCharacteristicsSuccessBlockType
 @brief Bluetooth characteristic discovery success code block
 
 The service's characteristics were successfully discovered
 
 @param service The service
 */
typedef void(^DGKBBluetoothCharacteristicsSuccessBlockType)(CBService *service);
/**
 @typedef DGKBBluetoothCharacteristicChangeBlockType
 @brief Bluetooth characteristic change code block
 
 The characteristic changed
 
 @param characteristic The characteristic
 */
typedef void(^DGKBBluetoothCharacteristicChangeBlockType)(CBCharacteristic *characteristic);

/** @} */

/**
 @interface DGKBBluetoothScanner
 @addtogroup Classes
 @{
 */
/**
 @brief Bluetooth Scanner
 
 Functionality to scan for Bluetooth services, connect peripherals and get peripheral characteristics
 @see DGKBBluetoothScanner()
 */
@interface DGKBBluetoothScanner : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

/// The Core Bluetooth manager's current state
@property (readonly) CBCentralManagerState state;

/**
 @brief Start scanning for peripherals
 
 @param seconds The number of seconds before timeout
 @param foundBlock The block to execute if a peripheral is found
 @param timeoutBlock The block to execute if no peripherals are found
 */
- (void)startScanningWithTimeout:(NSTimeInterval)seconds
               onFoundPeripheral:(DGKBBluetoothScanSuccessBlockType)foundBlock
                      onTimedOut:(DGKBBluetoothScanTimeoutBlockType)timeoutBlock;

/**
 @brief Stop scanning for peripherals 
 */
- (void)stopScanning;

/**
 @brief Connect a peripheral
 
 @param peripheral The peripheral
 @param seconds The number of seconds before timeout
 @param connectBlock Code block executed when the peripheral connects
 @param disconnectBlock Code block executed when the peripheral disconnects
 @param timeoutBlock Code blockj to execute if the connection cannot be made within the given period
 */
- (void)connectPeripheral:(CBPeripheral *)peripheral
                  timeout:(NSTimeInterval)seconds
                onConnect:(DGKBBluetoothConnectSuccessBlockType)connectBlock
             onDisconnect:(DGKBBluetoothDisconnectSuccessBlockType)disconnectBlock
               onTimedOut:(DGKBBluetoothConnectTimeoutBlockType)timeoutBlock;

/**
 @brief Disconnect a peripheral
 
 @param peripheral The peripheral
 */
- (void)disconnect:(CBPeripheral *)peripheral;

/**
 @brief Discover a peripheral's services

 @param peripheral The peripheral
 @param serviceUUIDs The list of services to search for
 @param block Code block to execute when the servcies have been found
 */
- (void)discoverServices:(CBPeripheral *)peripheral
               withUUIDs:(NSArray *)serviceUUIDs
         onFoundServices:(DGKBBluetoothDiscoverSuccessBlockType)block;

/**
 @brief Get a service's characteristics
 
 @param service The service
 @param characteristicUUIDs The list of characteristics to search for
 @param seconds The number of seconds before timeout
 @param foundBlock Code block to execute when the characteristics have been found
 @param changeBlock Code block to execute when a characteristic changes value
 */
- (void)getCharacteristics:(CBService *)service
                 withUUIDS:(NSArray *)characteristicUUIDs
                andTimeout:(NSTimeInterval)seconds
    onFoundCharacteristics:(DGKBBluetoothCharacteristicsSuccessBlockType)foundBlock
   onChangedCharacteristic:(DGKBBluetoothCharacteristicChangeBlockType)changeBlock;

@end

/** @} */
