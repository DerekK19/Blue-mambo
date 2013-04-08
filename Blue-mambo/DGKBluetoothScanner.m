//
//  DGKBluetoothScanner.m
//  Blue-mambo
//
//  Created by Derek Knight on 7/04/13.
//  Copyright (c) 2013 ASB. All rights reserved.
//

#import "DGKBluetoothScanner.h"

@interface DGKBluetoothScanner ()

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic) NSTimeInterval scanTimeout;
@property (nonatomic, copy) DGKBluetoothScanSuccessBlockType scanBlock;
@property (nonatomic, copy) DGKBluetoothScanTimeoutBlockType scanTimeoutBlock;
@property (nonatomic, assign) BOOL scanWhenReady;
@property (nonatomic, assign) BOOL scanState;
@property (nonatomic) NSTimeInterval connectTimeout;
@property (nonatomic, copy) DGKBluetoothConnectSuccessBlockType connectBlock;
@property (nonatomic, copy) DGKBluetoothDisconnectSuccessBlockType disconnectBlock;
@property (nonatomic, copy) DGKBluetoothConnectTimeoutBlockType connectTimeoutBlock;

- (void)startScanning;

@end

@implementation DGKBluetoothScanner

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
               onFoundPeripheral:(DGKBluetoothScanSuccessBlockType)block
                      onTimedOut:(DGKBluetoothScanTimeoutBlockType)timeout
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
                onConnect:(DGKBluetoothConnectSuccessBlockType)connectBlock
             onDisconnect:(DGKBluetoothDisconnectSuccessBlockType)disconnectBlock
               onTimedOut:(DGKBluetoothConnectTimeoutBlockType)timeoutBlock
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

- (void)startConnectionTimeoutMonitor:(CBPeripheral *)peripheral {
    [self cancelConnectionTimeoutMonitor:peripheral];
    [self performSelector:@selector(connectionDidTimeout:)
               withObject:peripheral
               afterDelay:_connectTimeout];
}

- (void)cancelConnectionTimeoutMonitor:(CBPeripheral *)peripheral {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(connectionDidTimeout:)
                                               object:peripheral];
}

- (void)connectionDidTimeout:(CBPeripheral *)peripheral {
    DEBUGLog(@"%@", peripheral.UUID);
    
    //    [self.delegate centralClient:self
    //                  connectDidFail:[[self class] errorWithDescription:@"Unable to connect to BTLE device."]];
    [_centralManager cancelPeripheralConnection:peripheral];
    _connectTimeoutBlock();
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

@end
