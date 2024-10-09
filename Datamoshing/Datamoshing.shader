Shader "Hidden/Shader/Datamoshing"
{
    Properties
    {
		// This property is necessary to make the CommandBuffer.Blit bind the source texture to _MainTex
        _MainTex("", 2DArray) = ""{}
        _WorkTex("", 2D) = ""{}
        _DispTex("", 2D) = ""{}
    }

	HLSLINCLUDE

	#pragma target 4.5
	#pragma only_renderers d3d11 vulkan metal

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/FXAA.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/PostProcessDefines.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/RTUpscale.hlsl"

    TEXTURE2D_X(_MainTex);
    TEXTURE2D(_WorkTex);
    TEXTURE2D(_DispTex);
    SAMPLER(sampler_MainTex);
    SAMPLER(sampler_WorkTex);
    SAMPLER(sampler_DispTex);
    SAMPLER(sampler_CameraMotionVectorsTexture);


    float _BlockSize;
    float _Quality;
    float _Velocity;
    float _Diffusion;

	struct Attributes
	{
		uint vertexID : SV_VertexID;
	};
    // Vertex shader for multi texturing
    struct Varyings
    {
        float4 pos : SV_POSITION;
        float2 uv0 : TEXCOORD0;
        float2 uv1 : TEXCOORD1;
    };

    Varyings Vert(Attributes v)
    {
        Varyings o;
        o.pos = GetFullScreenTriangleVertexPosition(v.vertexID);
        o.uv0 = GetFullScreenTriangleTexCoord(v.vertexID);
        o.uv1 = GetFullScreenTriangleTexCoord(v.vertexID);
        return o;
    }

    // PRNG
    float UVRandom(float2 uv)
    {
        float f = dot(float2(12.9898, 78.233), uv);
        return frac(43758.5453 * sin(f));
    }

    // Initialization shader
    float4 frag_init(Varyings i) : SV_Target
    {
        return 0;
    }

    // Displacement buffer updating shader
    float4 frag_update(Varyings i) : SV_Target
    {
        float2 uv = i.uv0;
        float2 t0 = float2(_Time.y, 0);
        float3 rand = float3(UVRandom(uv + t0.xy), UVRandom(uv + t0.yx), UVRandom(uv.yx - t0.xx));

        // Motion vector
        float2 mv = SAMPLE_TEXTURE2D_X(_CameraMotionVectorsTexture, sampler_CameraMotionVectorsTexture, uv).rg;
        mv *= _Velocity;
        // Normalized screen space -> Pixel coordinates
        mv = mv * _ScreenParams.xy;
        // Small random displacement (diffusion)
        mv += (rand.xy - 0.5) * _Diffusion;
        // Pixel perfect snapping
        mv = round(mv);

        // Accumulates the amount of motion.
        float acc = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, i.uv0).a;
        float mv_len = length(mv);
        float acc_update = acc + min(mv_len, _BlockSize) * 0.005;
        acc_update += rand.z * lerp(-0.02, 0.02, _Quality);
        float acc_reset = rand.z * 0.5 + _Quality;
        // - Reset if the amount of motion is larger than the block size.
        acc = saturate(mv_len > _BlockSize ? acc_reset : acc_update);

        // Pixel coordinates -> Normalized screen space
        mv *= (_ScreenParams.zw - 1);

        // Random number (changing by motion)
        float mrand = UVRandom(uv + mv_len);

        return float4(mv, mrand, acc);
    }

    // Moshing shader
    float4 frag_mosh(Varyings i) : SV_Target
    {
        float4 src = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, i.uv1);
        float4 disp = SAMPLE_TEXTURE2D(_DispTex, sampler_DispTex, i.uv0);
        float3 work = SAMPLE_TEXTURE2D(_WorkTex, sampler_WorkTex, i.uv1 - disp.xy * 0.98).rgb;
        return float4(lerp(work, src.rgb, 0.4), src.a);
    }

    ENDHLSL

    SubShader
    {
		ZWrite Off ZTest Always Blend Off Cull Off

        Pass
        {
			HLSLPROGRAM
			#pragma vertex Vert
            #pragma fragment frag_init
			ENDHLSL
        }

        Pass
        {
			HLSLPROGRAM
			#pragma vertex Vert
            #pragma fragment frag_update
			ENDHLSL
        }

        Pass
        {
			HLSLPROGRAM
			#pragma vertex Vert
            #pragma fragment frag_mosh
			ENDHLSL
        }
    }
	Fallback Off
}