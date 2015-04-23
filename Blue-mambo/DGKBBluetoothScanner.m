//
//  DGKBBluetoothScanner.m
//  Blue-mambo
//
//  Created by Derek Knight on 7/04/13.
//  Copyright (c) 2013 DGKB. All rights reserved.
//

#import "DGKBBluetoothScanner.h"

/**
 @extends DGKBBluetoothScanner
 @addtogroup Classes
 @{
 */
/**
 @brief Bluetooth Scanner extension
 
 Internal functionality for Bluetooth scanner. Private extensions to DGKBBluetoothScanner @see DGKBBluetoothScanner
 */
@interface DGKBBluetoothScanner ()

@property (nonatomic, strong) CBCentralManager *centralManager; ///< The central Bluetooth manager
@property (nonatomic) NSTimeInterval scanTimeout; ///< The scan timeout period
@property (nonatomic, copy) DGKBBluetoothScanSuccessBlockType scanBlock; ///< The code block for scan success
@property (nonatomic, copy) DGKBBluetoothScanTimeoutBlockType scanTimeoutBlock; ///< The code block for scan timeout
@property (nonatomic, assign) BOOL scanWhenReady; ///< Will scanning be deferred until the core Bluetooth is alive?
@property (nonatomic, assign) BOOL scanState; ///< Are we currently scanning for peripherals?
@property (nonatomic) NSTimeInterval connectTimeout; ///< The connect timeout period
@property (nonatomic, copy) DGKBBluetoothConnectSuccessBlockType connectBlock; ///< The code block for successful connection
@property (nonatomic, copy) DGKBBluetoothDisconnectSuccessBlockType disconnectBlock; ///< The code block for successful disconnection
@property (nonatomic, copy) DGKBBluetoothConnectTimeoutBlockType connectTimeoutBlock; ///< The code block for connection timeout
@property (nonatomic, strong) CBPeripheral *currentPeripheral; ///< The current peripheral
@property (nonatomic, copy) DGKBBluetoothDiscoverSuccessBlockType discoverBlock; ///< The code block for successful service discovery
@property (nonatomic, strong) CBService *currentService; ///< The current service
@property (nonatomic, copy) DGKBBluetoothCharacteristicsSuccessBlockType characteristicsBlock; ///< The code block for successful characteristic retrieval
@property (nonatomic, copy) DGKBBluetoothCharacteristicChangeBlockType changeBlock; ///< The code block for characteristic value change
@property (nonatomic) NSTimeInterval requestTimeout; ///< The request timeout period

/**
 @brief Starts scanning
 
 - Start the scanning timeout monitor
 - Scan for peripherals
 */
- (void)startScanning;
/**
 @brief Start scanning timeout monitor

 - Cancel any currently running scanning timeout monitor
 - Set up a timer that will call scanningDidTimeout after the specified period
 */
- (void)startScanningTimeoutMonitor;
/**
 @brief Cancel the scanning timeout monitor
 
 - Remove the timer that was set up to monitor scanning
 */
- (void)cancelScanningTimeoutMonitor;
/**
 @brief Handle scanning timeout
 
 - Stop scanning
 - Execute the scan timeout code block
 */
- (void)scanningDidTimeout;

/**
 @brief Start connection timeout monitor
 
 @param peripheral The peripheral

 - Cancel any currently running connection timeout monitor
 - Set up a timer that will call connectionDidTimeout after the specfiied period
 */
- (void)startConnectionTimeoutMonitor:(CBPeripheral *)peripheral;
/**
 @brief Cancel the connection timeout monitor
 
 - Remove the timer that was set up to monitor connections
 */
- (void)cancelConnectionTimeoutMonitor:(CBPeripheral *)peripheral;
/**
 @brief Handle connection timeout
 
 @param peripheral The peripheral
 
 - Cancel the peripheral connection
 - Execute the connection timeout code block
 */
- (void)connectionDidTimeout:(CBPeripheral *)peripheral;

