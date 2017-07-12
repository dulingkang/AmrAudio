//
//  AmrDecodeSession.cpp
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-12.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#include "AmrDecodeSession.h"
#include <assert.h>
#include <iostream>
//#include "dec_if.h"
#include "interf_dec.h"
#include "AmrAudioConfig.h"

AmrDecodeSession::AmrDecodeSession(AmrCodecType codecType, int mode) {
    int upper = 0;
    if (mCodecType == amr_nb) {
        upper = AMRNB_N_MODES - 1;
    } else if (mCodecType == amr_wb) {
        upper = AMRWB_N_MODES - 1;
    }
    if (mode > upper || mode < 0) {
        mMode = 0;
        LOG_IF_DEBUG("ERROR: mode %d is not support", mode);
        ASSERT_IF_DEBUG(0);
    }
    
#if AMR_WB_DECODE_SUPPORT
    if (mCodecType == amr_nb) {
        mDecodeState = Decoder_Interface_init();
    } else if (mCodecType == amr_wb) {
        mDecodeState = D_IF_init();
    }
#else
    mDecodeState = Decoder_Interface_init();
#endif //AMR_WB_DECODE_SUPPORT
}

AmrDecodeSession::~AmrDecodeSession() {
#if AMR_WB_DECODE_SUPPORT
    if (mCodecType == amr_nb) {
        Decoder_Interface_exit(mDecodeState);
    } else if (mCodecType == amr_wb) {
        D_IF_exit(mDecodeState);
    }
#else
    Decoder_Interface_exit(mDecodeState);
#endif //AMR_WB_DECODE_SUPPORT
}

int AmrDecodeSession::Decode(const unsigned char *amr, short *out, unsigned int amrByteSize) {
    LOG_IF_DEBUG("Decode amrByteSize: %d", amrByteSize);
    int decode_frames = amrByteSize / ByteSizeOfOneFrame();
    const unsigned char* p0 = amr;
    short* p1 = out;
    for (int i = 0; i < decode_frames; i++) {
#if AMR_WB_DECODE_SUPPORT
        if (mCodecType == amr_nb) {
            Decoder_Interface_Decode(mDecodeState, p0, p1, 0);
            p1 += 160;
        } else if (mCodecType == amr_wb) {
            D_IF_decode(mDecodeState, p0, p1, 0);
            p1 += 320;
        }
#else
        Decoder_Interface_Decode(mDecodeState, p0, p1, 0);
        p1 += 160;
#endif
        p0 += ByteSizeOfOneFrame();
		//p1 += 160; // p0移到下一帧的源数据头，计算依据：一帧amr-nb数据代表160个采样，每个采样占2字节，所以移动320个字节，即160个short.(AMR_NB_SAMPLE_BYTES_PER_FRAME/sizeof(short))

    }
    return GetPcmByteSizeByAmrSize(amrByteSize);
}
