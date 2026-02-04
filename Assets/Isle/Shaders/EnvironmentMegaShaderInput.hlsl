#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

CBUFFER_START(UnityPerMaterial)
    half4 _Color;
    float4 _MainTex_ST;

    // Normal map
    float4 _BumpMap_ST;
    half _BumpMapScale;

    // Lightmap
    half _UseLightMap;

    // _USE_SHADOWMAP
    half4 _ShadowColor;

    // _USE_FRESNEL
    half4 _FresnelColor;
    half _FresnelPower;
    half _InvertedFresnel;

    // _USE_REFLECTION
    half4 _ReflectionColor;
    half _ReflectionMetallic;
    half _ReflectionIntensity;
    half _ReflectionFresnelPow;
    half _ReflectionRoughness;

    // _USE_REFLECTION_BOX_PROJECTION
    half4 _ProbePosition;
    half4 _ProbeBoxMin;
    half4 _ProbeBoxMax;
CBUFFER_END
