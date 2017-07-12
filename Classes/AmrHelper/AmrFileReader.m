//
//  AmrFileReader.m
//  SpeakHereAmr
//
//  Created by Yu Guangzhen on 13-7-15.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import "AmrFileReader.h"

@implementation AmrFileReader

- (id)initWithFileName:(NSString *)fileName
{
    self = [super init];
    if (self) {
        _fileName = [fileName retain];
    }
    return self;
}

- (void)openFile {
    FILE * file = fopen([_fileName UTF8String], "rb+");
    if (file) {
        _file = file;
    }
}

- (void)closeFile {
    if (_file)
        fclose((FILE*)_file);
    _file = NULL;
}

- (NSData *)getData:(int)length {
    if ((_file == NULL) && _fileName)
        [self openFile];
    uint8_t * pData = (uint8_t*)malloc(length);
    fread(pData, length, 1, (FILE*)_file);
    NSData *data = [[NSData alloc] initWithBytes:pData length:length];
    free(pData);
    return [data autorelease];
}

- (void)dealloc
{

    [super dealloc];
}

@end