/**
 @brief Start request timeout monitor
 
 @param characteristic The characteristic

 - Cancel any currently running request timeout monitor
 - Set up a timer that will call requestDidTimeout after the specfiied period
 */
- (void)startRequestTimeoutMonitor:(CBCharacteristic *)characteristic;
/**
 @brief Cancel the request timeout monitor
 
 - Remove the timer that was set up to monitor requests
 */
- (void)cancelRequestTimeoutMonitor:(CBCharacteristic *)characteristic;
/**
 @brief Handle request timeout
 
 @param characteristic The characteristic
 
 - Cancel notifications for the characteristic
 */
- (void)requestDidTimeout:(CBCharacteristic *)characteristic;

/**
 @brief Get a description for a central manager's state
 @param state A central manager state
 @return A descriptive text
 
 Gets a text string that describes the Bluetooth central manager state
 */
- (NSString *)getCBCentralStateName:(CBCentralManagerState) state;

@end

/** @} */

/**
 @implements DGKBBluetoothScanner
 @addtogroup Classes
 @{
 */
@implementation DGKBBluetoothScanner

- (id)init
{
    self = [super init];
    if (self)
    {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

- (CBCentralManagerState)state
{
    return _centralManager.state;
}

/**
 When a peripheral is found, execute the supplied code block.
 If no peripherals are found within the timeout period, execute the timeout code block
 
 - Save the parameters to instance properties.
 - If the central manager is not powered on, defer scanning until it is.
 - Otherwise start scanning
 */
- (void)startScanningWithTimeout:(NSTimeInterval)seconds
               onFoundPeripheral:(DGKBBluetoothScanSuccessBlockType)foundBlock
                      onTimedOut:(DGKBBluetoothScanTimeoutBlockType)timeoutBlock
{
    DEBUGLog(@"Starting scan (%1.1f)...", seconds);
    _scanTimeout = seconds;
    _scanBlock = foundBlock;
    _scanTimeoutBlock = timeoutBlock;
    if (_centralManager.state != CBCentralManagerStatePoweredOn)
    {
        // Defer scanning until manager comes online.
        _scanWhenReady = YES;
        return;
    }
    [self startScanning];
}

- (void)startScanning
{
    _scanState = YES;  // scanning
    
    [self startScanningTimeoutMonitor];
    
    [_centralManager scanForPeripheralsWithServices:nil
                                            options:nil];
}

/**
 The code blocks supplied when scanning started will not be called
 when the scan is stopped through a call to this method
 
 - Cancel the scanning timout monitor.
 - Stop scanning
 */
- (void)stopScanning
{
    DEBUGLog(@"Stopping scan...");
    [self cancelScanningTimeoutMonitor];
    [_centralManager stopScan];
    _scanState = NO;
}

- (void)startScanningTimeoutMonitor
{
    [self cancelScanningTimeoutMonitor];
    [self performSelector:@selector(scanningDidTimeout)
               withObject:nil
               afterDelay:_scanTimeout];
}

- (void)cancelScanningTimeoutMonitor
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(scanningDidTimeout)
                                               object:nil];
}

- (void)scanningDidTimeout
{
    DEBUGLog(@"Timed out...");
    
    //    [self.delegate centralClient:self
    //                  connectDidFail:[[self class] errorWithDescription:@"Unable to find a BTLE device."]];
    [self stopScanning];
    _scanTimeoutBlock();
}

/**
 Attempt to connect to the peripheral within the specified timeout period
 If connection cannot be established in time, eecute tge timeoutBlock code block.
 If connection is successful, execute the connectBlock code block. When the connection
 is broken, execute the disconnectBlock code block
 
 - Save the parameters to instance properties.
 - Connect to the peripheral
 - Start a connection timeout monitor
 */
