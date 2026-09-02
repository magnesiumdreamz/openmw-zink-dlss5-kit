// Minimal OpenMW/Zink depth diagnostic. Near geometry is dark; far geometry is bright.

#include "ReShade.fxh"

float4 OpenMW_ShowDepth(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float depth = ReShade::GetLinearizedDepth(texcoord);
    return float4(sqrt(saturate(depth)).xxx, 1.0);
}

technique OpenMW_DepthDiagnostic
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OpenMW_ShowDepth;
    }
}
