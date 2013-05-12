//
//  DGKBListenController.m
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 DGKB. All rights reserved.
//

#import "DGKBListenController.h"
#import "BlueCommon.h"
#import "DGKBBluetoothScanner.h"

#define DGKBBlueScanningTimeout 10.0
#define DGKBBlueConnectionTimeout 10.0
#define DGKBBlueRequestTimeout 20.0
#define SCREENCOLOUR [UIColor colorWithRed:0.25 green:0.5 blue:1.0 alpha:1.0]

/**
 @extends DGKBListenController
 @addtogroup Controllers
 @{
 */
/**
 @brief Bluetooth Listener extension
 
 Internal functionality for Bluetooth listener. Private extensions to DGKBListenController @see DGKBListenController
 */
@interface DGKBListenController ()

@property (nonatomic, strong) NSString *serviceName;                    ///< The service name
@property (nonatomic, strong) NSArray *serviceUUIDs;                    ///< The service UUIDs to scan for
@property (nonatomic, strong) NSArray *characteristicUUIDs;             ///< The characteristic UUIDs to scan for

@property (nonatomic, strong) DGKBBluetoothScanner *scanner;            ///< The scanner
@property (nonatomic) BOOL scanState;                                   ///< Are we currently scanning?

@property(nonatomic, strong) CBPeripheral *connectedPeripheral;         ///< The currently connected peripheral
@property(nonatomic, strong) CBService *connectedService;               ///< The connected's peripheral's current service

@property(nonatomic, strong) CBCharacteristic *replyCharacteristic;     ///< Reply characteristics

@property(nonatomic, assign) BOOL subscribeWhenCharacteristicsFound;    ///< Should we subscribe to any found characteristics?
@property(nonatomic, assign) BOOL connectWhenReady;                     ///< Should we connect when Bluetooth is ready?

/**
 @brief Show the Bluetooth status
 @param message Message to display
 @param colour Colour to display the message
 
 - Display the message in the centralManagerStatus label
 */
- (void)showStatus:(NSString *)message
         andColour:(UIColor *)colour;

/**
 @brief Get a description for a central manager's state
 @param state A central manager state
 @return A descriptive text
 
 Gets a text string that describes the Bluetooth central manager state
 */
- (NSString *)getCBCentralStateName:(CBCentralManagerState) state;

/**
 @brief Will start scanning for peripherals
 */
- (void)willStartScanning;

/**
 @brief Did stop scanning for peripherals
 */
- (void)didStopScanning;

/**
 @brief Found a peripheral
 @param peripheral The peripheral
 @param advertisementData The peripheral's advertising data
 @param RSSI The Feceived Signal Strength Indicator
 */
- (void)didFindPeripheral:(CBPeripheral *)peripheral
    withAdvertisementData:(NSDictionary *)advertisementData
                  andRSSI:(NSNumber *)RSSI;

- (void)willConnect;

/**
 @brief A peripheral successfully connected
 @param peripheral The peripheral
 */
- (void)didConnectToPeripheral:(CBPeripheral *)peripheral;

/**
 @brief Services were found for the peripheral
 @param peripheral The peripheral
 */
- (void)didFindServices:(CBPeripheral *)peripheral;

/**
 @brief Characteristics were found for the peripheral's service
 @param service The service
 */
- (void)didFindCharacteristics:(CBService *)service;

- (void)willSubscribe;

- (void)willUnsubscribe;

/**
 @brief Show UI when peripheral connects
 
 - Pulse the screen green
 - Show the disconnect button
 */

- (void)peripheralDidConnect;
/**
 @brief Show UI when peripheral disconnects
 
 - Pulse the screen red
 - Hide the disconnect button
 */
- (void)peripheralDidDisconnect;

@end

/** @} */

/**
 @implements DGKBListenController
 @addtogroup Controllers
 @{
 */
@implementation DGKBListenController

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
    _scanner = [[DGKBBluetoothScanner alloc]init];
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

