//
//  AmrCodecType.h
//  SpeakHereAmr
//
//  Created by Yu Guangzhen on 13-7-14.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#ifndef SpeakHereAmr_AmrCodecType_h
#define SpeakHereAmr_AmrCodecType_h

typedef enum {
    amr_nb = 0,
    amr_wb = 1,  // opencore-amr没有实现amr_wb的编码
    amr_wb_plus = 3, // 编解码都不支持
} AmrCodecType;

// define by emun Mode mode.h
typedef enum {
	AMRNB_MODE_INVALID = -1,
	AMRNB_MR475 = 0,/* 4.75 kbps */
	AMRNB_MR515,    /* 5.15 kbps */
	AMRNB_MR59,     /* 5.90 kbps */
	AMRNB_MR67,     /* 6.70 kbps */
	AMRNB_MR74,     /* 7.40 kbps */
	AMRNB_MR795,    /* 7.95 kbps */
	AMRNB_MR102,    /* 10.2 kbps */
	AMRNB_MR122,    /* 12.2 kbps */
	AMRNB_MRDTX,    /* DTX       */
	AMRNB_N_MODES   /* number of mode, Not Use */
} AmrnbMode;

//#if AMR_WB_DECODE_SUPPORT
/*
 http://www.3gpp.org/ftp/Specs/html-info/26201.htm
 http://www.etsi.org/deliver/etsi_ts/126200_126299/126201/11.00.00_60/ts_126201v110000p.pdf
 */
typedef enum {
	AMRWB_MODE_INVALID = -1,
	AMRWB_MODE_66	= 0,	/*!< 6.60KBPS   */
	AMRWB_MODE_885	= 1,    /*!< 8.85KBPS   */
	AMRWB_MODE_1265	= 2,	/*!< 12.65KBPS  */
	AMRWB_MODE_1425	= 3,	/*!< 14.25KBPS  */
	AMRWB_MODE_1585	= 4,	/*!< 15.85BPS   */
	AMRWB_MODE_1825	= 5,	/*!< 18.25BPS   */
	AMRWB_MODE_1985	= 6,	/*!< 19.85KBPS  */
	AMRWB_MODE_2305	= 7,    /*!< 23.05KBPS  */
	AMRWB_MODE_2385 = 8,    /*!< 23.85KBPS> */
    AMRWB_N_MODES           /* number of mode, Not Use */
} AmrwbMode;
//#endif

#endif
