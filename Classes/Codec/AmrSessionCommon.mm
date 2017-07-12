//
//  AmrSessionCommon.cpp
//  SpeakHereAmr
//
//  Created by Yu Guangzhen on 13-7-14.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#include "AmrSessionCommon.h"
#include "AmrAudioConfig.h"

AmrSessionCommon::AmrSessionCommon(AmrCodecType codecType, int mode) : mCodecType(codecType), mMode(mode) {

}

AmrSessionCommon::~AmrSessionCommon() {

}

int AmrSessionCommon::ByteSizeOfOneFrame() {
    int byteSize = 0;
    static unsigned int static_amrnb_frame_map[AMRNB_N_MODES] = {
        // follow value is from 3GPP TS 26.101, tested http://www.3gpp.org/ftp/Specs/html-info/26101.htm
        // http://www.etsi.org/deliver/etsi_ts/126100_126199/126101/11.00.00_60/ts_126101v110000p.pdf
        13, // MR475
		14, // MR515
		16, // MR59
		18, // MR67
		20, // MR74
		21, // MR795
		27, // MR102
		32, // MR122
		0,  // DO NOT USE MRDTX
	};
#if AMR_WB_DECODE_SUPPORT
    static unsigned int static_amrwb_frame_size_map[AMRWB_N_MODES] = {
        // follow value is from 3GPP TS 26.201, not tested
        // http://www.3gpp.org/ftp/Specs/html-info/26201.htm
        18, // WBMR66,
        23, // WBMR885,
        33, // WBMR1265,
        37, // WBMR1425,
        41, // WBMR1585,
        47, // WBMR1825,
        51, // WBMR1985,
        59, // WBMR2305,
        61, // WBMR2385,
    };
    if (mCodecType == amr_nb) {
        byteSize = static_amrnb_frame_map[mMode];
    } else if(mCodecType == amr_wb) {
        byteSize = static_amrwb_frame_size_map[mMode];
    }
#else
	byteSize = static_amrnb_frame_map[mMode];
#endif //AMR_WB_DECODE_SUPPORT
    return byteSize;
}

int AmrSessionCommon::ByteSizeOfOneFrameAMRNB(AmrnbMode amrnbMode) {
    int byteSize = 0;
    ASSERT_IF_DEBUG(amrnbMode < AMRNB_N_MODES && amrnbMode > AMRNB_MODE_INVALID);
    static unsigned int static_amrnb_frame_map[AMRNB_N_MODES] = {
        // follow value is from 3GPP TS 26.101, tested http://www.3gpp.org/ftp/Specs/html-info/26101.htm
        // http://www.etsi.org/deliver/etsi_ts/126100_126199/126101/11.00.00_60/ts_126101v110000p.pdf
        13, // MR475
		14, // MR515
		16, // MR59
		18, // MR67
		20, // MR74
		21, // MR795
		27, // MR102
		32, // MR122
		0,  // DO NOT USE MRDTX
	};
	byteSize = static_amrnb_frame_map[amrnbMode];
    return byteSize;
}

int AmrSessionCommon::ByteSizeOfOneFrameAMRWB(AmrwbMode amrwbMode) {
    int byteSize = 0;
    static unsigned int static_amrwb_frame_size_map[AMRWB_N_MODES] = {
        // follow value is from 3GPP TS 26.201, not tested
        // http://www.3gpp.org/ftp/Specs/html-info/26201.htm
        18, // WBMR66,
        23, // WBMR885,
        33, // WBMR1265,
        37, // WBMR1425,
        41, // WBMR1585,
        47, // WBMR1825,
        51, // WBMR1985,
        59, // WBMR2305,
        61, // WBMR2385,
    };
    byteSize = static_amrwb_frame_size_map[amrwbMode];
    return byteSize;
}

int AmrSessionCommon::GetAmrByteSizeByPcmSize(int pcmByteSize) {
    int size = 0;
#if AMR_WB_DECODE_SUPPORT
    if (mCodecType == amr_nb) {
        size = pcmByteSize / AMR_NB_SAMPLE_BYTES_PER_FRAME * ByteSizeOfOneFrame();
    } else if(mCodecType == amr_wb) {
        size = pcmByteSize / AMR_WB_SAMPLE_BYTES_PER_FRAME * ByteSizeOfOneFrame();
    }
#else
    size = pcmByteSize / AMR_NB_SAMPLE_BYTES_PER_FRAME * ByteSizeOfOneFrame();
#endif
    return size;
}

int AmrSessionCommon::GetPcmByteSizeByAmrSize(int amrByteSize) {
    int size = 0;
#if AMR_WB_DECODE_SUPPORT
    if (mCodecType == amr_nb) {
        size = amrByteSize / ByteSizeOfOneFrame() * AMR_NB_SAMPLE_BYTES_PER_FRAME;
    } else if(mCodecType == amr_wb) {
        size = amrByteSize / ByteSizeOfOneFrame() * AMR_WB_SAMPLE_BYTES_PER_FRAME;
    }
#else
    size = amrByteSize / ByteSizeOfOneFrame() * AMR_NB_SAMPLE_BYTES_PER_FRAME;
#endif
    return size;
}
