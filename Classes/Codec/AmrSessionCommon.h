//
//  AmrSessionCommon.h
//  SpeakHereAmr
//
//  Created by Yu Guangzhen on 13-7-14.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#ifndef __SpeakHereAmr__AmrSessionCommon__
#define __SpeakHereAmr__AmrSessionCommon__

#include "AmrCodecDefine.h"
#include "AmrCodecType.h"

class AmrSessionCommon {
public:
    AmrSessionCommon(AmrCodecType codecType = amr_nb, int mode = AMRNB_MR74);
    ~AmrSessionCommon();

    AmrCodecType CodecType() { return mCodecType; };
    int Mode() { return mMode; };
    
    // 一帧amr数据的字节长度
    int ByteSizeOfOneFrame();
    static int ByteSizeOfOneFrameAMRNB(AmrnbMode amrnbMode);
    static int ByteSizeOfOneFrameAMRWB(AmrwbMode amrwbMode);
    /* 计算编码后的数据大小
     @param pcmByteSize     原始pcm数据长度
     @return                编码后的数据长度
     */
    int GetAmrByteSizeByPcmSize(int pcmByteSize);
    /* 计算解码后的数据大小
     @param amrByteSize     解码前amr数据长度
     @return                解码后的数据长度
     */
    int GetPcmByteSizeByAmrSize(int amrByteSize);
    
protected:
    AmrCodecType mCodecType;
    /*const*/ int mMode; // enum Mode or enum WBMode
};

#endif /* defined(__SpeakHereAmr__AmrSessionCommon__) */
