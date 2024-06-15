//
//  dovi.c
//
//
//  Created by kintan on 6/11/24.
//

#include <stdio.h>
#include <libavutil/display.h>
#include "dovi.h"
#define ARRAY_SIZE(s) (sizeof(s) / sizeof((s)[0]))

// Reshape data, grouped by component
struct dovi_reshape_data {
    float pivots[9]; // normalized to [0.0, 1.0] based on BL bit depth
    uint8_t num_pivots;
    uint8_t method[8]; // 0 = polynomial, 1 = MMR
                       // Note: these must be normalized (divide by coefficient_log2_denom)
    float poly_coeffs[8][3]; // x^0, x^1, x^2, unused must be 0
    uint8_t mmr_order[8]; // 1, 2 or 3
    float mmr_constant[8];
    float mmr_coeffs[8][3 /* order */][7];
};

void shader_dovi_reshape(const struct dovi_reshape_data *comp, struct reshape_data *out)
{
    if (!comp->num_pivots)
        return;
    // Prepare coefficients for GPU
    bool has_poly = false, has_mmr = false, mmr_single = true;
    int mmr_idx = 0, min_order = 3, max_order = 1;
    memset(out->coeffs_data, 0, sizeof(out->coeffs_data));
    for (int i = 0; i < comp->num_pivots - 1; i++) {
        switch (comp->method[i]) {
        case 0: // polynomial
            has_poly = true;
            out->coeffs_data[i][3] = 0.0; // order=0 signals polynomial
            for (int k = 0; k < 3; k++)
                out->coeffs_data[i][k] = comp->poly_coeffs[i][k];
            break;

        case 1:
            min_order = fmin(min_order, comp->mmr_order[i]);
            max_order = fmax(max_order, comp->mmr_order[i]);
            mmr_single = !has_mmr;
            has_mmr = true;
            out->coeffs_data[i][3] = (float) comp->mmr_order[i];
            out->coeffs_data[i][0] = comp->mmr_constant[i];
            out->coeffs_data[i][1] = (float) mmr_idx;
            for (int j = 0; j < comp->mmr_order[i]; j++) {
                // store weights per order as two packed vec4s
                float *mmr = &out->mmr_packed_data[mmr_idx][0];
                mmr[0] = comp->mmr_coeffs[i][j][0];
                mmr[1] = comp->mmr_coeffs[i][j][1];
                mmr[2] = comp->mmr_coeffs[i][j][2];
                mmr[3] = 0.0; // unused
                mmr[4] = comp->mmr_coeffs[i][j][3];
                mmr[5] = comp->mmr_coeffs[i][j][4];
                mmr[6] = comp->mmr_coeffs[i][j][5];
                mmr[7] = comp->mmr_coeffs[i][j][6];
                mmr_idx += 2;
            }
            break;
        }
    }

    if (comp->num_pivots > 2) {
        // Skip the (irrelevant) lower and upper bounds
        memcpy(out->pivots_data, comp->pivots + 1,
               (comp->num_pivots - 2) * sizeof(out->pivots_data[0]));

        // Fill the remainder with a quasi-infinite sentinel pivot
        for (int i = comp->num_pivots - 2; i < ARRAY_SIZE(out->pivots_data); i++)
            out->pivots_data[i] = 1e9f;
    }
    out->lo = comp->pivots[0];
    out->hi = comp->pivots[comp->num_pivots - 1];
    out->min_order = min_order;
    out->max_order = max_order;
    out->num_pivots = comp->num_pivots;
    out->has_poly = has_poly;
    out->has_mmr = has_mmr;
    out->mmr_single = mmr_single;
    return;
}


struct dovi_metadata* map_dovi_metadata(const AVDOVIMetadata *data)
{
    if (!data)
        return nil;
    const AVDOVIRpuDataHeader *header = av_dovi_get_header(data);
    const AVDOVIDataMapping *mapping  = av_dovi_get_mapping(data);
    const AVDOVIColorMetadata *color = av_dovi_get_color(data);
    struct dovi_metadata metadata = {0};
    struct dovi_metadata *out = &metadata;
    for (int i = 0; i < 3; i++) {
        out->nonlinear_offset[i] = - av_q2d(color->ycc_to_rgb_offset[i]);
        for (int j = 0; j < 3; j++) {
            out->nonlinear.columns[j][i] = av_q2d(color->ycc_to_rgb_matrix[i*3+j]);
            out->linear.columns[j][i] = av_q2d(color->rgb_to_lms_matrix[i*3+j]);
        }
    }
    out->minLuminance = color->source_min_pq;
    out->maxLuminance = color->source_max_pq;
    for (int c = 0; c < 3; c++) {
        const AVDOVIReshapingCurve *csrc = &mapping->curves[c];
        struct dovi_reshape_data cdst = {0};
        cdst.num_pivots = csrc->num_pivots;
        const float bl_scale = 1.0f / ((1 << header->bl_bit_depth) - 1);
        for (int i = 0; i < csrc->num_pivots; i++) {
            cdst.pivots[i] = bl_scale * csrc->pivots[i];
        }
        const float scale = 1.0f / (1 << header->coef_log2_denom);
        for (int i = 0; i < csrc->num_pivots - 1; i++) {
            cdst.method[i] = csrc->mapping_idc[i];
            switch (csrc->mapping_idc[i]) {
            case AV_DOVI_MAPPING_POLYNOMIAL:
                for (int k = 0; k < 3; k++) {
                    cdst.poly_coeffs[i][k] = (k <= csrc->poly_order[i])
                    ? scale * csrc->poly_coef[i][k]
                    : 0.0f;
                }
                break;
            case AV_DOVI_MAPPING_MMR:
                cdst.mmr_order[i] = csrc->mmr_order[i];
                cdst.mmr_constant[i] = scale * csrc->mmr_constant[i];
                for (int j = 0; j < csrc->mmr_order[i]; j++) {
                    for (int k = 0; k < 7; k++)
                        cdst.mmr_coeffs[i][j][k] = scale * csrc->mmr_coef[i][j][k];
                }
                break;
            }
        }
        shader_dovi_reshape(&cdst, &out->comp[c]);
    }
    return out;
}
