//
//  ASBListenController.m
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 ASB. All rights reserved.
//

#import "ASBListenController.h"
#import "BlueCommon.h"
#import "DGKBluetoothScanner.h"

#define ASBBlueScanningTimeout 10.0
#define ASBBlueConnectionTimeout 10.0
#define ASBBlueRequestTimeout 20.0
#define SCREENCOLOUR [UIColor colorWithRed:0.25 green:0.5 blue:1.0 alpha:1.0]

@interface ASBListenController ()

@property (nonatomic, strong) NSString *serviceName;
@property (nonatomic, strong) NSArray *serviceUUIDs;  // CBUUIDs
@property (nonatomic, strong) NSArray *characteristicUUIDs;  // CBUUIDs

@property (nonatomic, strong) DGKBluetoothScanner *scanner;
@property (nonatomic) BOOL scanState;

// Session information
@property(nonatomic, strong) CBPeripheral *connectedPeripheral;
@property(nonatomic, strong) CBService *connectedService;

// Reply characteristic
@property(nonatomic, strong) CBCharacteristic *replyCharacteristic;

// Flags to turn on while waiting for CBCentralManager to get ready.
@property(nonatomic, assign) BOOL subscribeWhenCharacteristicsFound;
@property(nonatomic, assign) BOOL connectWhenReady;

- (void)showStatus:(NSString *)message
         andColour:(UIColor *)colour;
- (NSString *)getCBCentralStateName:(CBCentralManagerState) state;
- (void)startScanning;
- (void)stoppedScanning;

@end

@implementation ASBListenController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _serviceUUIDs = @[
                      [CBUUID UUIDWithString:SERVICEUUID],
                      ];
    _characteristicUUIDs = @[
                             [CBUUID UUIDWithString:CHARACTERISTICUUID1],
                             [CBUUID UUIDWithString:CHARACTERISTICUUID2]
                             ];

    // Initialize scanner
    _scanner = [[DGKBluetoothScanner alloc]init];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [_scanner disconnect:_connectedPeripheral];
    _connectedPeripheral = nil;
    [_scanner stopScanning];
    _scanner = nil;
    [super viewDidDisappear:animated];
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
    [_scanButton setTitle: @"Stop"
                 forState: UIControlStateNormal];

    DEBUGLog(@"Scan Starting");

    [self showStatus:@"Scanning for all services." andColour:[UIColor greenColor]];

    [self.centralManagerActivityIndicator startAnimating];
    
    _scanState = YES;  // scanning
    
    [_scanner startScanningWithTimeout:ASBBlueScanningTimeout
                     onFoundPeripheral:^(CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI)
                                       {
                                           [self foundPeripheral:peripheral
                                           withAdvertisementData:advertisementData
                                                         andRSSI:RSSI];
                                       }
                            onTimedOut:^
                                       {
                                           [self showStatus:@"Failed to find a service"
                                                  andColour:[UIColor redColor]];
                        
                        //    [self.delegate centralClient:self
                        //                  connectDidFail:[[self class] errorWithDescription:@"Unable to find a BTLE device."]];
                                           [self stoppedScanning];
                                       }];
}

- (void)stoppedScanning
{
    DEBUGLog(@"");
    [self.centralManagerActivityIndicator stopAnimating];
    [self showStatus:@"Idle"
           andColour:[UIColor blackColor]];
    _centralManagerStatus.textColor = [UIColor blackColor];
    
    [_scanButton setTitle: @"Scan"
                 forState: UIControlStateNormal];
    _scanState = NO;
}

- (void)foundPeripheral:(CBPeripheral *)peripheral
  withAdvertisementData:(NSDictionary *)advertisementData
                andRSSI:(NSNumber *)RSSI
{
    DEBUGLog(@"Peripheral CFUUID: %@", peripheral.UUID);
    DEBUGLog(@"Name: %@", peripheral.name);
    DEBUGLog(@"Advertisment Data: %@", advertisementData);
    DEBUGLog(@"RSSI: %@", RSSI);
    
    BOOL foundSuitablePeripheral = NO;
    
    CFUUIDRef UUID = peripheral.UUID;
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
    if (!foundSuitablePeripheral) return;
    [_scanner stopScanning];
    [self stoppedScanning];
    DEBUGLog(@"Connecting ... %@", UUID);
    [self showStatus:@"Connecting."
           andColour:[UIColor greenColor]];
    [_scanner connectPeripheral:peripheral
                        timeout:ASBBlueConnectionTimeout
                      onConnect:^
                                {
                                    [self connectedPeripheral:peripheral];
                                }
                   onDisconnect:^
                                {
                                    DEBUGLog(@"%@", peripheral.name);
                                    _connectedPeripheral = nil;
                                    _connectedService = nil;
         
                                    [self peripheralDidDisconnect];
                                }
                     onTimedOut:^
                                {
                                    DEBUGLog(@"%@", peripheral.name);
                                    [self showStatus:@"Failed to connect"
                                           andColour:[UIColor redColor]];
                                }];
}

