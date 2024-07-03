#ifndef AVCODEC_SHIM_H
#define AVCODEC_SHIM_H

#import <Libavcodec/avcodec.h>
CFDataRef ff_videotoolbox_avcc_extradata_create(AVCodecContext *avctx);
CFDataRef ff_videotoolbox_hvcc_extradata_create(AVCodecContext *avctx);
CFDataRef ff_videotoolbox_vpcc_extradata_create(AVCodecContext *avctx);

#endif /* AVCODEC_SHIM_H */
