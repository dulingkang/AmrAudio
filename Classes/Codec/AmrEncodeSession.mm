//
//  AmrEncodeSession.cpp
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-12.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#include "AmrEncodeSession.h"
#include "interf_enc.h"
#include <iostream>

AmrEncodeSession::AmrEncodeSession(AmrCodecType codecType, int mode) {
    
    mEncodeState = Encoder_Interface_init(0);
}

AmrEncodeSession::~AmrEncodeSession() {
    if (state != NULL) {
        Encoder_Interface_exit(state);
        state = NULL;
    }
    Encoder_Interface_exit(mEncodeState);
}

int AmrEncodeSession::Encode(const short *pcm, unsigned char *out, unsigned int pcmByteSize) {
    // LOG_IF_DEBUG("Encode pcmByteSize: %d", pcmByteSize);
    int encoder_frames = pcmByteSize / AMR_NB_SAMPLE_BYTES_PER_FRAME;
	const short* p0 = pcm;
	unsigned char* p1 = out;
	int actual_byte_size = 0;
    // int count = 0;
	for( int i = 0; i < encoder_frames; i++ )
	{
		int result = Encoder_Interface_Encode(mEncodeState, (enum Mode)mMode, p0, p1, 0 );
		p0 += 160; // p0移到下一帧的源数据头，计算依据：一帧amr-nb数据代表160个采样，每个采样占2字节，所以移动320个字节，即160个short.(AMR_NB_SAMPLE_BYTES_PER_FRAME/sizeof(short))
		p1 += result;
		actual_byte_size += result;

        // count++;
        // printf("andy:AmrEncodeSession::Encode rst = %d, count = %d\n", rst, count);
    }
    
	return actual_byte_size;
}
