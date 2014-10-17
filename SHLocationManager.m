//  SHLocationManager.m
//
//  Copyright (c) 2013 Artem Mukha
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

#import "SHLocationManager.h"

@interface SHLocationManager () <CLLocationManagerDelegate>
@property (copy, nonatomic) SHLocationCompletionHandler completionHandler;
@end

@implementation SHLocationManager {
    CLAuthorizationStatus _status;
    
    CLLocationManager *_locationManager;
    CLLocation *_lastLocation;
    
    NSTimer *_locationTimer;
    
    BOOL _locating;
    
    BOOL _needsCheckTimer;
}

- (CLLocationManager *)locationManager {
    if (!_locationManager) {
        _locationManager = [CLLocationManager new];
        _locationManager.delegate = self;
    }
    
    return _locationManager;
}

- (instancetype)init {
    return [self initWithStatus:kCLAuthorizationStatusAuthorized];
}

- (instancetype)initWithStatus:(CLAuthorizationStatus)status {
    self = [super init];
    if (self) {
        _status = status;
        
        self.desiredAccuracy = 100.0;
        self.locationAge = 10.0;
        self.locationTimeout = 30.0;
    }
    return self;
}

- (void)dealloc {
    [_locationTimer invalidate], _locationTimer = nil;
}

- (BOOL)isLocating {
    return _locating;
}

- (void)requestAuthorization {
#ifdef __IPHONE_8_0
    if (_status == kCLAuthorizationStatusAuthorizedAlways) {
        [self.locationManager requestAlwaysAuthorization];
    }
    else if (_status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self.locationManager requestWhenInUseAuthorization];
    }
#endif
}

- (BOOL)canLocate {
    CLAuthorizationStatus authStatus = CLLocationManager.authorizationStatus;
    
    if (authStatus == kCLAuthorizationStatusNotDetermined) {
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) {
            [self requestAuthorization];
        }
    }
    
    BOOL allowedStatus = authStatus == kCLAuthorizationStatusNotDetermined || authStatus == kCLAuthorizationStatusAuthorized;
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) {
#ifdef __IPHONE_8_0
        allowedStatus |= authStatus == kCLAuthorizationStatusAuthorizedWhenInUse;
#endif
    }
    
	if ( [CLLocationManager locationServicesEnabled] && allowedStatus ) {
		return YES;
    } else {
        return NO;
    }
}

- (void)startUpdatingLocationWithCompletionHandler:(SHLocationCompletionHandler)completionHandler {
    if ( [self canLocate] ) {
        self.completionHandler = completionHandler;
        
        _locating = YES;
        [self.locationManager startUpdatingLocation];
        
        [self checkLocationTimer];
    } else {
        NSError *error = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil];
        
        if (completionHandler) {
            completionHandler(nil, error);
        }
    }
}

- (void)checkLocationTimer {
    CLAuthorizationStatus authStatus = CLLocationManager.authorizationStatus;
    
    BOOL allowedStatus = authStatus == kCLAuthorizationStatusAuthorized;
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) {
#ifdef __IPHONE_8_0
        allowedStatus |= authStatus == kCLAuthorizationStatusAuthorizedWhenInUse;
#endif
    }
    
    if (allowedStatus) {
        _locationTimer = [NSTimer timerWithTimeInterval:(_hasValidLocation ? 0.5 : self.locationTimeout)
                                                 target:self
                                               selector:@selector(timerFired:) userInfo:nil repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:_locationTimer forMode:NSRunLoopCommonModes];
    }
    else if (authStatus == kCLAuthorizationStatusNotDetermined) {
        _needsCheckTimer = YES;
    }
}

- (void)timerFired:(NSTimer *)timer {
    [self finishLocating];
}

- (void)cancelUpdatingLocation {
    [self.locationManager stopUpdatingLocation];
    
    _locating = NO;
    _hasValidLocation = NO;

    [_locationTimer invalidate], _locationTimer = nil;
}

- (void)finishLocating {
    @synchronized(self) {
        [self cancelUpdatingLocation];
        
        if (_lastLocation) {
            if (self.completionHandler) {
                self.completionHandler(_lastLocation, nil);
            }
        } else {
            NSError *error = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorNetwork userInfo:nil];
            
            if (self.completionHandler) {
                self.completionHandler(nil, error);
            }
        }
    }
}

- (void)startUpdatingLocation {
    if ( [self canLocate] ) {
        _locating = YES;
        [self.locationManager startUpdatingLocation];
    }
}

- (void)waitForValidLocationWithCompletionHandler:(SHLocationCompletionHandler)completionHandler {
    if ( [self canLocate] ) {
        self.completionHandler = completionHandler;
        
        [self checkLocationTimer];
    } else {
        NSError *error = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil];
        
        if (completionHandler) {
            completionHandler(nil, error);
        }
    }
}

#pragma mark - Location manager delegate methods

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"CLLocationManager: auth status = %d", status);
    
    if (_needsCheckTimer) {
        _needsCheckTimer = NO;
        [self checkLocationTimer];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *newLocation = locations.lastObject;
    
    if (!_hasValidLocation) {
        _lastLocation = newLocation;
    }
    
    NSLog(@"New location accuracy = %f", newLocation.horizontalAccuracy);
    
    if (newLocation.horizontalAccuracy <= self.desiredAccuracy) {
        NSDate *eventDate = newLocation.timestamp;
        NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
        
        if ( fabs(howRecent) <= self.locationAge ) {
            _hasValidLocation = YES;
            _lastLocation = newLocation;
            
            if (self.completionHandler) {
                [self finishLocating];
            }
        } else {
            NSLog(@"Outdated timestamp!");
        }
    } else {
        NSLog(@"Not enough accuracy!");
    }
    
    if ( self.locating && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)] ) {
        [self.delegate locationManager:self didUpdateLocations:locations];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (error.code == kCLErrorLocationUnknown) {
        return;
    }
    
    if (self.completionHandler) {
        [self cancelUpdatingLocation];
        
        self.completionHandler(nil, error);
    }
}

@end
