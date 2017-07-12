//
//  AmrFileWriter.m
//  SpeakHereAmr
//
//  Created by Yu Guangzhen on 13-7-15.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import "AmrFileWriter.h"

@implementation AmrFileWriter

- (id)initWithFileName:(NSString *)fileName
{
    self = [super init];
    if (self) {
        _fileName = [fileName retain];
    }
    return self;
}

- (void)dealloc
{
    [_fileName release];
    if (_file)
        [self closeFile];
    [super dealloc];
}

- (void)openFile {
    FILE * file = fopen([_fileName UTF8String], "a+");
    if (file) {
        _file = file;
    }
}

- (void)closeFile {
    if (_file)
        fclose((FILE*)_file);
    _file = NULL;
}

- (void)appendData:(NSData *)data {
    if ((_file == NULL) && _fileName)
        [self openFile];
    if (_file) {
        fseek((FILE*)_file, 0, SEEK_END);
        fwrite([data bytes], [data length], 1, (FILE *)_file);
    }
}

@end
