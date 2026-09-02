// Preserve the completed game image while preventing OpenMW framebuffer alpha
// from becoming Windows desktop transparency through Zink's premultiplied swapchain.

#include "ReShade.fxh"

texture OpenMW_BackBuffer : COLOR;

sampler OpenMW_BackBufferSampler
{
    Texture = OpenMW_BackBuffer;
};

float4 OpenMW_ForceOpaque(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float4 color = tex2D(OpenMW_BackBufferSampler, texcoord);
    return float4(color.rgb, 1.0);
}

technique OpenMW_OpaquePresent
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OpenMW_ForceOpaque;
    }
}