- (void)connectPeripheral:(CBPeripheral *)peripheral
                  timeout:(NSTimeInterval)seconds
                onConnect:(DGKBBluetoothConnectSuccessBlockType)connectBlock
             onDisconnect:(DGKBBluetoothDisconnectSuccessBlockType)disconnectBlock
               onTimedOut:(DGKBBluetoothConnectTimeoutBlockType)timeoutBlock
{
    DEBUGLog(@"Starting connection...");
    
    _connectTimeout = seconds;
    _connectBlock = connectBlock;
    _disconnectBlock = disconnectBlock;
    _connectTimeoutBlock = timeoutBlock;
    
    [_centralManager connectPeripheral:peripheral
                               options:nil];
    
    /// @note If you don't retain the CBPeripheral during the connection,
    ///       this request will silently fail. The call to startConnectionTimeoutMonitor
    ///       will retain the peripheral for timeout purposes.
    [self startConnectionTimeoutMonitor:peripheral];
}

/**
 Disconnect from the specified peripheral. When the connection has been broken, the code block
 provided when the connection had been made will be executed
 
 - If no peripheral is provided, do nothing
 - Otherwise cancel the peripheral connection
 */
- (void)disconnect:(CBPeripheral *)peripheral
{
    DEBUGLog(@"Disconnecting ...");
    if (!peripheral) return;
    [_centralManager cancelPeripheralConnection:peripheral];
}

- (void)startConnectionTimeoutMonitor:(CBPeripheral *)peripheral
{
    [self cancelConnectionTimeoutMonitor:peripheral];
    [self performSelector:@selector(connectionDidTimeout:)
               withObject:peripheral
               afterDelay:_connectTimeout];
}

- (void)cancelConnectionTimeoutMonitor:(CBPeripheral *)peripheral
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(connectionDidTimeout:)
                                               object:peripheral];
}

- (void)connectionDidTimeout:(CBPeripheral *)peripheral
{
    DEBUGLog(@"%@", peripheral.UUID);
    
    //    [self.delegate centralClient:self
    //                  connectDidFail:[[self class] errorWithDescription:@"Unable to connect to BTLE device."]];
    [_centralManager cancelPeripheralConnection:peripheral];
    _connectTimeoutBlock();
}

/**
 Discover the services offered by a peripheral. A list of services to search for is provided
 
 - Save the parameters to instance properties
 - Set the peripheral's delegate to self
 - Discover peripheral services
 */
- (void)discoverServices:(CBPeripheral *)peripheral
               withUUIDs:(NSArray *)serviceUUIDs
         onFoundServices:(DGKBBluetoothDiscoverSuccessBlockType)block
{
    DEBUGLog(@"Start discovering...");
    _discoverBlock = block;
    _currentPeripheral = peripheral;
    peripheral.delegate = self;
    [peripheral discoverServices:serviceUUIDs];
}

/**
 Discover the characteristics of a service offered by the peripheral. A list of characteristics
 to search for is provided

 - Save the parameters to instance properties
 - Discover characteristics for the current peripheral
 */
- (void)getCharacteristics:(CBService *)service
                 withUUIDS:(NSArray *)characteristicUUIDs
                andTimeout:(NSTimeInterval)seconds
    onFoundCharacteristics:(DGKBBluetoothCharacteristicsSuccessBlockType)foundBlock
   onChangedCharacteristic:(DGKBBluetoothCharacteristicChangeBlockType)changeBlock
{
    _characteristicsBlock = foundBlock;
    _changeBlock = changeBlock;
    [_currentPeripheral discoverCharacteristics:characteristicUUIDs
                                     forService:service];
}

- (void)startRequestTimeoutMonitor:(CBCharacteristic *)characteristic
{
    [self cancelRequestTimeoutMonitor:characteristic];
    [self performSelector:@selector(requestDidTimeout:)
               withObject:characteristic
               afterDelay:_requestTimeout];
}

- (void)cancelRequestTimeoutMonitor:(CBCharacteristic *)characteristic
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(requestDidTimeout:)
                                               object:characteristic];
}