- (void)willStartScanning
{
    [_scanButton setTitle: @"Stop"
                 forState: UIControlStateNormal];

    DEBUGLog(@"Scan Starting");

    [self showStatus:@"Scanning for all services." andColour:[UIColor greenColor]];

    [self.centralManagerActivityIndicator startAnimating];
    
    _scanState = YES;  // scanning
    
    [_scanner startScanningWithTimeout:DGKBBlueScanningTimeout
                     onFoundPeripheral:^(CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI)
                                       {
                                           [self didFindPeripheral:peripheral
                                             withAdvertisementData:advertisementData
                                                           andRSSI:RSSI];
                                       }
                            onTimedOut:^
                                       {
                                           [self showStatus:@"Failed to find a service"
                                                  andColour:[UIColor redColor]];
                        
                        //    [self.delegate centralClient:self
                        //                  connectDidFail:[[self class] errorWithDescription:@"Unable to find a BTLE device."]];
                                           [self didStopScanning];
                                       }];
}

- (void)didStopScanning
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

- (void)didFindPeripheral:(CBPeripheral *)peripheral
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
    [self didStopScanning];
    DEBUGLog(@"Connecting ... %@", UUID);
    [self showStatus:@"Connecting."
           andColour:[UIColor greenColor]];
    [_scanner connectPeripheral:peripheral
                        timeout:DGKBBlueConnectionTimeout
                      onConnect:^
                                {
                                    [self didConnectToPeripheral:peripheral];
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

- (void)didConnectToPeripheral:(CBPeripheral *)peripheral
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
         [self didFindServices:peripheral];
     }];
}

- (void)didFindServices:(CBPeripheral *)peripheral
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
                              andTimeout:DGKBBlueRequestTimeout
                  onFoundCharacteristics:^(CBService *service)
                                         {
                                             [self didFindCharacteristics:service];
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

- (void)didFindCharacteristics:(CBService *)service
{
    // For logging, just print out all the discovered services.
    DEBUGLog(@"Found %d characteristic(s)", service.characteristics.count);
    for (CBCharacteristic *characteristic in service.characteristics) {
        DEBUGLog(@"Characteristic: %@ (%d)", characteristic.UUID, characteristic.properties);
        if (characteristic.properties & CBCharacteristicPropertyWrite) _replyCharacteristic = characteristic;
    }
    
    if (service.characteristics.count < 1) {
        ERRORLog(@"Did not discover any characteristics for service. aborting.");
        [self didStopScanning];
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
- (void)willConnect
{
    NSAssert(self.serviceUUIDs.count > 0, @"Need to specify services");
    NSAssert(self.characteristicUUIDs.count > 0, @"Need to specify characteristics UUID");
    
    // Check if there is a Bluetooth LE subsystem turned on.
    if (_scanner.state != CBCentralManagerStatePoweredOn) {
        _connectWhenReady = YES;
        return;
    }
    
    if (!_connectedPeripheral) {
        _connectWhenReady = YES;
        [self willStartScanning];
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
- (void)willSubscribe
{
    if (!_connectedService) {
        NSLog(@"No connected services for peripheral at all. Unable to subscribe");
        return;
    }
    
    if (_connectedService.characteristics.count < 1) {
        self.subscribeWhenCharacteristicsFound = YES;
        
        [_scanner getCharacteristics:_connectedService
                           withUUIDS:_characteristicUUIDs
                          andTimeout:DGKBBlueRequestTimeout
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
                                             [self didStopScanning];
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

- (void)willUnsubscribe
{
    if (!_connectedService) return;
    
    for (CBCharacteristic *characteristic in _connectedService.characteristics)
    {
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            [_connectedPeripheral setNotifyValue:NO
                               forCharacteristic:characteristic];
        }
    }
//    [self.delegate centralClientDidUnsubscribe:self];
}

- (void)startRequestTimeoutMonitor:(CBCharacteristic *)characteristic
{
    [self cancelRequestTimeoutMonitor:characteristic];
    [self performSelector:@selector(requestDidTimeout:)
               withObject:characteristic
               afterDelay:DGKBBlueRequestTimeout];
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
    [self.connectedPeripheral setNotifyValue:NO
                           forCharacteristic:characteristic];
}


- (void)peripheralDidConnect
{
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

- (void)peripheralDidDisconnect
{
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
        [self willStartScanning];
    }
    else
    {
        [_scanner stopScanning];
        [self didStopScanning];
    }
}

- (void)didPressDisconnectButton:(id)sender
{
    [self didStopScanning];
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
                    [self willSubscribe];
                    return;
                }
            }
            
            if (self.connectWhenReady) {
                [self willConnect];
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

/** @} */
