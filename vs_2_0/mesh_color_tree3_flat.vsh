// (C)2008 S2 Games
// mesh_color_flat.vsh
// 
// ...
//=============================================================================

//=============================================================================
// Headers
//=============================================================================
#include "../common/common.h"
#include "../common/fog.h"

//=============================================================================
// Global variables
//=============================================================================
float4x4	mWorldViewOffset;        // World * View Offset
float3x3	mWorldRotate;            // World rotation for normals

float4		vSunPositionWorld;

float3		vAmbient;
float3		vSunColor;

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

#if (FOLIAGE == 1)
float4		vFoliage;
float		fTime;
float4x4	mWorld;
float4x4	mViewProj;
float4		vTreeFoliage2;
#else
float4x4	mWorldViewProj;          // World * View * Projection transformation
#endif

//=============================================================================
// Vertex shader output structure
//=============================================================================
struct VS_OUTPUT
{
	float4 Position : POSITION;
	float4 Color0 : COLOR0;
	float2 Texcoord0 : TEXCOORDX;
		#include "../common/inc_texcoord.h"
#if (LIGHTING_QUALITY == 0 || FALLOFF_QUALITY == 0)
	float3 PositionOffset : TEXCOORDX;
		#include "../common/inc_texcoord.h"
#endif
#if (LIGHTING_QUALITY == 0 || LIGHTING_QUALITY == 1)
	float3 Normal : TEXCOORDX;
		#include "../common/inc_texcoord.h"
#elif (LIGHTING_QUALITY == 2)
	#ifdef GROUND_AMBIENT
	float4 DiffLight : TEXCOORDX;
		#include "../common/inc_texcoord.h"
	#else
	float3 DiffLight : TEXCOORDX;
		#include "../common/inc_texcoord.h"
	#endif
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
#if (TEXCOORDS > 0)
	float2 Texcoord0  : TEXCOORD0;
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
	
#if (NUM_BONES > 0)
	float4 vPosition = 0.0f;
	float3 vNormal = 0.0f;

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
	
	vNormal = normalize(vNormal);
#else
	float4 vPosition = float4(In.Position, 1.0f);
	float3 vNormal = vInNormal;
#endif

	float3 vPositionOffset = mul(vPosition, mWorldViewOffset).xyz;
	
#if (FOLIAGE == 1)
	const float PI = 3.14159265358979323846f;
	float4 vPosition2 = mul(vPosition, mWorld);
	float fPositionOff = dot(normalize(vPosition2.xyz), vTreeFoliage2.z);
	float fXT = (fPositionOff * PI);
	float fPhaseBrushOffset = vPosition.z * vTreeFoliage2.w * cos((fTime + fXT) * vFoliage.z) * vFoliage.w;
	vPosition2.x += fPhaseBrushOffset * vTreeFoliage2.x;
	vPosition2.y += fPhaseBrushOffset * vTreeFoliage2.y;
	Out.Position = mul(vPosition2, mViewProj);
#else
	Out.Position = mul(vPosition, mWorldViewProj);
#endif

	Out.Color0         = vColor;
	Out.Texcoord0      = In.Texcoord0;
#if (LIGHTING_QUALITY == 0 || FALLOFF_QUALITY == 0)
	Out.PositionOffset = vPositionOffset;
#endif
#if (FALLOFF_QUALITY == 1 && (FOG_TYPE != 0 || SHADOWS == 1))
	Out.Last.z = length(vPositionOffset);
#endif
	
#if (LIGHTING_QUALITY == 0 || LIGHTING_QUALITY == 1)
	Out.Normal         = mul(vNormal, mWorldRotate);
#elif (LIGHTING_QUALITY == 2)
	float3 vLight = vSunPositionWorld.xyz;		
	float3 vWVNormal = normalize(mul(vNormal, mWorldRotate));

	float fDiffuse = saturate(dot(vWVNormal, vLight));

	Out.DiffLight.xyz =  vSunColor * fDiffuse;
	
	#ifdef GROUND_AMBIENT
	Out.DiffLight.w = dot(vWVNormal, float3(0.0f, 0.0f, 1.0f)) * 0.375f + 0.625f;
	#endif
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
