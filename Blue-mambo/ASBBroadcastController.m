//
//  ASBBroadcastController.m
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 ASB. All rights reserved.
//

#import "ASBBroadcastController.h"
#import "BlueCommon.h"

#define SCREENCOLOUR [UIColor blueColor]

@interface ASBBroadcastController ()

@property(nonatomic, strong) NSString *serviceName;
@property(nonatomic, strong) CBUUID *serviceUUID;
@property(nonatomic, strong) CBUUID *characteristicUUID;

@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property(nonatomic, assign) BOOL serviceRequiresRegistration;
@property(nonatomic, strong) CBMutableService *service;
@property(nonatomic, strong) CBMutableCharacteristic *characteristic1;
@property(nonatomic, strong) CBMutableCharacteristic *characteristic2;

@property(nonatomic, strong) NSData *pendingData;

- (void)showStatus:(NSString *)message
         andColour:(UIColor *)colour;

- (NSString *)getCBPeripheralStateName:(CBPeripheralManagerState) state;

@end

@implementation ASBBroadcastController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _serviceName = SERVICENAME;
    _serviceUUID = [CBUUID UUIDWithString:SERVICEUUID];
//    _characteristicUUID = [CBUUID UUIDWithString:CHARACTERISTICUUID];
    
    // Initialize peripheral manager providing self as its delegate
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self stopAdvertising];
    _peripheralManager = nil;
    
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private functions

- (void)enableService {
    // If the service is already registered, we need to re-register it again.
    if (_service) {
        [_peripheralManager removeService:self.service];
    }
    
    // Create a BTLE Peripheral Service and set it to be the primary. If it
    // is not set to the primary, it will not be found when the app is in the
    // background.
    _service = [[CBMutableService alloc] initWithType:_serviceUUID
                                              primary:YES];
    
    // Set up the characteristic in the service. This characteristic is only
    // readable through subscription (CBCharacteristicsPropertyNotify) and has
    // no default value set.
    //
    // There is no need to set the permission on characteristic.
    // Assign the characteristic.
    _characteristic1 = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:CHARACTERISTICUUID1]
                                                          properties:CBCharacteristicPropertyNotify
                                                               value:nil
                                                         permissions:0];
    _characteristic2 = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:CHARACTERISTICUUID2]
                                                          properties:CBCharacteristicPropertyWrite
                                                               value:nil
                                                         permissions:CBAttributePermissionsWriteable];
    _service.characteristics = @[_characteristic1,
                                 _characteristic2];
    
    // Add the service to the peripheral manager.
    [_peripheralManager addService:_service];
}

- (void)disableService {
    [_peripheralManager removeService:_service];
    _service = nil;
    [self stopAdvertising];
}


// Called when the BTLE advertisments should start. We don't take down
// the advertisments unless the user switches us off.
- (void)startAdvertising {
    if (_peripheralManager.isAdvertising) {
        [_peripheralManager stopAdvertising];
    }
    
    NSDictionary *advertisment = @{
                                   CBAdvertisementDataServiceUUIDsKey : @[_serviceUUID],
                                   CBAdvertisementDataLocalNameKey : _serviceName
                                   };
    [_peripheralManager startAdvertising:advertisment];
    [self showStatus:@"Advertising"
           andColour:[UIColor greenColor]];
}

- (void)stopAdvertising {
    [_peripheralManager stopAdvertising];
    [self showStatus:@"Idle"
           andColour:[UIColor blackColor]];
}

- (BOOL)isAdvertising {
    return [_peripheralManager isAdvertising];
}

- (void)showStatus:(NSString *)message
         andColour:(UIColor *)colour
{
    _peripheralManagerStatus.text = message;
    _peripheralManagerStatus.textColor = colour;
}

