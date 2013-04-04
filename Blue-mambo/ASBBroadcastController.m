//
//  ASBBroadcastController.m
//  Blue-mambo
//
//  Created by Derek Knight on 4/04/13.
//  Copyright (c) 2013 ASB. All rights reserved.
//

#import "ASBBroadcastController.h"
#import "BlueCommon.h"

@interface ASBBroadcastController ()

@property(nonatomic, strong) NSString *serviceName;
@property(nonatomic, strong) CBUUID *serviceUUID;
@property(nonatomic, strong) CBUUID *characteristicUUID;

@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property(nonatomic, assign) BOOL serviceRequiresRegistration;
@property(nonatomic, strong) CBMutableService *service;
@property(nonatomic, strong) CBMutableCharacteristic *characteristic;

- (void)showStatus:(NSString *)message
         andColour:(UIColor *)colour;

- (NSString *)getCBPeripheralStateName:(CBPeripheralManagerState) state;

@end

@implementation ASBBroadcastController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _serviceName = SERVICENAME;
    _serviceUUID = [CBUUID UUIDWithString:SERVICEUUID];
    _characteristicUUID = [CBUUID UUIDWithString:CHARACTERISTICUUID];
    
    // Initialize peripheral manager providing self as its delegate
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
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
    self.characteristic = [[CBMutableCharacteristic alloc] initWithType:_characteristicUUID
                                                             properties:CBCharacteristicPropertyNotify
                                                                  value:nil
                                                            permissions:0];
    
    // Assign the characteristic.
    _service.characteristics = [NSArray arrayWithObject:_characteristic];
    
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
           andColour:[UIColor greenColor]];
}

- (BOOL)isAdvertising {
    return [_peripheralManager isAdvertising];
}

- (void)showStatus:(NSString *)message
         andColour:(UIColor *)colour
{
    _peripheralManagerStatus.text = message;
    _peripheralManagerStatus.textColor = [UIColor whiteColor];
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

#pragma mark - CBPeripheralManagerDelegate delegate implementation

- (void)peripheralManager:(CBPeripheralManager *)peripheral
            didAddService:(CBService *)service
                    error:(NSError *)error {
    // As soon as the service is added, we should start advertising.
    [self startAdvertising];
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    DEBUGLog(@"peripheralManagerDidUpdateState %@", peripheral);
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
    DEBUGLog(@"didSubscribe: %@", characteristic.UUID);
    DEBUGLog(@"didSubscribe: - Central: %@", central.UUID);
//    [self centralDidConnect];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
                  central:(CBCentral *)central
didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    DEBUGLog(@"didUnsubscribe: %@", central.UUID);
//    [self centralDidDisconnect];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral
                                       error:(NSError *)error {
    if (error) {
        DEBUGLog(@"didStartAdvertising: Error: %@", error);
        return;
    }
    DEBUGLog(@"didStartAdvertising");
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral {
    DEBUGLog(@"isReadyToUpdateSubscribers");
//    if (self.pendingData) {
//        NSData *data = [self.pendingData copy];
//        self.pendingData = nil;
//        [self sendToSubscribers:data];
//    }
}

@end
