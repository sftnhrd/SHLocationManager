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
#import <CoreLocation/CoreLocation.h>


@interface SHLocationManager () <CLLocationManagerDelegate>
@property (copy, nonatomic) SHLocationCompletionHandler completionHandler;
@end

@implementation SHLocationManager {
    CLLocationManager *_locationManager;
    CLLocation *_lastLocation;
    
    NSTimer *_locationTimer;
    
    BOOL _locating;
}

- (CLLocationManager *)locationManager
{
    if (!_locationManager) {
        _locationManager = [CLLocationManager new];
        _locationManager.delegate = self;
    }
    
    return _locationManager;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.desiredAccuracy = 100.0;
        self.locationAge = 10.0;
        self.locationTimeout = 30.0;
    }
    return self;
}

- (void)dealloc
{
    [_locationTimer invalidate], _locationTimer = nil;
}

- (BOOL)isLocating
{
    return _locating;
}

+ (BOOL)canLocate
{
	CLAuthorizationStatus authStatus = [CLLocationManager authorizationStatus];
	if ( [CLLocationManager locationServicesEnabled]
		&&
		( authStatus == kCLAuthorizationStatusNotDetermined ||
		 authStatus == kCLAuthorizationStatusAuthorized )
		)
	{
		return YES;
	}
	
	return NO;
}

- (void)startUpdatingLocationWithCompletionHandler:(SHLocationCompletionHandler)completionHandler
{
    if ( [SHLocationManager canLocate] ) {
        self.completionHandler = completionHandler;
        
        _locating = YES;
        [self.locationManager startUpdatingLocation];
        
        _locationTimer = [NSTimer timerWithTimeInterval:self.locationTimeout
                                                 target:self
                                               selector:@selector(timerFired:) userInfo:nil repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:_locationTimer forMode:NSRunLoopCommonModes];
    } else {
        NSError *error = [NSError errorWithDomain:kCLErrorDomain code:kCLErrorDenied userInfo:nil];
        
        if (completionHandler) {
            completionHandler(nil, error);
        }
    }
}

- (void)timerFired:(NSTimer *)timer
{
    NSLog(@"Location timer fired!");
    [self finishLocating];
}

- (void)cancelUpdatingLocation
{
    [self.locationManager stopUpdatingLocation];
    _locating = NO;

    [_locationTimer invalidate], _locationTimer = nil;
}

- (void)finishLocating
{
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

#pragma mark - Location manager delegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    _lastLocation = locations.lastObject;
    
    NSLog(@"Last location accuracy = %f", _lastLocation.horizontalAccuracy);
    
    if (_lastLocation.horizontalAccuracy <= self.desiredAccuracy) {
        NSDate *eventDate = _lastLocation.timestamp;
        NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
        
        if ( fabs(howRecent) <= self.locationAge ) {
            [self finishLocating];
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

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if (error.code == kCLErrorLocationUnknown) {
        return;
    }
    
    [self cancelUpdatingLocation];
    
    if (self.completionHandler) {
        self.completionHandler(nil, error);
    }
}

@end
