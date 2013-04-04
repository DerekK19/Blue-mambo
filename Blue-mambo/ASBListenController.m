//
//  ASBListenController.m
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 ASB. All rights reserved.
//

#import "ASBListenController.h"
#import "BlueCommon.h"
#define ASBBlueScanningTimeout 10.0
#define ASBBlueConnectionTimeout 10.0

@interface ASBListenController ()

@property (nonatomic, strong) NSString *serviceName;
@property (nonatomic, strong) NSArray *serviceUUIDs;  // CBUUIDs
@property (nonatomic, strong) NSArray *characteristicUUIDs;  // CBUUIDs

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic) BOOL scanState;

// Session information
@property(nonatomic, strong) CBPeripheral *connectedPeripheral;
@property(nonatomic, strong) CBService *connectedService;

// Flags to turn on while waiting for CBCentralManager to get ready.
@property(nonatomic, assign) BOOL subscribeWhenCharacteristicsFound;
@property(nonatomic, assign) BOOL connectWhenReady;

- (void)showStatus:(NSString *)message
         andColour:(UIColor *)colour;
- (NSString *)getCBCentralStateName:(CBCentralManagerState) state;
- (void)startScanning;
- (void)stopScanning;
- (void)startScanningTimeoutMonitor;
- (void)cancelScanningTimeoutMonitor;
- (void)scanningDidTimeout;
- (void)startConnectionTimeoutMonitor:(CBPeripheral *)peripheral;
- (void)cancelConnectionTimeoutMonitor:(CBPeripheral *)peripheral;
- (void)connectionDidTimeout:(CBPeripheral *)peripheral;

@end

@implementation ASBListenController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _serviceUUIDs = @[
                      [CBUUID UUIDWithString:SERVICEUUID],
                      ];
    _characteristicUUIDs = @[
                             [CBUUID UUIDWithString:CHARACTERISTICUUID]
                             ];

    // Initialize central manager providing self as its delegate
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private functions

- (void)showStatus:(NSString *)message
         andColour:(UIColor *)colour
{
    _centralManagerStatus.text = message;
    _centralManagerStatus.textColor = colour;
}

// Converts CBCentralManagerState to a string
- (NSString *)getCBCentralStateName:(CBCentralManagerState) state
{
    NSString *stateName;
    
    switch (state) {
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

- (void)startScanning
{
    _scanState = YES;  // scanning
    [_scanButton setTitle: @"Stop"
                 forState: UIControlStateNormal];
    
    DEBUGLog(@"Starting scan...");
    
    [self showStatus:@"Scanning for all services." andColour:[UIColor greenColor]];
    [self startScanningTimeoutMonitor];
    
    [_centralManager scanForPeripheralsWithServices:nil options:nil];
    
    [self.centralManagerActivityIndicator startAnimating];
}

- (void)stopScanning
{
    DEBUGLog(@"Scan stopped");
    [self.centralManagerActivityIndicator stopAnimating];
    [self showStatus:@"Idle"
           andColour:[UIColor blackColor]];
    _centralManagerStatus.textColor = [UIColor blackColor];
    {
        [_centralManager stopScan];
    }
    
    [_scanButton setTitle: @"Scan"
                 forState: UIControlStateNormal];
    _scanState = NO;
}

// Does all the necessary things to find the device and make a connection.
- (void)connect {
    NSAssert(self.serviceUUIDs.count > 0, @"Need to specify services");
    NSAssert(self.characteristicUUIDs.count > 0, @"Need to specify characteristics UUID");
    
    // Check if there is a Bluetooth LE subsystem turned on.
    if (_centralManager.state != CBCentralManagerStatePoweredOn) {
        _connectWhenReady = YES;
        return;
    }
    
    if (!_connectedPeripheral) {
        _connectWhenReady = YES;
        [self startScanning];
        return;
    }
    
    if (!_connectedService) {
        _connectWhenReady = YES;
        [_connectedPeripheral setDelegate:self];
        
        // By specifying the actual services we want to connect to, this will
        // work for iOS apps that are in the background.
        //
        // If you specify nil in the list of services and the application is in the
        // background, it may sometimes only discover the Generic Access Profile
        // and the Generic Attribute Profile services.
        //[peripheral discoverServices:nil];
        
        [_connectedPeripheral discoverServices:self.serviceUUIDs];
        return;
    }
}

- (void)disconnect {
    [self stopScanning];
    [_centralManager cancelPeripheralConnection:self.connectedPeripheral];
    self.connectedPeripheral = nil;
}

// Once connected, subscribes to all the charactersitics that are subscribe-able.
- (void)subscribe {
    if (!_connectedService) {
        NSLog(@"No connected services for peripheralat all. Unable to subscribe");
        return;
    }
    
    if (_connectedService.characteristics.count < 1) {
        self.subscribeWhenCharacteristicsFound = YES;
        
        [_connectedPeripheral discoverCharacteristics:self.characteristicUUIDs
                                           forService:_connectedService];
        return;
    }
    
    self.subscribeWhenCharacteristicsFound = NO;
    for (CBCharacteristic *characteristic in self.connectedService.characteristics) {
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            [self.connectedPeripheral setNotifyValue:YES
                                   forCharacteristic:characteristic];
        }
    }
//    [self.delegate centralClientDidSubscribe:self];
}

- (void)unsubscribe {
    if (!_connectedService) return;
    
    for (CBCharacteristic *characteristic in _connectedService.characteristics) {
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            [_connectedPeripheral setNotifyValue:NO
                               forCharacteristic:characteristic];
        }
    }
//    [self.delegate centralClientDidUnsubscribe:self];
}