- (void)requestDidTimeout:(CBCharacteristic *)characteristic
{
    DEBUGLog(@"%@", characteristic);
    
    //    [self.delegate centralClient:self
    //        requestForCharacteristic:characteristic
    //                         didFail:[[self class] errorWithDescription:@"Unable to request data from BTLE device."]];
    [_currentPeripheral setNotifyValue:NO
                     forCharacteristic:characteristic];
}

- (NSString *)getCBCentralStateName:(CBCentralManagerState) state
{
    NSString *stateName;
    
    switch (state)
    {
        case CBCentralManagerStatePoweredOn:
            stateName = @"Bluetooth Powered On - Ready";
            break;
        case CBCentralManagerStateResetting:
            stateName = @"Resetting";
            break;
            
        case CBCentralManagerStateUnsupported:
            stateName = @"Unsupported";
            break;
            
        case CBCentralManagerStateUnauthorized:
            stateName = @"Unauthorized";
            break;
            
        case CBCentralManagerStatePoweredOff:
            stateName = @"Bluetooth Powered Off";
            break;
            
        default:
            stateName = @"Unknown";
            break;
    }
    return stateName;
}

#pragma mark -
#pragma CBCentralManagerDelegate implementation

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSString *description = [self getCBCentralStateName:central.state];

    DEBUGLog(@"%@ (%@)", description, central);
    switch (central.state)
    {
        case CBCentralManagerStatePoweredOn:
            if (_scanWhenReady)
            {
                [self startScanning];
                return;
            }
            break;
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{    
    DEBUGLog(@"Name: %@", peripheral.name);
    
    _scanBlock (peripheral, advertisementData, RSSI);
}

- (void)centralManager:(CBCentralManager *)central
  didConnectPeripheral:(CBPeripheral *)peripheral
{
    DEBUGLog(@"%@", peripheral.name);
    [self cancelConnectionTimeoutMonitor:peripheral];
    _connectBlock();
}

- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    DEBUGLog(@"%@", peripheral);
    [self cancelConnectionTimeoutMonitor:peripheral];
    //    [self.delegate centralClient:self connectDidFail:error];
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    DEBUGLog(@"%@", peripheral);
    _disconnectBlock();
}

#pragma mark -
#pragma CBPeripheralDelegate implementation

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverServices:(NSError *)error
{
    if (error) {
        //        [self.delegate centralClient:self connectDidFail:error];
        DEBUGLog(@"Error: %@", error);
        // TODO: Need to deal with resetting the state at this point.
        return;
    }
    DEBUGLog(@"Discovered");
    _discoverBlock(peripheral);
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverIncludedServicesForService:(CBService *)service
             error:(NSError *)error
{
    DEBUGLog(@"%@", peripheral);
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error)
    {
        //        [self.delegate centralClient:self connectDidFail:error];
        DEBUGLog(@"Error: %@", error);
        return;
    }
    _characteristicsBlock(service);
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    DEBUGLog(@"%@", peripheral);
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    DEBUGLog(@"Characteristic changed");
    [self cancelRequestTimeoutMonitor:characteristic];
    
    if (error) {
        DEBUGLog(@"%@", error);
        //        [self.delegate centralClient:self requestForCharacteristic:characteristic didFail:error];
        return;
    }
    _changeBlock (characteristic);
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForDescriptor:(CBDescriptor *)descriptor
             error:(NSError *)error
{
    DEBUGLog(@"%@", peripheral);
}

- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    DEBUGLog(@"%@", peripheral);
}

- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForDescriptor:(CBDescriptor *)descriptor
             error:(NSError *)error
{
    DEBUGLog(@"%@", peripheral);
}
- (void)peripheralDidInvalidateServices:(CBPeripheral *)peripheral
{
    DEBUGLog(@"%@", peripheral);
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
    DEBUGLog(@"%@", peripheral);
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    DEBUGLog(@"%@ RSSI: %@", peripheral, peripheral.RSSI);
    DEBUGLog(@"Error: %@", error);
}

@end

/** @} */
