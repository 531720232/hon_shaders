// (C)2008 S2 Games
// mesh_color_unit.vsh
// 
// Default unit vertex shader
//=============================================================================

//=============================================================================
// Headers
//=============================================================================
#include "../common/common.h"
#include "../common/fog.h"

//=============================================================================
// Global variables
//=============================================================================
float4x4	mWorld;          // World * View * Projection transformation
float4x4	mViewProj;          // World * View * Projection transformation
float4x4	mWorldViewOffset;        // World * View Offset
float3x3	mWorldRotate;            // World rotation for normals

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

//=============================================================================
// Vertex shader output structure
//=============================================================================
struct VS_OUTPUT
{
	float4 Position : POSITION;
	float4 Color0 : COLOR0;
	float2 Texcoord0 : TEXCOORDX;
		#include "../common/inc_texcoord.h"
};

//=============================================================================
// Vertex shader input structure
//=============================================================================
struct VS_INPUT
{
	float3 Position   : POSITION;
	float2 Texcoord0  : TEXCOORD0;
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
	
	
#if (NUM_BONES > 0)
	float4 vPosition = 0.0f;

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

#else
	float4 vPosition = float4(In.Position, 1.0f);
#endif
	
	float4x4 mFlatWorldY = mWorld;
	mFlatWorldY[0][1] *= 0.01f; // Compress Y 99%
	mFlatWorldY[1][1] *= 0.01f; // Compress Y 99%
	mFlatWorldY[2][1] *= 0.01f; // Compress Y 99%
	mFlatWorldY[2][2] *= 1.2f; 
	
	Out.Position = mul(vPosition, mFlatWorldY);
	Out.Position = mul(Out.Position, mViewProj);
	
	Out.Color0 = vColor;

	Out.Texcoord0      = In.Texcoord0;

	return Out;
}