- (void)startScanningTimeoutMonitor {
    [self cancelScanningTimeoutMonitor];
    [self performSelector:@selector(scanningDidTimeout)
               withObject:nil
               afterDelay:ASBBlueScanningTimeout];
}

- (void)cancelScanningTimeoutMonitor {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(scanningDidTimeout)
                                               object:nil];
}

- (void)scanningDidTimeout {
    DEBUGLog(@"Scanning did timeout");
    
    [self showStatus:@"Failed to find a service"
           andColour:[UIColor redColor]];

//    [self.delegate centralClient:self
//                  connectDidFail:[[self class] errorWithDescription:@"Unable to find a BTLE device."]];
    [self stopScanning];
}

- (void)startConnectionTimeoutMonitor:(CBPeripheral *)peripheral {
    [self cancelConnectionTimeoutMonitor:peripheral];
    [self performSelector:@selector(connectionDidTimeout:)
               withObject:peripheral
               afterDelay:ASBBlueConnectionTimeout];
}

- (void)cancelConnectionTimeoutMonitor:(CBPeripheral *)peripheral {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(connectionDidTimeout:)
                                               object:peripheral];
}

- (void)connectionDidTimeout:(CBPeripheral *)peripheral {
    DEBUGLog(@"connectionDidTimeout: %@", peripheral.UUID);
    
    [self showStatus:@"Failed to connect"
           andColour:[UIColor redColor]];
    
//    [self.delegate centralClient:self
//                  connectDidFail:[[self class] errorWithDescription:@"Unable to connect to BTLE device."]];
    [_centralManager cancelPeripheralConnection:peripheral];
}

- (void)centralDidConnect {
    // Pulse the screen blue.
    [UIView animateWithDuration:0.1
                     animations:^{
                         self.view.backgroundColor = [UIColor blueColor];
                     }
                     completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.1
                                          animations:^{
                                              self.view.backgroundColor =
                                              [UIColor colorWithWhite:0.2 alpha:1.0];
                                          }];
                     }];
}

- (void)centralDidDisconnect {
    // Pulse the screen red.
    [UIView animateWithDuration:0.1
                     animations:^{
                         self.view.backgroundColor = [UIColor redColor];
                     }
                     completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.1
                                          animations:^{
                                              self.view.backgroundColor =
                                              [UIColor colorWithWhite:0.2 alpha:1.0];
                                          }];
                     }];
}

#pragma mark - UI Action handlers

- (IBAction)didPressScanButton
{
    if (! _scanState)
    {
        if (_centralManager.state == CBCentralManagerStatePoweredOn)
        {
            [self startScanning];
        }
        else
        {
            DEBUGLog(@"Scan request not executed, central manager not in powered on state");
            DEBUGLog(@"Central Manager state: %@",[self getCBCentralStateName: _centralManager.state]);
        }
    }
    else  // stop scanning
    {
        [self stopScanning];
    }
}