- (void)connectedPeripheral:(CBPeripheral *)peripheral
{
    DEBUGLog(@"%@", peripheral.name);
    _connectedPeripheral = peripheral;
    
    // By specifying the actual services we want to connect to, this will
    // work for iOS apps that are in the background.
    //
    // If you specify nil in the list of services and the application is in the
    // background, it may sometimes only discover the Generic Access Profile
    // and the Generic Attribute Profile services.
    //[peripheral discoverServices:nil];
    
    [_scanner discoverServices:peripheral
                     withUUIDs:_serviceUUIDs
               onFoundServices:^(CBPeripheral *peripheral)
     {
         [self foundServices:peripheral];
     }];
}

- (void)foundServices:(CBPeripheral *)peripheral
{
    DEBUGLog(@"%@ (Services Count: %d)",
             peripheral.name, peripheral.services.count);
    
    for (CBService *service in peripheral.services) {
        DEBUGLog(@"Service: %@ [%@]", service.UUID, _connectedPeripheral.name);
        
        // Still iterate through all the services for logging purposes, but if
        // we found one, don't bother doing anything more.
        if (_connectedService) continue;
        
        if ([_serviceUUIDs containsObject:service.UUID])
        {
            _connectedService = service;
    
            [_scanner getCharacteristics:_connectedService
                               withUUIDS:_characteristicUUIDs
                              andTimeout:ASBBlueRequestTimeout
                  onFoundCharacteristics:^(CBService *service)
                                         {
                                             [self foundCharacteristics:service];
                                         }
                 onChangedCharacteristic:^(CBCharacteristic *characteristic)
                                         {
                                            DEBUGLog(@"%@ Value: %@", characteristic, characteristic.value);
                                            NSString *printable = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
                                            DEBUGLog(@"Text: %@", printable);
                                            _reportLog.text = [NSString stringWithFormat:@"%@%@\n", _reportLog.text, printable];
                                                 
    //                                         if (_replyCharacteristic != nil)
    //                                         {
    //                                             DEBUGLog(@"Send ACK back");
    //                                             [peripheral writeValue:[@"ACK" dataUsingEncoding:NSUTF8StringEncoding]
    //                                                  forCharacteristic:_replyCharacteristic
    //                                                               type:CBCharacteristicWriteWithResponse];
    //                                         }             
                                         }];
        }
    }
}

- (void)foundCharacteristics:(CBService *)service
{
    // For logging, just print out all the discovered services.
    DEBUGLog(@"Found %d characteristic(s)", service.characteristics.count);
    for (CBCharacteristic *characteristic in service.characteristics) {
        DEBUGLog(@"Characteristic: %@ (%d)", characteristic.UUID, characteristic.properties);
        if (characteristic.properties & CBCharacteristicPropertyWrite) _replyCharacteristic = characteristic;
    }
    
    if (service.characteristics.count < 1) {
        ERRORLog(@"Did not discover any characteristics for service. aborting.");
        [self stoppedScanning];
        [_scanner disconnect:_connectedPeripheral];
        _connectedPeripheral = nil;
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            [_connectedPeripheral setNotifyValue:YES
                                   forCharacteristic:characteristic];
        }
    }
    [self peripheralDidConnect];
    //    [self.delegate centralClientDidSubscribe:self];
}

