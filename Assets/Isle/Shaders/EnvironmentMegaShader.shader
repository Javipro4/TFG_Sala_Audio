Shader "Spatial/Environment/EnvironmentMegaShader"
{
    Properties
    {
        [Header(BlendingMode)]
        [Enum(Opaque, 0, CutOut, 1, Transparent, 2)] _BlendingMode ("Blending Mode", int) = 0

        [Header(Main)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Main Color", Color) = (1, 1, 1, 1)

        [Header(Fresnel)]
        [Toggle(_USE_FRESNEL)] _UseFresnel ("Use Fresnel", int) = 0
        _FresnelPower ("Fresnel Power", Range(0, 2)) = 1
        _FresnelColor ("Fresnel Color", Color) = (1, 1, 1, 1)

        [Header(Reflection)]
        [Toggle(_USE_REFLECTION)] _UseReflection ("Use Reflection", int) = 0
        _ReflectionColor("Reflection Color", Color) = (1,1,1,1)
        _ReflectionMetallic("Reflection Metallic", Range(0,1)) = 1 // lerp(add,mix)
        _ReflectionIntensity("Reflection Intensity", Range(0,1)) = 1 // lerp(color,refl)
        _ReflectionFresnelPow("Reflection Fresnel Power", Float) = 1
        _ReflectionRoughness("Reflection Roughness", Range(0.0, 10.0)) = 0.0

        // Box Projection
        // Below values are temporal and unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax will be supported from URP ver 12.
        _ProbePosition("Probe Position", Vector) = (0,1,0,1)
        _ProbeBoxMin("Probe Box Min", Vector) = (-10, 0, -10, 0)
        _ProbeBoxMax("Probe Box Max", Vector) = (10, 10, 10, 0)

        // Only enabled when lighting model is set to lambertian
        [Header(Normal Map)]
        [Toggle(_USE_NORMALMAP)] _UseNormalMap ("Use Normal Map", int) = 0
        [Normal] _BumpMap ("Normal Map", 2D) = "white" {}
        _BumpMapScale ("Normal Map Scale", Range(0, 4)) = 0

        [Header(Light Map)]
        [Toggle(_USE_LIGHTMAP)] _UseLightMap ("Use Lightmap", int) = 0

        [Header(Shadow Map)]
        [Toggle(_USE_SHADOWMAP)] _UseShadowMap ("Use Shadowmap", int) = 0
        _ShadowColor ("Shadow Color", Color) = (0, 0, 0, 1)

        [Header(Blending State)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("SrcBlend", int) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("DstBlend", int) = 0

        [Header(Depth State)]
        [Toggle] _ZWrite ("ZWrite", int) = 1
    }
    SubShader
    {
        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Unlit" "IgnoreProjector" = "True"}

        Pass
        {
            Name "UniversalForward"
            Tags{"LightMode" = "UniversalForward"}

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Local keywords, assuming no runtime changes
            #pragma shader_feature_local _BLENDING_OPAQUE
            #pragma shader_feature_local _BLENDING_CUTOUT
            #pragma shader_feature_local _BLENDING_TRANSPARENT
            
            #pragma shader_feature_local _USE_FRESNEL
            #pragma shader_feature_local _USE_NORMALMAP
            #pragma shader_feature_local _USE_LIGHTMAP
            #pragma shader_feature_local _USE_SHADOWMAP

            #pragma shader_feature_local _ _USE_REFLECTION

            // Global keywords
            #pragma multi_compile __ MSAA_DISABLED
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #if defined(_USE_SHADOWMAP)
                #pragma multi_compile_fwdadd_fullshadows
            #endif

            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1; // lightmap uv
                #if defined(_USE_FRESNEL)|| defined(_USE_REFLECTION) || defined(_USE_NORMALMAP)
                    half3 normal : NORMAL;
                #endif
                #if defined(_USE_NORMALMAP)
                    half4 tangent : TANGENT;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 uv : TEXCOORD0;
                #if defined(_USE_FRESNEL) || defined(_USE_REFLECTION) || defined(_USE_NORMALMAP)
                    half3 worldNormal : TEXCOORD1;
                #endif
                #if defined(_USE_FRESNEL) || defined(_USE_REFLECTION)
                    float3 positionWS : TEXCOORD2;
                #endif
                #if defined(_USE_NORMALMAP)
                    half3 worldTangent : TEXCOORD3;
                    half3 worldBinormal : TEXCOORD4;
                    float2 uvNormalMap : TEXCOORD5;
                #endif
                #if defined(_USE_SHADOWMAP)
                    float4 shadowCoord : TEXCOORD6;
                #endif
                float fogCoord : TEXCOORD7;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            #if defined(_USE_NORMALMAP)
                TEXTURE2D(_BumpMap);
                SAMPLER(sampler_BumpMap);
            #endif


            // CBUFFER size should be the same between different passes so split 
            #include "EnvironmentMegaShaderInput.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = vertexInput.positionCS;

                float2 lightmapUV = 0.0;
                #if defined(_USE_LIGHTMAP)
                    lightmapUV = mad(v.uv2, unity_LightmapST.xy, unity_LightmapST.zw);
                #endif
                o.uv = float4(TRANSFORM_TEX(v.uv, _MainTex), lightmapUV);

                #if defined(_USE_FRESNEL) || defined(_USE_REFLECTION) || defined(_USE_NORMALMAP)
                    o.worldNormal = normalize(TransformObjectToWorldNormal(v.normal));
                #endif

                #if defined(_USE_FRESNEL) || defined(_USE_REFLECTION)
                    o.positionWS = vertexInput.positionWS;
                #endif
                #if defined(_USE_NORMALMAP)
                    o.worldTangent = normalize(mul((float3x3)unity_ObjectToWorld, v.tangent.xyz));
                    o.worldBinormal = cross(o.worldNormal, o.worldTangent) * v.tangent.w;
                    o.uvNormalMap = TRANSFORM_TEX(v.uv, _BumpMap);
                #endif

                #if defined(_USE_SHADOWMAP)
                    o.shadowCoord = TransformWorldToShadowCoord(vertexInput.positionWS);
                #endif

                o.fogCoord = ComputeFogFactor(o.vertex.z);

                return o;
            }

            // from GlobalIllumination.hlsl - BoxProjectedCubemapDirection (URP ver. 12.1.3 or later)
            float3 BoxProjectedCubemapDirectionCopied(float3 reflectionWS, float3 positionWS, float4 cubemapPositionWS, float4 boxMin, float4 boxMax)
            {
                float3 boxMinMax = (reflectionWS > 0.0f) ? boxMax.xyz : boxMin.xyz;
                half3 rbMinMax = half3(boxMinMax - positionWS) / reflectionWS;

                half fa = half(min(min(rbMinMax.x, rbMinMax.y), rbMinMax.z));

                float3 worldPos = half3(positionWS - cubemapPositionWS.xyz);

                return worldPos + reflectionWS * fa;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
                col.rgb *= _Color.rgb;
                col.a = saturate(col.a * _Color.a);

                #if defined(_BLENDING_CUTOUT)
                    clip (col.a - 0.5);
                #endif

                #if defined(_USE_FRESNEL) || defined(_USE_REFLECTION)
                    #if defined(_USE_NORMALMAP)
                        half3 tangentNormal = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv.xy), _BumpMapScale);
                        // Swapping YZ components of tangent normal addressed in the matrix compute below
                        half3 worldNormal = 
                        tangentNormal.x * i.worldTangent +
                        tangentNormal.y * i.worldBinormal +
                        tangentNormal.z * i.worldNormal;
                    #else
                        half3 worldNormal = i.worldNormal;
                    #endif
                #endif

                #if defined(_USE_FRESNEL) || defined(_USE_REFLECTION)
                    float3 worldViewDir = GetWorldSpaceNormalizeViewDir(i.positionWS);
                #endif

                #if defined(_USE_FRESNEL)
                    half nv = dot(worldViewDir, worldNormal);
                    half fresnel = saturate(1. - nv);
                    fresnel = pow(fresnel, _FresnelPower);

                    col = lerp(col, _FresnelColor, fresnel);
                #endif

                half3 lightmap = (half3) 1.0;
                #if defined(_USE_LIGHTMAP)
                    real4 encodedIlluminance = SAMPLE_TEXTURE2D_LIGHTMAP(unity_Lightmap, samplerunity_Lightmap, i.uv.zw).rgba;
                    half4 decodeInstructions = half4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0h, 0.0h);
                    lightmap = DecodeLightmap(encodedIlluminance, decodeInstructions);
                    col.rgb *= lightmap;
                #endif

                #if defined(_USE_SHADOWMAP)
                    ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
                    half4 shadowParams = GetMainLightShadowParams();
                    half shadow = SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), i.shadowCoord, shadowSamplingData, shadowParams, false);
                    col.rgb = lerp(col.rgb * _ShadowColor.rgb, col.rgb, shadow);
                #endif

                #if defined(_USE_REFLECTION)
                    float3 worldRefl = reflect(-worldViewDir, worldNormal);
                    // Reflection Probe Box Projection.
                    // https://community.arm.com/arm-community-blogs/b/graphics-gaming-and-vr-blog/posts/reflections-based-on-local-cubemaps-in-unity
                    // Box Projection and unity_SpecCube0_ProbePosition are supported from URP ver. 12.1.3 or later.
                    // So use manual value for now.
                    // worldRefl = BoxProjectedCubemapDirectionCopied(worldRefl, i.positionWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
                    worldRefl = BoxProjectedCubemapDirectionCopied(worldRefl, i.positionWS, _ProbePosition, _ProbeBoxMin, _ProbeBoxMax);
                    half4 skyData = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, worldRefl, _ReflectionRoughness);
                    half3 skyColor = DecodeHDREnvironment(skyData, unity_SpecCube0_HDR) * _ReflectionColor.rgb;
                    skyColor.rgb *= _ReflectionColor.rgb;
                    half3 refl = lerp(col.rgb + skyColor, skyColor, _ReflectionMetallic);

                    #if !defined(_USE_FRESNEL)
                        half nv = dot(worldViewDir, worldNormal);
                        half fresnel;
                    #endif
                    fresnel = pow(max(1-nv, 0), _ReflectionFresnelPow);

                    half reflIntensity = _ReflectionIntensity * saturate(fresnel+_ReflectionMetallic);
                    // if(_UseLightMap){
                        // reflIntensity *= saturate(lightmap * lightmap);
                        // reflIntensity *= saturate(lightmap+_ReflectionMetallic);
                    // }
                    col.rgb = lerp(col.rgb, refl, reflIntensity);
                #endif

                col.rgb = MixFog(col.rgb, i.fogCoord);
                return col;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "./EnvironmentMegaShaderInput.hlsl"

            /////////////////////////////////////////////////////////////////////////////////////////////////////////         
            // Below is copied from "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            /////////////////////////////////////////////////////////////////////////////////////////////////////////
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionCS   : SV_POSITION;
            };

            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                return positionCS;
            }

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);

                output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.positionCS = GetShadowPositionHClip(input);
                return output;
            }

            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                // Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                return 0;
            }
            ENDHLSL
        }

    }
    FallBack "VertexLit"
}