#pragma mark - CBCentralManager delegate implementation

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    DEBUGLog(@"centralManagerDidUpdateState %@", central);
    _hostBluetoothStatus.text = [self getCBCentralStateName:central.state];
    _hostBluetoothStatus.textColor = [UIColor whiteColor];
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    
    DEBUGLog(@"didDiscoverPeripheral: Peripheral CFUUID: %@", peripheral.UUID);
    DEBUGLog(@"didDiscoverPeripheral: Name: %@", peripheral.name);
    DEBUGLog(@"didDiscoverPeripheral: Advertisment Data: %@", advertisementData);
    DEBUGLog(@"didDiscoverPeripheral: RSSI: %@", RSSI);
    
    BOOL foundSuitablePeripheral = NO;

    CFUUIDRef UUID = peripheral.UUID;
    if (YES || UUID)
    {
//        CBUUID *peripheralUUID = [CBUUID UUIDWithCFUUID:UUID];

        // Figure out whether this device has the right service.
        if (!foundSuitablePeripheral) {
            NSArray *serviceUUIDs =
            [advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
            for (CBUUID *foundServiceUUIDs in serviceUUIDs) {
                if ([_serviceUUIDs containsObject:foundServiceUUIDs]) {
                    foundSuitablePeripheral = YES;
                    break;
                }
            }
        }
        
        // When the iOS app is in background, the advertisments sometimes does not
        // contain the service UUIDs you advertise(!). So we fallback to just
        // check whether the name of the device is the correct one.
        if (!foundSuitablePeripheral) {
            NSString *peripheralName =
            [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
            foundSuitablePeripheral = [_serviceName isEqualToString:peripheralName];
        }
        
        // At this point, if we still haven't found one, chances are the
        // iOS app has been killed in the background and the service is not
        // responding any more.
        //
        // There isn't much you can do at this point since connecting to the
        // peripheral won't really do anything if you can't spot the service.
        //
        // TODO: check what alternatives there are, maybe opening up bluetooth-central
        //       as a UIBackgroundModes will work.
        
        
        // If we found something to connect to, start connecting to it.
        // TODO: This does not deal with multiple devices advertising the same service
        //       yet.
        if (foundSuitablePeripheral)
        {
            [self cancelScanningTimeoutMonitor];
            [self stopScanning];
            DEBUGLog(@"Connecting ... %@", UUID);
            [self showStatus:@"Connecting."
                   andColour:[UIColor greenColor]];
            [_centralManager connectPeripheral:peripheral
                                       options:nil];
            
            // !!! NOTE: If you don't retain the CBPeripheral during the connection,
            //           this request will silently fail. The below method
            //           will retain peripheral for timeout purposes.
            [self startConnectionTimeoutMonitor:peripheral];
        }
    }
}

#pragma mark - CBPeripheralDelegate delegate implementation

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverServices:(NSError *)error {
    if (error) {
        //        [self.delegate centralClient:self connectDidFail:error];
        DEBUGLog(@"didDiscoverServices: Error: %@", error);
        // TODO: Need to deal with resetting the state at this point.
        return;
    }
    
    DEBUGLog(@"didDiscoverServices: %@ (Services Count: %d)",
             peripheral.name, peripheral.services.count);
    
    for (CBService *service in peripheral.services) {
        DEBUGLog(@"didDiscoverServices: Service: %@", service.UUID);
        
        // Still iterate through all the services for logging purposes, but if
        // we found one, don't bother doing anything more.
        if (_connectedService) continue;
        
        if ([self.serviceUUIDs containsObject:service.UUID]) {
            self.connectedService = service;
        }
    }
    [self centralDidConnect];
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error {
    if (error) {
        //        [self.delegate centralClient:self connectDidFail:error];
        DEBUGLog(@"didDiscoverChar: Error: %@", error);
        return;
    }
    
    // For logging, just print out all the discovered services.
    DEBUGLog(@"didDiscoverChar: Found %d characteristic(s)", service.characteristics.count);
    for (CBCharacteristic *characteristic in service.characteristics) {
        DEBUGLog(@"didDiscoverChar:  Characteristic: %@", characteristic.UUID);
    }
    
    // If we did discover characteristics, these will get remembered in the
    // CBService instance, so there's no need to do anything more here
    // apart from remembering the service, in case it changed.
    _connectedService = service;
    
    if (service.characteristics.count < 1) {
        NSLog(@"didDiscoverChar: did not discover any characterestics for service. aborting.");
        [self disconnect];
        return;
    }
    
    if (self.subscribeWhenCharacteristicsFound) {
        [self subscribe];
    }
}

@end
