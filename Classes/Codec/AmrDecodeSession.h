//
//  AmrDecodeSession.h
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-12.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#ifndef __SpeakHereAmr__AmrDecodeSession__
#define __SpeakHereAmr__AmrDecodeSession__

#include "AmrSessionCommon.h"

class AmrDecodeSession : public AmrSessionCommon {
public:
    /* 
     @param codecType   amr codec type amr_nb or amr_wb
     @param mode        when codecType is amr_nb, mode must be enum Mode
                        when codecType is amr_wb, mode must be enum WBMode
    */
    AmrDecodeSession(AmrCodecType codecType = amr_nb, int mode = AMRNB_MR74);
    ~AmrDecodeSession();

    /*
     @param amr         amr数据
     @param out         解码后的pcm数据
     @param amrLength   amr数据的长度
     @return            解码后的数据长度
    */
    int Decode(const unsigned char* amr, short* out, unsigned int amrByteSize);

private:
    void* mDecodeState;
};

#endif /* defined(__SpeakHereAmr__AmrDecodeSession__) */
