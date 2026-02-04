Shader "Spatial/Environment/IsleGalleryVariants"
{
    Properties
    {
        _BaseColor ("Base color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}

        [Header(Variant Setting)]
        [Toggle] _UseVariant ("Use Variant", Int) = 0
        _VariantMask ("Variant Mask", 2D) = "black" {}
        [Enum(red,0,green,1,blue,2)] _MaskChannelSelector("Mask Channel Selector", Int) = 0
        [Enum(uv1,0,uv2,1)] _UVChannelSelector("UV Channel Selector", Int) = 0
        _VariantColor ("Variant color (Overlay)", Color) = (1,1,1,1)
        _VariantTex ("Variant Texture (Overlay)", 2D) = "white" {}

        [Toggle] _AdjustColorToRest ("Adjust color to the rest", Int) = 0
        _VariantColor2 ("Variant color 2 (Overlay)", Color) = (0.5,0.5,0.5,1)

        [Header(Reflection)]
        [Toggle(_USE_REFLECTION)] _UseReflection ("Use Reflection", Int) = 0
        _ReflectionIntensity ("Reflection Intensity", Range(0,1)) = 1
        _ReflectionRoughness ("Reflection Roughness", Float) = 0
        _ReflectionColor ("Reflection Color", Color) = (1,1,1,1)
        _ReflectionFresnelPow ("Reflection Fresnel Pow", Float) = 1

        [Header(Shadow Map)]
        [Toggle(_USE_SHADOWMAP)] _UseShadowMap ("Use Shadowmap", int) = 0
        _ShadowColor ("Shadow Color", Color) = (0, 0, 0, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "UniversalForward"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #pragma shader_feature_local _USE_REFLECTION
            #pragma shader_feature_local _USE_SHADOWMAP
            #if defined(_USE_SHADOWMAP)
                #pragma multi_compile_fwdadd_fullshadows
            #endif

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                #if defined(_USE_PARALLAX_OCCLUSION) || defined(_USE_REFLECTION)
                    float3 normal : NORMAL;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varying
            {
                float4 positionHCS : SV_POSITION;
                float4 uv : TEXCOORD0;
                float2 uvTile : TEXCOORD1;
                #if defined(_USE_REFLECTION)
                    float3 positionWS : TEXCOORD3;
                    float3 normalWS : TEXCOORD4;
                #endif
                float fogCoord : TEXCOORD5;
                #if defined(_USE_SHADOWMAP)
                    float4 shadowCoord : TEXCOORD6;
                #endif
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_VariantMask);
            SAMPLER(sampler_VariantMask);
            TEXTURE2D(_VariantTex);
            SAMPLER(sampler_VariantTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                half4 _BaseColor;

                int _UseVariant;
                int _MaskChannelSelector;
                int _UVChannelSelector;
                float4 _VariantTex_ST;
                half4 _VariantColor;

                int _AdjustColorToRest;
                half4 _VariantColor2;

                // #if defined(_USE_REFLECTION)
                half _ReflectionIntensity;
                half _ReflectionRoughness;
                half4 _ReflectionColor;
                half _ReflectionFresnelPow;
                // #endif

                half4 _ShadowColor;
            CBUFFER_END

            Varying vert (Attributes IN)
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                Varying OUT = (Varying)0;
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv.xy = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.uv.zw = TRANSFORM_TEX((_UVChannelSelector == 0) ? IN.uv : IN.uv2, _MainTex);
                OUT.uvTile = TRANSFORM_TEX((_UVChannelSelector == 0) ? IN.uv : IN.uv2, _VariantTex);

                #if defined(_USE_REFLECTION) || defined(_USE_SHADOWMAP)
                    float3 positionWS = mul(unity_ObjectToWorld, IN.positionOS).xyz;
                #endif

                #if defined(_USE_REFLECTION)
                    OUT.positionWS = positionWS;
                    OUT.normalWS = TransformObjectToWorldNormal(IN.normal);
                #endif

                OUT.fogCoord = ComputeFogFactor(OUT.positionHCS.z);
                #if defined(_USE_SHADOWMAP)
                    OUT.shadowCoord = TransformWorldToShadowCoord(positionWS);
                #endif
                return OUT;
            }

            half4 frag (Varying IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv.xy) * _BaseColor;
                if(_UseVariant)
                {
                    half4 variantMask = SAMPLE_TEXTURE2D(_VariantMask, sampler_VariantMask, IN.uv.zw);
                    half mask = variantMask.r;
                    if(_MaskChannelSelector == 1)
                    {
                        mask = variantMask.g;
                    }
                    else if(_MaskChannelSelector == 2)
                    {
                        mask = variantMask.b;
                    }

                    half4 variantTex = SAMPLE_TEXTURE2D(_VariantTex, sampler_VariantTex, IN.uvTile) * _VariantColor;
                    // color.rgb = lerp(color.rgb, color.rgb * variantTex.rgb, mask); // Multiply
                    half3 overlay = (variantTex.rgb > 0.5) * (1-(1-2*(variantTex.rgb-0.5)) * (1-color.rgb)) + (variantTex.rgb <= 0.5) * ((2*variantTex.rgb) * color.rgb);
                    
                    #if defined(_USE_REFLECTION)
                        float3 worldViewDir = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                        float3 worldNormal = normalize(IN.normalWS);
                        float3 worldRefl = normalize(reflect(-worldViewDir, worldNormal));

                        half4 skyData = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, worldRefl, _ReflectionRoughness);
                        half3 skyColor = DecodeHDREnvironment(skyData, unity_SpecCube0_HDR) * _ReflectionColor.rgb;

                        half nv = dot(worldViewDir, worldNormal);
                        half fresnel = pow(max(1-nv, 0), _ReflectionFresnelPow);
                        half reflIntensity = _ReflectionIntensity * fresnel;

                        overlay.rgb = lerp(overlay.rgb, overlay.rgb + skyColor.rgb, reflIntensity);
                    #endif

                    if(!_AdjustColorToRest)
                    {
                        color.rgb = lerp(color.rgb, overlay, mask);
                    }
                    else
                    {
                        half3 overlay2 = (_VariantColor2.rgb > 0.5) * (1-(1-2*(_VariantColor2.rgb-0.5)) * (1-color.rgb)) + (_VariantColor2.rgb <= 0.5) * ((2*_VariantColor2.rgb) * color.rgb);
                        color.rgb = lerp(overlay2, overlay, mask);
                    }
                }

                #if defined(_USE_SHADOWMAP)
                    ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
                    half4 shadowParams = GetMainLightShadowParams();
                    half shadow = SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), IN.shadowCoord, shadowSamplingData, shadowParams, false);
                    color.rgb = lerp(color.rgb * _ShadowColor.rgb, color.rgb, shadow);
                #endif
                color.rgb = MixFog(color.rgb, IN.fogCoord);
                return color;
            }
            ENDHLSL
        }
    }
}
