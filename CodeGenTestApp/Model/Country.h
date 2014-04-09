#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Country : NSManagedObject

@property (nonatomic, retain) NSString * capital;
@property (nonatomic, retain) NSString * name;

@end
