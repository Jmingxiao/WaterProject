// vertex to fragment struct
struct Varyings
{
	float4 positionCS 				: SV_POSITION;
	float2 uv 						: TEXCOORD0;
	float4 screenPos				: TEXCOORD1; 
	half4 positionWSAndFog			: TEXCOORD3;
	half3 normalWS 					: TEXCOORD4;
	half3 tangentWS					: TEXCOORD5;    // xyz: tangent, w: viewDir.y
	half3 bitangentWS				: TEXCOORD6;
};

// the original vertex struct
struct Attributes
{
	float4 vertex 		: POSITION;
	float3 normalOS 	: NORMAL;
	float4 tangentOS 	: TANGENT;
	float2 uv 			: TEXCOORD0;
};

float _freq;
	float _amp;
	float _fi;


	float _WaterDepth;
    half4 _DepthColor;
    half4 _ShallowColor;
	float _luminanceThreshold;
	float _luminance;
	float _Metallic;
	float _Smoothness;
	sampler2D  _LUT;
	
	half _Distortsss;
	half _Powersss;
	half _Scalesss;
	half4 _sssColor;

	float _causticIntense;
	float _causticTint;

	sampler2D _FoamTexture;
	float4 _FoamColor;
	float4 _FoamTexture_ST;
    float _FoamTextureSpeedX;
    float _FoamTextureSpeedY;
    float _FoamLinesSpeed;
	float _FoamThreshold;
	
	sampler2D _NormalMap;
    float2 _UVScale;
    float _DetailScale;
    float _DetailStrength;
    float _ScrollSpeed;
    float _BumpStrength;


    float _distortIntensityrefra;
	float _distortIntensityrefle;

	sampler2D _WaterFXMap;