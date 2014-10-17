//  SHLocationManager.h
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

@import Foundation;
@import CoreLocation;

typedef void (^SHLocationCompletionHandler)(CLLocation *location, NSError *error);

@protocol SHLocationManagerDelegate;


@interface SHLocationManager : NSObject

- (instancetype)init; // uses kCLAuthorizationStatusAuthorized

/*
 * Uses kCLAuthorizationStatusAuthorizedAlways or kCLAuthorizationStatusAuthorizedWhenInUse
 */
- (instancetype)initWithStatus:(CLAuthorizationStatus)status __OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_8_0);

@property (nonatomic, readonly, getter = isLocating) BOOL locating;

@property (nonatomic, readonly) BOOL hasValidLocation;

- (void)startUpdatingLocationWithCompletionHandler:(SHLocationCompletionHandler)completionHandler;
- (void)cancelUpdatingLocation;

- (void)startUpdatingLocation;
- (void)waitForValidLocationWithCompletionHandler:(SHLocationCompletionHandler)completionHandler;

@property (weak, nonatomic) id <SHLocationManagerDelegate> delegate;

// Filter locations which we wanna see in completion handler

@property (nonatomic) double desiredAccuracy; // default is 100 meters

@property (nonatomic) NSTimeInterval locationAge; // default is 10 seconds ago

@property (nonatomic) NSTimeInterval locationTimeout; // if no correct location were found we use what we have after this interval. Default is 30 seconds

@end


@protocol SHLocationManagerDelegate <NSObject>

@optional

/* if you still wanna observe each location update */
- (void)locationManager:(SHLocationManager *)manager didUpdateLocations:(NSArray *)locations;

@end
