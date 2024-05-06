//
//  renderer.c
//  
//
//  Created by kintan on 5/5/24.
//

#include <stdio.h>
#include <libplacebo/vulkan.h>
static int create_vk_by_placebo() {
    pl_vk_inst inst = pl_vk_inst_create(NULL, pl_vk_inst_params(
                                                                 .extensions = (const char *[]){
                                                                     VK_KHR_DISPLAY_EXTENSION_NAME,
                                                                 },
                                                                 .num_extensions = 1,
                                                                 ));
}