// Does all the necessary things to find the device and make a connection.
- (void)connect {
    NSAssert(self.serviceUUIDs.count > 0, @"Need to specify services");
    NSAssert(self.characteristicUUIDs.count > 0, @"Need to specify characteristics UUID");
    
    // Check if there is a Bluetooth LE subsystem turned on.
    if (_scanner.state != CBCentralManagerStatePoweredOn) {
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

// Once connected, subscribes to all the charactersitics that are subscribe-able.
- (void)subscribe {
    if (!_connectedService) {
        NSLog(@"No connected services for peripheral at all. Unable to subscribe");
        return;
    }
    
    if (_connectedService.characteristics.count < 1) {
        self.subscribeWhenCharacteristicsFound = YES;
        
        [_scanner getCharacteristics:_connectedService
                           withUUIDS:_characteristicUUIDs
                          andTimeout:ASBBlueRequestTimeout
              onFoundCharacteristics:^(CBService *service)
                                     {
                                         // For logging, just print out all the discovered services.
                                         DEBUGLog(@"Found %d characteristic(s)", service.characteristics.count);
                                         for (CBCharacteristic *characteristic in service.characteristics) {
                                             DEBUGLog(@"Characteristic: %@ (%d)", characteristic.UUID, characteristic.properties);
                                             if (characteristic.properties & CBCharacteristicPropertyWrite) _replyCharacteristic = characteristic;
                                         }
                                         
                                         // If we did discover characteristics, these will get remembered in the
                                         // CBService instance, so there's no need to do anything more here
                                         // apart from remembering the service, in case it changed.
                                         _connectedService = service;
                                         
                                         if (service.characteristics.count < 1) {
                                             NSLog(@"Did not discover any characteristics for service. aborting.");
                                             [self stoppedScanning];
                                             [_scanner disconnect:_connectedPeripheral];
                                             _connectedPeripheral = nil;
                                             return;
                                         }
                                         
                                         for (CBCharacteristic *characteristic in service.characteristics) {
                                             if (characteristic.properties & CBCharacteristicPropertyNotify) {
                                                 [self.connectedPeripheral setNotifyValue:YES
                                                                        forCharacteristic:characteristic];
                                             }
                                         }
                                     }
             onChangedCharacteristic:^(CBCharacteristic *characteristic)
                                     {
                                         DEBUGLog(@"%@ Value: %@", characteristic, characteristic.value);
                                         NSString *printable = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
                                         DEBUGLog(@"Text: %@", printable);
                                         _reportLog.text = [NSString stringWithFormat:@"%@%@\n", _reportLog.text, printable];
                                         
//                                         if (_replyCharacteristic != nil)
//                                         {
//                                             DEBUGLog(@"Send ACK back");
//                                             [peripheral writeValue:[@"ACK" dataUsingEncoding:NSUTF8StringEncoding]
//                                                  forCharacteristic:_replyCharacteristic
//                                                               type:CBCharacteristicWriteWithResponse];
//                                         }             
                                     }];
        return;
    }
    
    self.subscribeWhenCharacteristicsFound = NO;
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

- (void)startRequestTimeout:(CBCharacteristic *)characteristic {
    [self cancelRequestTimeoutMonitor:characteristic];
    [self performSelector:@selector(requestDidTimeout:)
               withObject:characteristic
               afterDelay:ASBBlueRequestTimeout];
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
    [self.connectedPeripheral setNotifyValue:NO
                           forCharacteristic:characteristic];
}


- (void)peripheralDidConnect {
    // Pulse the screen blue.
    [UIView animateWithDuration:0.1
                     animations:^{
                         self.view.backgroundColor = [UIColor greenColor];
                     }
                     completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.1
                                          animations:^{
                                              self.view.backgroundColor = SCREENCOLOUR;
                                          }];
                         [self showStatus:@"Connected"
                                andColour:[UIColor greenColor]];
                         _disconnectButton.hidden = NO;
                     }];
}

- (void)peripheralDidDisconnect {
    // Pulse the screen red.
    [UIView animateWithDuration:0.1
                     animations:^{
                         self.view.backgroundColor = [UIColor redColor];
                     }
                     completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.1
                                          animations:^{
                                              self.view.backgroundColor = SCREENCOLOUR;
                                          }];
                         [self showStatus:@"Idle"
                                andColour:[UIColor blackColor]];
                         _disconnectButton.hidden = YES;
                     }];
}

#pragma mark - UI Action handlers

- (IBAction)didPressScanButton:(id)sender
{
    if (! _scanState)
    {
        [self startScanning];
    }
    else
    {
        [_scanner stopScanning];
        [self stoppedScanning];
    }
}

- (void)didPressDisconnectButton:(id)sender
{
    [self stoppedScanning];
    [_scanner disconnect:_connectedPeripheral];
    _connectedPeripheral = nil;
}

#pragma mark - CBCentralManager delegate implementation

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    DEBUGLog(@"%@", central);
    _hostBluetoothStatus.text = [self getCBCentralStateName:central.state];
    _hostBluetoothStatus.textColor = [UIColor whiteColor];

    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            if (self.subscribeWhenCharacteristicsFound) {
                if (self.connectedService) {
                    [self subscribe];
                    return;
                }
            }
            
            if (self.connectWhenReady) {
                [self connect];
                return;
            }
            break;
        default:
            DEBUGLog(@"centralManager did update: %d", central.state);
            break;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    DEBUGLog(@"%@ Value: %@", characteristic, characteristic.value);
    NSString *printable = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    DEBUGLog(@"Text: %@", printable);

}
@end
