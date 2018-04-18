// (C)2006 S2 Games
// terrain_color.vsh
// 
// Terrain
//=============================================================================

//=============================================================================
// Headers
//=============================================================================
#include "../common/common.h"
#include "../common/fog.h"

//=============================================================================
// Global variables
//=============================================================================
float4x4	mWorldViewProj;	         // World * View * Projection transformation
float4x4	mWorldViewOffset;	     // World * View  (No Scale)
float4x4	mWorld;			         // World transformation
float4x4	mWorldRotate;

float4		vSunPositionWorld;

float3		vSunColor;

float3		vWorldSizes;

float		fReflectionHeight;


#if (SHADOWS == 1)
float4x4	mLightWorldViewProjTex;  // Light's World * View * Projection * Tex
#endif

float4		vColor;

#if (NUM_BONES > 0)
float4x3	vBones[NUM_BONES];
#endif

#ifdef CLOUDS
float4x4	mCloudProj;
#endif

#if (FOG_OF_WAR == 1)
float4x4	mFowProj;
#endif

float4x4	mSceneProj;

//=============================================================================
// Vertex shader output structure
//=============================================================================
struct VS_OUTPUT
{
	float4 Position : POSITION;
	float4 Texcoord0 : TEXCOORDX;
		#include "../common/inc_texcoord.h"
	float4 PositionScreen : TEXCOORDX;
		#include "../common/inc_texcoord.h"
#if (LIGHTING_QUALITY == 0 || FALLOFF_QUALITY == 0)
	float3 PositionOffset : TEXCOORDX;
		#include "../common/inc_texcoord.h"
#endif
#if (LIGHTING_QUALITY == 0)
	float3 Normal : TEXCOORDX;
		#include "../common/inc_texcoord.h"
	float3 Tangent : TEXCOORDX;
		#include "../common/inc_texcoord.h"
	float3 Binormal : TEXCOORDX;
		#include "../common/inc_texcoord.h"
#elif (LIGHTING_QUALITY == 1)
	float3 HalfAngle : TEXCOORDX;
		#include "../common/inc_texcoord.h"
	float3 SunLight : TEXCOORDX;
		#include "../common/inc_texcoord.h"
	float3 Reflect : TEXCOORDX;
		#include "../common/inc_texcoord.h"
#endif
#if (SHADOWS == 1)
	float4 TexcoordLight : TEXCOORDX; // Texcoord in light texture space
		#include "../common/inc_texcoord.h"
#endif
#ifdef CLOUDS
	float2 TexcoordClouds : TEXCOORDX;
			#include "../common/inc_texcoord.h"
#endif
#if ((FOG_QUALITY == 1 && FOG_TYPE != 0) || (FALLOFF_QUALITY == 1 && (FOG_TYPE != 0 || SHADOWS == 1)) || FOG_OF_WAR == 1)
	float4 Last : TEXCOORDX;
		#include "../common/inc_texcoord.h"
#endif
};

//=============================================================================
// Vertex shader input structure
//=============================================================================
struct VS_INPUT
{
	float3 Position   : POSITION;
	float3 Normal     : NORMAL;
#if (TEXCOORDS == 1)
	float4 Texcoord0  : TEXCOORD0;
	float4 Tangent    : TEXCOORD1;
#endif
#if (NUM_BONES > 0)
	int4 BoneIndex    : TEXCOORD_BONEINDEX;
	float4 BoneWeight : TEXCOORD_BONEWEIGHT;
#endif
};

//=============================================================================
// Vertex Shader
//=============================================================================
VS_OUTPUT VS( VS_INPUT In )
{
	VS_OUTPUT Out;
	
#if ((FOG_QUALITY == 1 && FOG_TYPE != 0) || (FALLOFF_QUALITY == 1 && (FOG_TYPE != 0 || SHADOWS == 1)) || FOG_OF_WAR == 1)
	Out.Last = 0;
#endif

	float3 vInNormal = (In.Normal / 255.0f) * 2.0f - 1.0f;
	float4 vInTangent = (In.Tangent / 255.0f) * 2.0f - 1.0f;
	
#if (NUM_BONES > 0)
	float4 vPosition = 0.0f;
	float3 vNormal = 0.0f;
	float3 vTangent = 0.0f;

	//
	// GPU Skinning
	// Blend bone matrix transforms for this bone
	//
	
	int4 vBlendIndex = In.BoneIndex;
	float4 vBoneWeight = In.BoneWeight / 255.0f;
	
	float4x3 mBlend = 0.0f;
	for (int i = 0; i < NUM_BONE_WEIGHTS; ++i)
		mBlend += vBones[vBlendIndex[i]] * vBoneWeight[i];

	vPosition = float4(mul(float4(In.Position, 1.0f), mBlend).xyz, 1.0f);
	vNormal = mul(float4(vInNormal, 0.0f), mBlend).xyz;
	vTangent = mul(float4(vInTangent.xyz, 0.0f), mBlend).xyz;
	
	vNormal = normalize(vNormal);
	vTangent = normalize(vTangent);
#else
	float4 vPosition = float4(In.Position, 1.0f);
	float3 vNormal = vInNormal;
	float3 vTangent = vInTangent.xyz;
#endif
	
	float3 vPositionOffset = mul(vPosition, mWorldViewOffset).xyz;
	
	float3 vPositionWorld = mul(vPosition, mWorld).xyz;
	
	Out.Position      = mul(vPosition, mWorldViewProj);
		
	float fDistance = length(vPositionWorld);

	Out.Texcoord0 = In.Texcoord0;

	Out.PositionScreen = Out.Position;// / Out.Position.w;

#if (LIGHTING_QUALITY == 0 || FALLOFF_QUALITY == 0)
	Out.PositionOffset  = vPositionOffset;
#endif
#if (FALLOFF_QUALITY == 1 && (FOG_TYPE != 0 || SHADOWS == 1))
	Out.Last.z = fDistance;
#endif
	
#if (LIGHTING_QUALITY == 0)
	Out.Normal        = mul(mWorldRotate, vNormal);
	Out.Tangent       = mul(mWorldRotate, vTangent);
	Out.Binormal      = cross(Out.Tangent, Out.Normal);
	
#elif (LIGHTING_QUALITY == 1)
	float3 vCamDirection = -normalize(vPositionOffset);
	float3 vLight = vSunPositionWorld.xyz;
	float3 vWVNormal = vNormal;
	float3 vWVTangent = vTangent;
	float3 vWVBinormal = cross(vWVTangent, vWVNormal);

	float3x3 mRotate = transpose(float3x3(vWVTangent, vWVBinormal, vWVNormal));
	
	Out.SunLight      = mul(vLight, mRotate);
	Out.HalfAngle     = mul(normalize(vLight + vCamDirection), mRotate);
	Out.Reflect        = vNormal;//reflect(vPositionOffset, vWVNormal);
#endif

#if (SHADOWS == 1)
	Out.TexcoordLight = mul(vPosition, mLightWorldViewProjTex);
#endif

#ifdef CLOUDS
	Out.TexcoordClouds = mul(vPosition, mCloudProj).xy;
#endif

#if (FOG_QUALITY == 1 && FOG_TYPE != 0)
	Out.Last.w = Fog(vPositionOffset);
#endif

#if (FOG_OF_WAR == 1)
	Out.Last.xy = mul(vPosition, mFowProj).xy;
#endif

	return Out;
}
