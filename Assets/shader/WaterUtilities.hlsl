#ifndef WATER_UTILITY_INCLUDED
#define WATER_UTILITY_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#ifdef UNITY_COLORSPACE_GAMMA
#define unity_ColorSpaceLuminance half4(0.22, 0.707, 0.071, 0.0)
#else // Linear values
#define unity_ColorSpaceLuminance half4(0.0396819152, 0.458021790, 0.00609653955, 1.0)
#endif

#define F(i) length(.5-frac( k.xyw = mul(float3x3(-2,-1,2, 3,-2,1, 1,2,2),k.xyw)*i))

float4 mainImage(float2 p)
{

    float4 k =float4(2022,5,9,_Time.x)*0.6;
    k.xy = p*(sin(k.w)*0.2+2.0)/float2(0.1,0.1);
    k = pow(min(min(F(0.5),F(0.4)),F(0.3)), 7.0)*25.+float4(0,0,0,1);
	return k;
}

half Luminance(half3 rgb)
{
    return dot(rgb, unity_ColorSpaceLuminance.rgb);
}

half LinearRgbToLuminance(half3 linearRgb)
{
    return dot(linearRgb, half3(0.2126729f,  0.7151522f, 0.0721750f));
}
	
float3 normal_strength_float(float3 inn,float str){
   return float3(inn.rg * str, lerp(1, inn.b, saturate(str)));
}

float4 TriplannarCaustic(float Tile,float Blend, float3 Position, float3 Normal){

	float3 Node_UV = Position * Tile;
	float3 Node_Blend = pow(abs(Normal), Blend);
	Node_Blend /= dot(Node_Blend, 1.0);

	float4 Node_X = mainImage(Node_UV.zy);
	float4 Node_Y = mainImage(Node_UV.xz);
	float4 Node_Z = mainImage(Node_UV.xy);

	return Node_X * Node_Blend.x + Node_Y * Node_Blend.y + Node_Z * Node_Blend.z;
}
float4 Triplannar(sampler2D tex, float Tile,float Blend, float3 Position, float3 Normal,float2 scroll){

	float3 Node_UV = Position * Tile;
	float3 Node_Blend = pow(abs(Normal), Blend);
	Node_Blend /= dot(Node_Blend, 1.0);

	float4 Node_X = tex2D(tex, Node_UV.zy+scroll);
	float4 Node_Y = tex2D(tex, Node_UV.xz+scroll);
	float4 Node_Z = tex2D(tex, Node_UV.xy+scroll);

	return  Node_Y ;
}

float3 HeightToNormal(Texture2D _tex, SamplerState _sampler, float2 _uv, half _intensity)
{
	float3 bumpSamples;
	bumpSamples.x = _tex.Sample(_sampler, _uv).x; // Sample center
	bumpSamples.y = _tex.Sample(_sampler, float2(_uv.x + _intensity / _ScreenParams.x, _uv.y)).x; // Sample U
	bumpSamples.z = _tex.Sample(_sampler, float2(_uv.x, _uv.y + _intensity / _ScreenParams.y)).x; // Sample V
	half dHdU = bumpSamples.z - bumpSamples.x;//bump U offset
	half dHdV = bumpSamples.y - bumpSamples.x;//bump V offset
	return float3(-dHdU, dHdV, 0.5);//return tangent normal
}
#endif