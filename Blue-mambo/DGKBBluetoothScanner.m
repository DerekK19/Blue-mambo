//
//  DGKBBluetoothScanner.m
//  Blue-mambo
//
//  Created by Derek Knight on 7/04/13.
//  Copyright (c) 2013 DGKB. All rights reserved.
//

#import "DGKBBluetoothScanner.h"

@interface DGKBBluetoothScanner ()

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic) NSTimeInterval scanTimeout;
@property (nonatomic, copy) DGKBBluetoothScanSuccessBlockType scanBlock;
@property (nonatomic, copy) DGKBBluetoothScanTimeoutBlockType scanTimeoutBlock;
@property (nonatomic, assign) BOOL scanWhenReady;
@property (nonatomic, assign) BOOL scanState;
@property (nonatomic) NSTimeInterval connectTimeout;
@property (nonatomic, copy) DGKBBluetoothConnectSuccessBlockType connectBlock;
@property (nonatomic, copy) DGKBBluetoothDisconnectSuccessBlockType disconnectBlock;
@property (nonatomic, copy) DGKBBluetoothConnectTimeoutBlockType connectTimeoutBlock;
@property (nonatomic, strong) CBPeripheral *currentPeripheral;
@property (nonatomic, copy) DGKBBluetoothDiscoverSuccessBlockType discoverBlock;
@property (nonatomic, strong) CBService *currentService;
@property (nonatomic, copy) DGKBBluetoothCharacteristicsSuccessBlockType characteristicsBlock;
@property (nonatomic, copy) DGKBBluetoothCharacteristicChangeBlockType changeBlock;
@property (nonatomic) NSTimeInterval requestTimeout;

- (void)startScanning;

@end

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

- (void)startScanningWithTimeout:(NSTimeInterval)seconds
               onFoundPeripheral:(DGKBBluetoothScanSuccessBlockType)block
                      onTimedOut:(DGKBBluetoothScanTimeoutBlockType)timeout
{
    DEBUGLog(@"Starting scan (%1.1f)...", seconds);
    _scanTimeout = seconds;
    _scanBlock = block;
    _scanTimeoutBlock = timeout;
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
    
    [_centralManager scanForPeripheralsWithServices:nil options:nil];
}

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
    
    // !!! NOTE: If you don't retain the CBPeripheral during the connection,
    //           this request will silently fail. The below method
    //           will retain peripheral for timeout purposes.
    [self startConnectionTimeoutMonitor:peripheral];
}

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

- (void)discoverServices:(CBPeripheral *)peripheral
               withUUIDs:(NSArray *)serviceUUIDs
         onFoundServices:(DGKBBluetoothDiscoverSuccessBlockType)block
{
    DEBUGLog(@"Start discovering...");
    _discoverBlock = block;
    _currentPeripheral = peripheral;
    [peripheral setDelegate:self];
    [peripheral discoverServices:serviceUUIDs];
}

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

- (void)startRequestTimeout:(CBCharacteristic *)characteristic {
    [self cancelRequestTimeoutMonitor:characteristic];
    [self performSelector:@selector(requestDidTimeout:)
               withObject:characteristic
               afterDelay:_requestTimeout];
}

- (void)cancelRequestTimeoutMonitor:(CBCharacteristic *)characteristic {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(requestDidTimeout:)
                                               object:characteristic];
}

- (void)requestDidTimeout:(CBCharacteristic *)characteristic {
    DEBUGLog(@"%@", characteristic);
    
    //    [self.delegate centralClient:self
    //        requestForCharacteristic:characteristic
    //                         didFail:[[self class] errorWithDescription:@"Unable to request data from BTLE device."]];
    [_currentPeripheral setNotifyValue:NO
                     forCharacteristic:characteristic];
}


// Converts CBCentralManagerState to a string
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

@end
