//
//  AmrFileWriter.h
//  SpeakHereAmr
//
//  Created by Yu Guangzhen on 13-7-15.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AmrFileWriter : NSObject {
    NSString *_fileName;
    void *_file;
}

//向文件中写
- (id)initWithFileName:(NSString *) fileName;
- (void) openFile;
- (void) appendData:(NSData *) data;
- (void) closeFile;

@end
