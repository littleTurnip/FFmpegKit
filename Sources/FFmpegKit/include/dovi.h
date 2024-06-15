//
//  dovi.h
//
//
//  Created by kintan on 6/11/24.
//

#ifndef dovi_h
#define dovi_h
#include <stdbool.h>
#include <stdint.h>
#include <Libavutil/dovi_meta.h>
#include <simd/types.h>

// Parsed metadata from the Dolby Vision RPU
struct dovi_metadata {
    // Colorspace transformation metadata
    simd_float3x3 nonlinear;     // before PQ, also called "ycc_to_rgb"
    simd_float3x3 linear;        // after PQ, also called "rgb_to_lms"
    simd_float3 nonlinear_offset;  // input offset ("ycc_to_rgb_offset")
    float minLuminance;
    float maxLuminance;
    struct reshape_data {
        simd_float4 coeffs[8];
        simd_float4 mmr[8*6];
        float pivots[7];
        float lo;
        float hi;
        uint8_t min_order;
        uint8_t max_order;
        uint8_t num_pivots;
        bool has_poly;
        bool has_mmr;
        bool mmr_single;
    } comp[3];
};

struct dovi_metadata* map_dovi_metadata(const AVDOVIMetadata *data);
#endif /* dovi_h */
