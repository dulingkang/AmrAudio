//
//  AmrFileReader.h
//  SpeakHereAmr
//
//  Created by Yu Guangzhen on 13-7-15.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AmrFileReader : NSObject {
    NSString *_fileName;
    void *_file;
}

- (id)initWithFileName:(NSString *) fileName;
- (void) openFile;
- (NSData*) getData:(int) length;
- (void) closeFile;

@end
