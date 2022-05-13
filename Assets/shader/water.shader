Shader "Unlit/water"
{
   Properties
	{   
        [Header(Tessellation)]
        _Tess("Tessellation", Range(1, 64)) = 20
		_MaxTessDistance("Max Tess Distance", Range(1, 64)) = 20
		
		[Header(Vertexwave)]
		_amp ("Amplitude",Range(0,1)) = 0.1
		_freq ("frequency",Range(0,50)) = 0.1
		_fi ("phase",Range(0,10)) = 0.1
		
        [Header(Colors)]
        _DepthColor("Depth Color", Color) = (1,1,1,1)
        _ShallowColor("Shallow Color", Color) = (1,1,1,1)
		_Metallic("Mettallic", Range(0,1)) = 0.5
		_Smoothness("Smoothness", Range(0,1)) = 0.9
		_LUT("LUT", 2D) = "white" {}

		[Header(Thresholds)]
		_FoamThreshold("Foam threshold", float) = 0
        _WaterDepth("WaterDepth",float) = 1.2

		[Header(Foam)]
		[HDR] _FoamColor("Foam color", Color) = (1,1,1)
        _FoamTexture("Foam texture", 2D) = "white" {} 
        _FoamTextureSpeedX("Foam texture speed X", float) = 0
        _FoamTextureSpeedY("Foam texture speed Y", float) = 0
        _FoamLinesSpeed("Foam lines speed", float) = 0

		[Header(Normal maps)]
        [Normal]_NormalMap("Normal", 2D) = "bump" {} 
        _UVScale("UVScale",Vector) = (0,0,0,0)
        _DetailScale("DetailScale",float) = 5
        _ScrollSpeed("ScrollSpeed",float) = 0.69
        _DetailStrength("DetailStrength", Range(0,1)) = 0.29
        _BumpStrength("BumpStrength",float) = 0.32

		[Header(Refraction)]
		_causticIntense("caustic Intense", Range(0,50)) = 1
		_causticTint("caustic Tint", Range(0,0.5)) = 0.1
        _distortIntensityrefra("refraction DistortIntensity",Range(0,10)) =0.1
		_distortIntensityrefle("reflection DistortIntensity",Range(0,10)) =0.1


		[Header(sss)]
		_Distortsss ("back Distortion",Range(0,1)) = 0.1
		_Powersss("Back Power",Range(0,10)) = 0.1
		_Scalesss("Back Scale",Range(0,1)) = 0.1
		_sssColor("sss color", Color) = (1,1,1)

		[Header(Shadow)]
		_ShadowColor ("Shadow Color", Color) = (0.35,0.4,0.45,1.0)

		[Toggle(UNDERWATER_LUMINANCE)]
		_luminance("luminance", Range(0,1)) = 0
		_luminanceThreshold("luminance threshold", Range(0,5)) = 0

		[KeywordEnum(Off, Refraction, Reflection, Normal, Fresnel, WaterEffects, WaterDepth, Luminance,scenepos)] _Debug ("Debug mode", Float) = 0
	}

		// The SubShader block containing the Shader code. 
	SubShader
	{
		Tags{ "Queue" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" }

	Pass
	{
		Tags{ "LightMode" = "UniversalForward" }

		HLSLPROGRAM
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"   
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
#include "Tessellationvariables.hlsl"
#include "WaterInput.hlsl"
#include "WaterUtilities.hlsl"
#include "WaterLighting.hlsl"

#pragma prefer_hlslcc gles
#pragma exclude_renderers d3d11_9x
#pragma target 2.0
#pragma shader_feature UNDERWATER_LUMINANCE


#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#pragma multi_compile _ _SHADOWS_SOFT
#pragma multi_compile_fog
#pragma shader_feature _DEBUG_OFF _DEBUG_REFRACTION _DEBUG_REFLECTION _DEBUG_NORMAL _DEBUG_FRESNEL _DEBUG_WATEREFFECTS _DEBUG_WATERDEPTH _DEBUG_LUMINANCE _DEBUG_SCENEPOS


#pragma require tessellation
#pragma vertex TessellationVertexProgram
#pragma fragment frag
#pragma hull hull 
#pragma domain domain

	TEXTURE2D( _CameraOpaqueTexture);
	SAMPLER(sampler_CameraOpaqueTexture_linear_clamp);
	TEXTURE2D( _PlanarReflectionTexture);
	SAMPLER(sampler_PlanarReflectionTexture_linear_clamp);
	TEXTURE2D(_BlitPassTexture);
    SAMPLER(sampler_BlitPassTexture);


	CBUFFER_START(UnityPerMaterial)
        float4 _ShadowColor;
    CBUFFER_END



	// pre tesselation vertex program
	ControlPoint TessellationVertexProgram(Attributes v)
	{
		ControlPoint p;

		p.vertex = v.vertex;
		p.uv = v.uv;
		p.normalOS = v.normalOS;
		p.tangentOS = v.tangentOS;


		return p;
	}
	
	float calculateSurface(float2 pos , out half3 normal, out half3 tangent)
	{	
		float y =0.0;
		float2 dir[3] = { normalize(float2(1,2)),normalize(float2(2,1)),normalize(float2(1,-2))};

		normal = float3(0,1,0);
		for(int i =0; i<3; i++){
			y += _amp*sin(dot(pos,dir[i])*_freq+_Time.y*_fi);
			normal.x += -(dir[i].x*_freq*_amp*cos(dot(pos,dir[i])*_freq+_Time.y*_fi));
			normal.z = -(dir[i].y*_freq*_amp*cos(dot(pos,dir[i])*_freq+_Time.y*_fi));
		}
		 
		tangent = half3(0,1,-normal.z);
		normal.y = 1;
		normal = normalize(normal);
		return y;
	}

	half2 DistortionUVs(half depth, float3 normalWS)
	{
   	 	half3 viewNormal = mul((float3x3)GetWorldToHClipMatrix(), -normalWS).xyz;
    	return viewNormal.xz;
	}

	// after tesselation
	Varyings vert(Attributes v)
	{
		Varyings output;
		half3 normalOS = v.normalOS;
		half3 tangentOS = v.tangentOS;
		half waveheight = calculateSurface(v.vertex.xz,normalOS,tangentOS);
		v.vertex.y += waveheight;
		

		half3 posWS = TransformObjectToWorld(v.vertex.xyz);
		half4 posCS = TransformObjectToHClip(v.vertex.xyz);

		half4 sp = ComputeScreenPos(posCS);
		sp = sp/sp.w;
		half4 waterFX = tex2Dlod(_WaterFXMap,half4(sp.x,sp.y,0,0)); 
		posWS.y += waterFX.w * 2 - 1;

		output.positionCS = TransformWorldToHClip(posWS);
		output.screenPos = ComputeScreenPos(output.positionCS);
		float fogFactor = ComputeFogFactor(output.positionCS.z);
		output.positionWSAndFog = half4(posWS,fogFactor);

		VertexNormalInputs normalInputs = GetVertexNormalInputs(normalize(normalOS), v.tangentOS);
		output.normalWS = normalInputs.normalWS;
		output.tangentWS = normalInputs.tangentWS;
		output.bitangentWS = normalInputs.bitangentWS;
		output.uv = v.uv;
		

		return output;
	}

	[UNITY_domain("tri")]
	Varyings domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
	{
		Attributes v;

#define DomainPos(fieldName) v.fieldName = \
				patch[0].fieldName * barycentricCoordinates.x + \
				patch[1].fieldName * barycentricCoordinates.y + \
				patch[2].fieldName * barycentricCoordinates.z;
			DomainPos(vertex)
			DomainPos(uv)
			DomainPos(normalOS)
			DomainPos(tangentOS)

			return vert(v);
	}

	// The fragment shader definition.            
	half4 frag(Varyings IN) : SV_Target
	{

		half3 viewDir  = SafeNormalize(GetCameraPositionWS() - IN.positionWSAndFog.xyz);

		half2 sp = IN.screenPos.xy/IN.screenPos.w;
		half4 waterfx = tex2D(_WaterFXMap,sp);
		half3 posWS = IN.positionWSAndFog.xyz;
		
       	float rawDepth = SampleSceneDepth(sp);
        float sceneEyeDepth = LinearEyeDepth(rawDepth,_ZBufferParams);
		float roughness = pow(1- _Smoothness,2.0);


		
		VertexPositionInputs vertexInput = (VertexPositionInputs)0;
        vertexInput.positionWS = posWS;
		float4 shadowCoord = GetShadowCoord(vertexInput);
		Light mainLight = GetMainLight(shadowCoord);
		half shadowAttenutation = MainLightRealtimeShadow(shadowCoord);


		//normal Calculation
        float2 uv1 = (IN.normalWS.y*0.5+1)*IN.uv*_UVScale;
        float2 uv2 = uv1 * _DetailScale;
        float2 timescroll = float2(_Time.y,_Time.y)*_ScrollSpeed; 
        float2 bias1 = float2(-0.1,0.035);
        float2 bias2 = float2(-0.01,0.05);
        uv1 += timescroll*bias1;
        uv2 += timescroll*bias2;
        float4 normalmap1 = tex2D(_NormalMap,uv1);
        normalmap1.rgb = UnpackNormalmapRGorAG(normalmap1);
        float4 normalmap2 = tex2D(_NormalMap,uv2);
        normalmap2.rgb = UnpackNormalmapRGorAG(normalmap2);
        float3 blend = normalize(float3(normalmap1.xy + normalmap2.xy, normalmap1.z * normalmap2.z));
        float Ratio = 1 - _DetailStrength;
        float3 normal = lerp(lerp(normalmap1.xyz, blend, saturate(Ratio*2)), normalmap2.xyz, saturate((Ratio-0.5)*2));
        float strength = 1-saturate((1-IN.normalWS.y)*0.5);
        normal = normal_strength_float(normal,strength);
        normal = normal_strength_float(normal,_BumpStrength);
        float strength1 = saturate(IN.normalWS.y+0.75);
        normal = normal_strength_float(normal,strength1);
		half3 normalWS = TransformTangentToWorld(normal,half3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz));
		normalWS +=  half3(1-waterfx.y, 0.5h, 1-waterfx.z) - 0.5;
		normalWS = normalize(normalWS);
		
		//distortion
		half depthFade = saturate((sceneEyeDepth - IN.screenPos.w)/ _WaterDepth);
		half2 distortfromdepth = DistortionUVs(depthFade, normalWS);
        half2 distort = distortfromdepth*0.1*_distortIntensityrefra+sp;
		half2 distortref = distortfromdepth*0.1*_distortIntensityrefle+sp;
		half distorteddepth = LinearEyeDepth(SampleSceneDepth(distort),_ZBufferParams);
		half dwaterdepth = saturate((distorteddepth - IN.screenPos.w) / _WaterDepth);
		distort = dwaterdepth>0 ? distort: sp;
		dwaterdepth = dwaterdepth>0? dwaterdepth:depthFade;

		//scenetextures
		float3 sceneposWS = ComputeWorldSpacePosition(sp, rawDepth, UNITY_MATRIX_I_VP);
		float relativeDepth = posWS.y- sceneposWS.y;
		float3 scenenormal = SampleSceneNormals(sp);
		scenenormal =mul(unity_CameraToWorld, float4(scenenormal, 0.0f));

		//caustic
		float4 caustics = TriplannarCaustic(_causticTint,1,sceneposWS,scenenormal);
		_causticIntense = relativeDepth>1?_causticIntense/relativeDepth:_causticIntense*relativeDepth;
		caustics *= _causticIntense*clamp(dot(scenenormal,mainLight.direction),0.001,1);

		//waterfall
		float2 scrol =float2(0.2,0.2)*_Time.y;	
		float3 noisez =tex2D(_FoamTexture,float2( posWS.z*10 , posWS.y+_Time.y*10)*0.1);
		float3 noisex =tex2D(_FoamTexture,float2( posWS.x*10 , posWS.y+_Time.y*10)*0.1);
		float3 blendNormal = saturate(pow(normalWS,4));
		float3 noise = lerp(noisex,noisez,blendNormal.x);
		float dotresult = dot(noise.xyz+normalWS,float3(0,1,0));
		float4 waterfall =step(0.5,dotresult)*step(dotresult,0.9);


		half4 underwatercolor =  SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture_linear_clamp, distort)+caustics;
		//reflection
		half4 reflection = SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture, sampler_PlanarReflectionTexture_linear_clamp, distortref, 6*roughness);

		//luminance
	#ifdef UNDERWATER_LUMINANCE
		float lod = clamp(sceneEyeDepth*0.25,0.0,5);
		half4 lumen = dwaterdepth>0?SAMPLE_TEXTURE2D_LOD(_BlitPassTexture, sampler_BlitPassTexture, distort,7):0;
		half luminance  = LinearRgbToLuminance(lumen.rgb);
		luminance = clamp(luminance-_luminanceThreshold,0,1);
		half lumenDist = depthFade*0.9f;
	#else
		half luminance = 0;
	#endif

		//water color 
		half4 watercolor = lerp(_ShallowColor,_DepthColor,dwaterdepth);
    	half4 refractcolor = lerp(underwatercolor, watercolor, watercolor.a);
		

		//foam
		float foamDiff = saturate((sceneEyeDepth - IN.screenPos.w) / _FoamThreshold);
        float foamTex = tex2D(_FoamTexture, posWS.xz * _FoamTexture_ST + _Time.y * float2(_FoamTextureSpeedX, _FoamTextureSpeedY));
        float foam = step(foamDiff - (saturate(sin((foamDiff - _Time.y * _FoamLinesSpeed) * 8 * PI)) * (1.0 - foamDiff)), foamTex);


		//prepare
		half3 halfVector = normalize(mainLight.direction + viewDir);
		float nv = max(saturate(dot(normalWS, viewDir)), 0.000001);
		float vh = max(saturate(dot(viewDir, halfVector)), 0.000001);
		float hv = max(saturate(dot(halfVector, viewDir)), 0.000001);
		half F0 =lerp(0.02, watercolor, _Metallic);


		//direct 
		BRDFData brdfData;
		half alpha = 0.3f;
    	InitializeBRDFData(0.0,_Metallic,1.0, _Smoothness,alpha, brdfData);
		
		//half4 dirlightcolor = half4(LightingPhysicallyBased(brdfData, mainLight, normalWS, viewDir),1);//
		half3 dirlightcolor = DirectBDRF(brdfData, normalWS, mainLight.direction, viewDir) * mainLight.color;
		
		half3 F = FresnelTerm(hv,F0);
		half fresnel = CalculateFresnelTerm(normalWS,viewDir);
		half oneMinusDielectricSpec = kDielectricSpec.a;
    	half oneminusref = oneMinusDielectricSpec - _Metallic * oneMinusDielectricSpec;
		half glazz = saturate(_Smoothness + (1.0 - oneminusref));
		half3 Flerp = fresnelLerp(F0,glazz,nv);

		uint pixelLightCount = GetAdditionalLightsCount();
    	for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    	{
        	Light light = GetAdditionalLight(lightIndex, posWS);
			
        	watercolor = lerp(watercolor,half4(light.distanceAttenuation * light.color,watercolor.a),light.distanceAttenuation);
    	}

		//sss
		 half3 directLighting = dot(mainLight.direction, half3(0, 1, 0)) * mainLight.color;
    	directLighting += saturate(pow(dot(viewDir, -mainLight.direction), 3)) * 5 * mainLight.color;
	#ifdef UNDERWATER_LUMINANCE
		half underwaterlumen = min(luminance/lumenDist,0.8f);
		refractcolor =  lerp(watercolor,underwatercolor,underwaterlumen);
		//watercolor = lerp(watercolor,half4(lumen.rgb/lumenDist,watercolor.a),underwaterlumen);
	#else
		half underwaterlumen = 0;
	#endif
		float3 sss = directLighting*shadowAttenutation*watercolor.rgb;//subsurfacescattering(viewDir,mainLight.direction,normalWS,_Distortsss,_Powersss,_Scalesss)*mainLight.color*_sssColor*depthFade;

		half4 col;
		fresnel = clamp(fresnel-luminance,0,1);
		col = lerp(refractcolor,reflection,fresnel)+half4(dirlightcolor+sss,1);
		col = lerp(col,_ShadowColor, (1.0 - shadowAttenutation) * _ShadowColor.a);
		
		col += foam* _FoamColor;
		
		
		float fogFactor = IN.positionWSAndFog.w;		
		col = half4(MixFog(col.xyz, fogFactor),alpha);

#if defined(_DEBUG_REFRACTION)
    return refractcolor;
#elif defined(_DEBUG_NORMAL)
    return half4(normalWS.x * 0.5 + 0.5, 0, normalWS.z * 0.5 + 0.5, 1);
#elif defined(_DEBUG_REFLECTION)
    return reflection;
#elif defined(_DEBUG_WATEREFFECTS)
    return waterfx.w;
#elif defined(_DEBUG_WATERDEPTH)
    return half4(sss,1);
#elif defined(_DEBUG_LUMINANCE)
    return lumen;
#elif defined(_DEBUG_FRESNEL)
	return fresnel;
#elif defined(_DEBUG_SCENEPOS)
	return caustics;

#else
    return half4(col.rgb,1);
#endif
		
	}
		ENDHLSL
	}

	UsePass "Universal Render Pipeline/Lit/ShadowCaster"
	UsePass "Universal Render Pipeline/Lit/Meta"
}
}
