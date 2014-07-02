
#import <Foundation/Foundation.h>
#import <Foundation/NSFileManager.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIApplication.h>

#import "CouchbaseLite.framework/Headers/CouchbaseLite.h"
#import "CouchbaseLite.framework/Headers/CBLDocument.h"

@interface HCAppDelegate : NSObject

// shared manager
@property (retain, strong, nonatomic) CBLManager *manager;

// the database
@property (retain, strong, nonatomic) CBLDatabase *database;

// document identifier
@property (retain, strong, nonatomic) NSString *docID;

@end



@implementation HCAppDelegate

- (BOOL)startup
{
    // create a shared instance of CBLManager
    if (![self createTheManager]) return NO;
    
    // Create a database and demonstrate CRUD operations
    BOOL result = [self sayHello];
    NSLog (@"This Hello Couchbase Lite run was a %@!", (result ? @"total success" : @"dismal failure"));
    
    return YES;
}


/*
The sayHello method controls the tutorial app. It first creates a manager and a database
to store documents in. Next it creates and stores a new document. Then it uses the document that
was created to demonstrate the reaminaing CRUD operations by retrieving the document, 
updating the document, and deleting the document.
*/
- (BOOL) sayHello {
    
    // create a database
    if (![self createTheDatabase]) return NO;
    
    // create a new document & save it in the database
    if (![self createTheDocument:0]) return NO;

   
    return YES;
    
}


#pragma mark Manager and Database Methods

// creates the manager object
- (BOOL) createTheManager {
    
    // create a shared instance of CBLManager
    self.manager = [CBLManager sharedInstance];
    if (!self.manager) {
        NSLog (@"Cannot create shared instance of CBLManager");
        return NO;
    }
    
    NSLog (@"Manager created");
    
    return YES;
    
}


// creates the database
- (BOOL) createTheDatabase {
    
    NSError *error;
    
    // create a name for the database and make sure the name is legal
    NSString *dbname = @"my-new-database";
    if (![CBLManager isValidDatabaseName: dbname]) {
        NSLog (@"Bad database name");
        return NO;
    }
    
    // create a new database
    self.database = [_manager databaseNamed: dbname error: &error];
    if (!self.database) {
        NSLog (@"Cannot create database. Error message: %@", error.localizedDescription);
        return NO;
    }
    
    // log the database location
    NSString *databaseLocation = @"CouchbaseLite";
    NSLog(@"Database %@ created at %@", dbname, [NSString stringWithFormat:@"%@/%@%@", databaseLocation, dbname, @".cblite"]);
    
    return YES;
}



// creates the document
- (BOOL) createTheDocument:(int)num {
    
    NSError *error;
    
    // create an object that contains data for the new document
    NSDictionary *myDictionary =
        @{@"message" : @"Hello Couchbase Lite!",
          @"name" : @"Joey",
          @"age" : @15};
    
    // display the data for the new document
    //NSLog(@"This is the data for the document: %@", myDictionary);
    
    // create an empty document
    CBLDocument* doc = [_database createDocument];
    
    
    // write the document to the database
    CBLRevision *newRevision = [doc putProperties: myDictionary error: &error];
    if (!newRevision) {
        NSLog (@"Cannot write document to database. Error message: %@", error.localizedDescription);
        return NO;
    }
    
    //NSLog(@"Document created and written to database. ID = %@", doc.documentID);

    return YES;
    
}

@end

int main() {
    HCAppDelegate *h = [[HCAppDelegate alloc] init];
    FILE *fp;

    

    [h startup];

    NSLog(@"Writing 1000 couchdb entries...\n");
    for(int i = 0; i < 1000; i++) {
        //NSLog(@"%d\n", i);
        [h createTheDocument:i];
    }



}