// Converts CBPeripheralManagerState to a string
- (NSString *)getCBPeripheralStateName:(CBPeripheralManagerState) state
{
    NSString *stateName;
    
    switch (state) {
        case CBPeripheralManagerStatePoweredOn:
            stateName = @"Bluetooth Powered On - Ready";
            break;
            
        case CBPeripheralManagerStateResetting:
            stateName =@"Resetting";
            break;
            
        case CBPeripheralManagerStateUnsupported:
            stateName = @"Unsupported";
            break;
            
        case CBPeripheralManagerStateUnauthorized:
            stateName = @"Unauthorized";
            break;
            
        case CBPeripheralManagerStatePoweredOff:
            stateName = @"Bluetooth Powered Off";
            break;
            
        case CBPeripheralManagerStateUnknown:
            stateName = @"Unknown";
            break;
            
        default:
            stateName = @"Unknown";
            break;
    }
    return stateName;
}

- (void)sendToSubscribers:(NSData *)data {
    if (_peripheralManager.state != CBPeripheralManagerStatePoweredOn) {
        DEBUGLog(@"sendToSubscribers: peripheral not ready for sending state: %d", _peripheralManager.state);
        return;
    }
    
    BOOL success = [_peripheralManager updateValue:data
                                 forCharacteristic:self.characteristic1
                              onSubscribedCentrals:nil];
    if (!success) {
        DEBUGLog(@"Failed to send data, buffering data for retry once ready.");
        _pendingData = data;
        return;
    }
    DEBUGLog(@"Sent %d bytes", [data length]);
}

- (void)centralDidConnect {
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

- (void)centralDidDisconnect {
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
                         [self showStatus:@"Advertising"
                                andColour:[UIColor greenColor]];
                         _disconnectButton.hidden = YES;

                     }];
}

#pragma mark - UI Action handlers

- (void)didPressDisconnectButton:(id)sender
{
    
}

#pragma mark - CBPeripheralManagerDelegate delegate implementation

- (void)peripheralManager:(CBPeripheralManager *)peripheral
            didAddService:(CBService *)service
                    error:(NSError *)error {
    // As soon as the service is added, we should start advertising.
    [self startAdvertising];
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    DEBUGLog(@"%@", peripheral);
    _hostBluetoothStatus.text = [self getCBPeripheralStateName:peripheral.state];
    _hostBluetoothStatus.textColor = [UIColor whiteColor];
    
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
            [self enableService];
            break;
        
        case CBPeripheralManagerStatePoweredOff:
            [self disableService];
            self.serviceRequiresRegistration = YES;
            break;
        
        case CBPeripheralManagerStateResetting:
            self.serviceRequiresRegistration = YES;
            break;

        case CBPeripheralManagerStateUnauthorized:
            [self disableService];
            self.serviceRequiresRegistration = YES;
            break;

        case CBPeripheralManagerStateUnsupported:
            self.serviceRequiresRegistration = YES;
            // TODO: Give user feedback that Bluetooth is not supported.
            break;

        case CBPeripheralManagerStateUnknown:
            break;
        
        default:
            break;
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
                  central:(CBCentral *)central
didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    DEBUGLog(@"%@", characteristic.UUID);
    DEBUGLog(@"Central: %@", central.UUID);
    [self centralDidConnect];
    [self sendToSubscribers:[@"Hello" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
                  central:(CBCentral *)central
didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    DEBUGLog(@"%@", central.UUID);
    [self centralDidDisconnect];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral
                                       error:(NSError *)error {
    if (error) {
        DEBUGLog(@"Error: %@", error);
        return;
    }
    DEBUGLog(@"");
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral {
    DEBUGLog(@"");
    if (_pendingData) {
        NSData *data = [_pendingData copy];
        _pendingData = nil;
        [self sendToSubscribers:data];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
  didReceiveWriteRequests:(NSArray *)requests
{
    DEBUGLog(@"");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
    didReceiveReadRequest:(CBATTRequest *)request
{
    DEBUGLog(@"");
}

@end
