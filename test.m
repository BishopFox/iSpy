//
//  HCAppDelegate.m
//  HelloCBL
//
//  Created by Amy Kurtzman on 11/17/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "HCAppDelegate.h"

#import "couchbase-lite-ios/Source/API/CouchbaseLite.h"
#import "couchbase-lite-ios/Source/API/CBLDocument.h"

@interface HCAppDelegate ()

// shared manager
@property (strong, nonatomic) CBLManager *manager;

// the database
@property (strong, nonatomic) CBLDatabase *database;

// document identifier
@property (strong, nonatomic) NSString *docID;

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
    if (![self createTheDocument]) return NO;

    // retrieve a document from the database
    if (![self retrieveTheDocument]) return NO;
    
    // update a document
    if (![self updateTheDocument]) return NO;
    
    // delete a document
    if (![self deleteTheDocument]) return NO;
    
    return YES;
    
}


#pragma mark Manager and Database Methods

// creates the manager object
- (BOOL) createTheManager {
    
    // create a shared instance of CBLManager
    _manager = [CBLManager sharedInstance];
    if (!_manager) {
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
    _database = [_manager databaseNamed: dbname error: &error];
    if (!_database) {
        NSLog (@"Cannot create database. Error message: %@", error.localizedDescription);
        return NO;
    }
    
    // log the database location
    NSString *databaseLocation = @"CouchbaseLite"];
    NSLog(@"Database %@ created at %@", dbname, [NSString stringWithFormat:@"%@/%@%@", databaseLocation, dbname, @".cblite"]);
    
    return YES;
}


#pragma mark CRUD Methods


// creates the document
- (BOOL) createTheDocument {
    
    NSError *error;
    
    // create an object that contains data for the new document
    NSDictionary *myDictionary =
        @{@"message" : @"Hello Couchbase Lite!",
          @"name" : @"Joey",
          @"age" : @15,
          @"timestamp" : [[NSDate date] description]};
    
    // display the data for the new document
    NSLog(@"This is the data for the document: %@", myDictionary);
    
    // create an empty document
    CBLDocument* doc = [_database createDocument];
    
    // save the ID of the new document
    _docID = doc.documentID;
    
    // write the document to the database
    CBLRevision *newRevision = [doc putProperties: myDictionary error: &error];
    if (!newRevision) {
        NSLog (@"Cannot write document to database. Error message: %@", error.localizedDescription);
        return NO;
    }
    
    NSLog(@"Document created and written to database. ID = %@", _docID);

    return YES;
    
}


// retrieves the document
- (BOOL) retrieveTheDocument {
    
    // retrieve the document from the database
    CBLDocument *retrievedDoc = [_database documentWithID: _docID];
    
    // display the retrieved document
    NSLog(@"The retrieved document contains: %@", retrievedDoc.properties);
    
    return YES;
}


// updates the document
- (BOOL) updateTheDocument {
    
    NSError *error;

    // retrieve the document from the database
    CBLDocument *retrievedDoc = [_database documentWithID: _docID];

    // make a mutable copy of the properties from the document we just retrieved
    NSMutableDictionary *docContent = [retrievedDoc.properties mutableCopy];
    
    // modify the document properties
    [docContent setObject:@"Good Morning Couchbase Lite!!!" forKey:@"message"];
    [docContent setObject:@"breakfast" forKey:@"meal"];
    [docContent setObject:@"Green eggs and ham" forKey:@"entree"];
    [docContent setObject:@"burnt" forKey:@"toast"];
    
    // write the updated document to the database
    CBLSavedRevision *newRev = [retrievedDoc putProperties: docContent error: &error];
    if (!newRev) {
        NSLog (@"Cannot update document. Error message: %@", error.localizedDescription);
    }
    
    // display the new revision of the document
    NSLog (@"The new revision of the document contains: %@", newRev.properties);
    
    return YES;
    
}


// deletes the document
- (BOOL) deleteTheDocument {
    
    NSError *error;
    
    // retrieve the document from the database and then delete it
    if (![[_database documentWithID: _docID] deleteDocument: &error])
        NSLog (@"Cannot delete document. Error message: %@", error.localizedDescription);

    // verify the deletion by retrieving the document and checking whether it has been deleted
    CBLDocument *ddoc = [_database documentWithID: _docID];
    NSLog (@"The document with ID %@ is %@", _docID, ([ddoc isDeleted] ? @"deleted" : @"not deleted"));
    
    return YES;
    
}

@end

int main() {
    HCAppDelegate *h = [[HCAppDelegate alloc] init];
    [h startup];

}