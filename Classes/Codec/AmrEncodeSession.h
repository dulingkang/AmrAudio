//
//  AmrEncodeSession.h
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-12.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#ifndef __SpeakHereAmr__AmrEncodeSession__
#define __SpeakHereAmr__AmrEncodeSession__

#include "AmrSessionCommon.h"

// At present, this class only for amrnb
class AmrEncodeSession : public AmrSessionCommon {
public:
    AmrEncodeSession(AmrCodecType codecType = amr_nb, int mode = AMRNB_MR74);
    ~AmrEncodeSession();
    
    /* 
     @param pcm             原始pcm数据
     @param out             编码后的amr数据
     @param pcmByteSize     原始pcm数据长度
     */
    int Encode(const short* pcm, unsigned char* out, unsigned int pcmByteSize);

private:
    void* mEncodeState;
    
    void *state;
};

#endif /* defined(__SpeakHereAmr__AmrEncodeSession__) */
