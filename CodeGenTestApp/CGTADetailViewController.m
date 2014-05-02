//
//  CGTADetailViewController.m
//  CodeGenTestApp
//
//  Created by Jim Puls on 2/3/14.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "CGTADetailViewController.h"
#import "CGTATestAppColorList.h"
#import "CGTAMainStoryboardIdentifiers.h"
#import "CGTAMainModel.h"
#import "CGTAAppDelegate.h"
#import "CGTAMainModel.h"


@interface CGTADetailViewController ()

@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *tapLabel;
@property (weak, nonatomic) IBOutlet UILabel *countryNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *capitalNameLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *countryNameTopConstraint;
@property (nonatomic) BOOL countryNameVisible;

@end


@implementation CGTADetailViewController

- (void)setImage:(UIImage *)image;
{
    _image = image;
    [self updateView];
}

- (void)setCountryName:(NSString *)countryName;
{
    _countryName = countryName;
    [self updateView];
}

- (void)loadAllCountriesIfNeeded;
{
    static BOOL attemptedToLoad = NO;
    if (attemptedToLoad) {
        return;
    }
    attemptedToLoad = YES;
    
    CGTAAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    NSManagedObjectContext *context = delegate.managedObjectContext;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[Country entityName]];
    NSInteger count = [context countForFetchRequest:request error:NULL];
    if (count > 0) {
        return;
    }

    NSDictionary *countryCapitals = @
    {
        @"argentina": @"Buenos Aires",
        @"australia": @"Canberra",
        @"austria": @"Vienna",
        @"belgium": @"Brussels",
        @"brazil": @"Brasilia",
        @"cameroon": @"Yaounde",
        @"canada": @"Ottawa",
        @"chile": @"Santiago",
        @"china": @"Beijing",
        @"denmark": @"Copenhagen",
        @"finland": @"Helsinki",
        @"france": @"Paris",
        @"germany": @"Berlin",
        @"greece": @"Athens",
        @"hongKong": @"Victoria",
        @"hungary": @"Budapest",
        @"iceland": @"Reykjavik",
        @"india": @"New Delhi",
        @"indonesia": @"Jakarta",
        @"ireland": @"Dublin",
        @"israel": @"Jerusalem",
        @"italy": @"Rome",
        @"japan": @"Tokyo",
        @"malaysia": @"Kuala Lumpur",
        @"mexico": @"Mexico City",
        @"netherlands": @"Amsterdam",
        @"newZealand": @"Wellington",
        @"norway": @"Oslo",
        @"pakistan": @"Islamabad",
        @"palestine": @"Ramallah",
        @"peru": @"Lima",
        @"poland": @"Warsaw",
        @"portugal": @"Lisbon",
        @"puertoRico": @"San Juan",
        @"romania": @"Bucharest",
        @"russia": @"Moscow",
        @"saudiArabia": @"Riyadh",
        @"singapore": @"Singapore",
        @"southAfrica": @"Pretoria",
        @"southKorea": @"Seoul",
        @"spain": @"Madrid",
        @"sweden": @"Stockholm",
        @"switzerland": @"Bern",
        @"thailand": @"Bangkok",
        @"turkey": @"Ankara",
        @"uk": @"London",
        @"ukraine": @"Kyiv",
        @"uruguay": @"Montevideo",
        @"usa": @"Washington D.C.",
        @"venezuela": @"Caracas",
    };
    
    for (NSString *countryName in countryCapitals) {
        Country *country = [NSEntityDescription insertNewObjectForEntityForName:[Country entityName] inManagedObjectContext:context];
        country.name = [countryName lowercaseString];
        country.capital = countryCapitals[countryName];
    }
    
    // Save the context.
    NSError *error = nil;
    if (![context save:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}

- (NSString *)capitalForCountryName:(NSString *)countryName;
{
    [self loadAllCountriesIfNeeded];
    CGTAAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    NSManagedObjectContext *context = delegate.managedObjectContext;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[Country entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"%K = %@", [Country name], [countryName lowercaseString]];
    NSArray *results = [context executeFetchRequest:request error:NULL];
    if (results.count > 0) {
        Country *country = results[0];
        return country.capital;
    } else {
        return nil;
    }
}

- (void)setCountryNameVisible:(BOOL)countryNameVisible;
{
    [self setCountryNameVisible:countryNameVisible animated:NO];
}

- (void)setCountryNameVisible:(BOOL)countryNameVisible animated:(BOOL)animated;
{
    _countryNameVisible = countryNameVisible;
    
    // the label was positioned perfectly via the storyboard, so now we can restore
    // this positioning simply by refering to the constant that was generated for us!
    self.countryNameTopConstraint.constant = countryNameVisible ? [self countryNameTopConstraintOriginalConstant] : 0;
    
    if (animated) {
        [UIView animateWithDuration:0.2
                         animations:^{
                             self.tapLabel.alpha = countryNameVisible ? 0 : 1;
                             [self.view layoutIfNeeded];
                         }];
    } else {
        self.tapLabel.alpha = countryNameVisible ? 0 : 1;
    }
}

- (void)viewDidLoad;
{
    [self updateView];
    
    self.countryNameLabel.textColor = [UIColor whiteColor];
    self.capitalNameLabel.textColor = [UIColor whiteColor];
    
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.startPoint = CGPointMake(0.5, 0.5);
    layer.endPoint = CGPointMake(0.5, 1.0);
    
    layer.colors = @[(id)[UIColor whiteColor].CGColor, (id)[CGTATestAppColorList tealColor].CGColor];
    layer.frame = self.view.layer.bounds;
    [self.view.layer insertSublayer:layer atIndex:0];
    
    self.countryNameVisible = NO;
}

- (void)updateView;
{
    self.imageView.image = self.image;
    self.countryNameLabel.text = self.countryName;
    self.capitalNameLabel.text = [self capitalForCountryName:self.countryName];
}

- (IBAction)imageTapped:(UITapGestureRecognizer *)sender;
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self setCountryNameVisible:!self.countryNameVisible animated:YES];
    }
}

@end
