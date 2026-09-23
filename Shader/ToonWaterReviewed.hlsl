#ifndef TOON_WATER_REVIEWED_INCLUDED
#define TOON_WATER_REVIEWED_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerMaterial)
float _TessellationUniform, _TessellationMinDist, _TessellationMaxDist;
float4 _ShallowColor, _DeepColor, _FresnelColor, _FoamColor;
float _DeepRange, _WaterAlpha, _WaterOpacity, _BottomRetain, _BottomExposure, _DiffuseContribution;
float4 _NormalSpeed, _NormalMap_ST;
float _NormalScale, _NormalLayer2Scale, _UnderWaterDistort, _ChromaticAberration;
float _NormalSeamBlend, _ContactSoftness;
float4 _CausticsSpeed1, _CausticsSpeed2, _CausticsTex_ST;
float _CausticsIntensity, _CausticsRange;
float _EdgeErosion, _FoamDistance, _FoamPushPull, _FoamDissolve, _FoamThickness, _FoamWaveSpeed, _FoamWaveFrequency;
float4 _FoamNoiseTex_ST, _WaveA, _WaveB, _WaveC, _FoamSpeed;
float _FoamMaxDepth, _CrestFoamThreshold, _CrestFoamStrength, _FoamEnabled;
float4 _SSSColor, _GlintColor, _GlintSpeed, _PBRSpecularColor;
float _SSSIntensity, _SSSPower, _SSSDistortion, _GlintScale, _GlintThreshold, _GlintStrength;
float _PBRSmoothness, _PBRSpecularIntensity, _SpecularF0, _SpecularAA;
float _RippleIntensity, _RippleNormalStrength, _RippleTexelSize, _RippleCrestStrength;
float4 _WaterCenter;
float _RippleReady;
float4 _RippleOriginSize, _RippleGrid;
float _SSRIntensity, _SSREnabled, _SSRMinReflect, _SSRJitter, _SSRBaseStep, _SSRAdaptiveStep, _SSRBaseThickness;
float _SSRRoughness, _SSRBrightness, _SSRContrast, _SSRWaterPlaneBias, _SSRMaxDistance, _SSREdgeFade, _SSRNormalBias;
// ShaderLab legacy Int properties are float-backed material values.
float _SSRMaxSteps, _SSRRefineSteps;
float _ProbeIntensity, _FresnelPower, _FresnelGlowPower, _FresnelGlowIntensity, _GlowReflectionSplit;
float _DebugEnabled, _DebugMode, _LegacyWaterlineEnabled;
CBUFFER_END

TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
TEXTURE2D(_CausticsTex); SAMPLER(sampler_CausticsTex);
TEXTURE2D(_FoamNoiseTex); SAMPLER(sampler_FoamNoiseTex);
TEXTURE2D(_RippleTex); SAMPLER(sampler_RippleTex);
TEXTURE2D(_WaterMaskTex); SAMPLER(sampler_WaterMaskTex);
TEXTURE2D_X(_WaterReviewReflectionTexture);
TEXTURE2D_X(_WaterReviewBackgroundTexture);
float4 _WaterReviewColorInfo, _WaterReviewBackgroundInfo;
float3 _CameraNearPlane0, _CameraNearPlane1, _CameraNearPlane2, _CameraNearPlane3;
float4 _OrthoCenter;
float _OrthoSize;

struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
struct ControlPoint { float3 positionWS : TEXCOORD0; float2 uv : TEXCOORD1; };
struct TessFactors { float edge[3] : SV_TessFactor; float inside : SV_InsideTessFactor; };
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 screenPos : TEXCOORD1;
    float3 positionWS : TEXCOORD2;
    float3 normalWS : TEXCOORD3;
    float3 tangentWS : TEXCOORD4;
    float crestFoam : TEXCOORD5;
};

float3 WaterSafeNormalize(float3 v, float3 fallback)
{
    float l2 = dot(v,v);
    return l2 > 1e-10 ? v * rsqrt(l2) : fallback;
}

float3 GerstnerWave(float3 p, float4 wave, float time, inout float3 tangent, inout float3 bitangent)
{
    float directionLength = length(wave.xy);
    if (directionLength < 1e-5 || abs(wave.w) < 1e-4) return 0;
    float2 dir = wave.xy / directionLength;
    float k = TWO_PI / max(abs(wave.w), 0.01);
    // Wrap phase, not elapsed time: no discontinuity at 3600 seconds.
    float phase = TWO_PI * frac((k * (dot(dir,p.xz) - directionLength*time)) / TWO_PI);
    float s, c; sincos(phase,s,c);
    float steepness = clamp(wave.z,-0.95,0.95);
    float a = steepness/k;
    tangent += float3(-dir.x*dir.x*steepness*s, dir.x*steepness*c, -dir.x*dir.y*steepness*s);
    bitangent += float3(-dir.x*dir.y*steepness*s, dir.y*steepness*c, -dir.y*dir.y*steepness*s);
    return float3(dir.x*a*c,a*s,dir.y*a*c);
}

ControlPoint vert(Attributes input)
{
    ControlPoint o; o.positionWS=TransformObjectToWorld(input.positionOS.xyz); o.uv=input.uv; return o;
}
float CalcTess(float3 p)
{
    float nearDist=max(0,_TessellationMinDist);
    float farDist=max(nearDist+0.01,_TessellationMaxDist);
    return lerp(1,clamp(_TessellationUniform,1,63),saturate((farDist-distance(p,GetCameraPositionWS()))/(farDist-nearDist)));
}
TessFactors ConstHS(InputPatch<ControlPoint,3> p)
{
    TessFactors f;
    float3 tess=float3(CalcTess(p[0].positionWS),CalcTess(p[1].positionWS),CalcTess(p[2].positionWS));
    f.edge[0]=(tess.y+tess.z)*0.5; f.edge[1]=(tess.z+tess.x)*0.5; f.edge[2]=(tess.x+tess.y)*0.5;
    f.inside=(tess.x+tess.y+tess.z)/3; return f;
}
[domain("tri")] [partitioning("fractional_odd")] [outputtopology("triangle_cw")]
[outputcontrolpoints(3)] [patchconstantfunc("ConstHS")]
ControlPoint hullShader(InputPatch<ControlPoint,3> p,uint id:SV_OutputControlPointID) { return p[id]; }

bool RippleValid() { return _RippleReady > 0.5 && all(_RippleOriginSize.zw > 0) && _RippleIntensity > 0; }
float2 RippleUV(float3 p) { return (p.xz-_RippleOriginSize.xy)/max(_RippleOriginSize.zw,0.001)+0.5; }
float RippleHeight(float2 uv)
{
    if(any(uv<0)||any(uv>1)) return 0;
    return SAMPLE_TEXTURE2D_LOD(_RippleTex,sampler_RippleTex,uv,0).r;
}
[domain("tri")]
Varyings domainShader(TessFactors factors,OutputPatch<ControlPoint,3> p,float3 bary:SV_DomainLocation)
{
    Varyings o;
    float3 basePosition=p[0].positionWS*bary.x+p[1].positionWS*bary.y+p[2].positionWS*bary.z;
    float3 t=float3(1,0,0), b=float3(0,0,1);
    float3 displacement=GerstnerWave(basePosition,_WaveA,_Time.y,t,b);
    displacement+=GerstnerWave(basePosition,_WaveB,_Time.y,t,b);
    displacement+=GerstnerWave(basePosition,_WaveC,_Time.y,t,b);
    float3 finalPosition=basePosition+displacement;
    [branch] if(RippleValid()) finalPosition.y+=RippleHeight(RippleUV(finalPosition))*_RippleIntensity;
    o.normalWS=WaterSafeNormalize(cross(b,t),float3(0,1,0));
    o.tangentWS=WaterSafeNormalize(t-o.normalWS*dot(t,o.normalWS),float3(1,0,0));
    o.positionWS=finalPosition; o.positionCS=TransformWorldToHClip(finalPosition); o.screenPos=ComputeScreenPos(o.positionCS);
    o.uv=p[0].uv*bary.x+p[1].uv*bary.y+p[2].uv*bary.z;
    // W10 intentionally remains a separate task; preserve original crest semantics.
    o.crestFoam=saturate((displacement.y/3-_CrestFoamThreshold)*_CrestFoamStrength);
    return o;
}

float EyeDepth(float rawDepth)
{
    if(unity_OrthoParams.w>0.5)
    {
        #if UNITY_REVERSED_Z
        rawDepth=1-rawDepth;
        #endif
        return lerp(_ProjectionParams.y,_ProjectionParams.z,rawDepth);
    }
    return LinearEyeDepth(rawDepth,_ZBufferParams);
}
bool DepthValid(float rawDepth)
{
    #if UNITY_REVERSED_Z
    return rawDepth>1e-6;
    #else
    return rawDepth<0.999999;
    #endif
}
float SceneDepthLOD(float2 uv)
{
    uv=ClampAndScaleUVForBilinear(UnityStereoTransformScreenSpaceTex(uv),_CameraDepthTexture_TexelSize.xy);
    return SAMPLE_TEXTURE2D_X_LOD(_CameraDepthTexture,sampler_PointClamp,uv,0).r;
}
float3 Background(float2 uv)
{
    float3 result=0;
    if(_WaterReviewBackgroundInfo.w>0.5)
    {
        uv=UnityStereoTransformScreenSpaceTex(uv);
        float2 texel=0.5/max(_WaterReviewBackgroundInfo.xy,float2(1,1));
        uv=clamp(uv,texel,1-texel);
        result=SAMPLE_TEXTURE2D_X_LOD(_WaterReviewBackgroundTexture,sampler_LinearClamp,uv,0).rgb;
    }
    else
    {
        uv=ClampAndScaleUVForBilinear(UnityStereoTransformScreenSpaceTex(uv),_CameraOpaqueTexture_TexelSize.xy);
        result=SAMPLE_TEXTURE2D_X_LOD(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,uv,0).rgb;
    }
    return result;
}
float3 SeabedPosition(float2 uv,float depth)
{
    #if !UNITY_REVERSED_Z
    depth=lerp(UNITY_NEAR_CLIP_VALUE,1,depth);
    #endif
    return ComputeWorldSpacePosition(uv,depth,UNITY_MATRIX_I_VP);
}
float2 ValidRefractionUV(float2 candidate,float2 fallback,float surfaceDepth)
{
    if(any(candidate<0)||any(candidate>1)) return fallback;
    return EyeDepth(SceneDepthLOD(candidate)) < surfaceDepth+0.001 ? fallback : candidate;
}

bool TraceSample(float3 pointVS,out float2 uv,out float delta)
{
    uv=0;delta=0;
    float rayDepth=-pointVS.z;
    if(rayDepth<=_ProjectionParams.y || rayDepth>=_ProjectionParams.z) return false;
    float4 clipPosition=mul(UNITY_MATRIX_P,float4(pointVS,1));
    if(clipPosition.w<=1e-5) return false;
    uv=ComputeScreenPos(clipPosition).xy/clipPosition.w;
    if(any(uv<=0)||any(uv>=1)) return false;
    float raw=SceneDepthLOD(uv);
    if(!DepthValid(raw)) { delta=-_ProjectionParams.z; return true; }
    delta=rayDepth-EyeDepth(raw); return true;
}

float3 TraceSSR(float3 positionWS,float3 normalWS,float3 directionWS,float2 screenUV,
                out float confidence,out float iterations,out float actualLOD)
{
    confidence=0;iterations=0;actualLOD=0;
    #if defined(_WATER_SSR)
    if(_WaterReviewColorInfo.w<0.5) return 0;
    float3 originWS=positionWS+normalWS*max(_SSRNormalBias,0.001);
    float3 originVS=TransformWorldToView(originWS);
    float3 dirVS=WaterSafeNormalize(mul((float3x3)UNITY_MATRIX_V,directionWS),float3(0,0,-1));
    int maxSteps=(int)clamp(_SSRMaxSteps,1,150), refineSteps=(int)clamp(_SSRRefineSteps,0,8);
    float maxDistance=clamp(_SSRMaxDistance,0.05,1000);
    float growth=clamp(_SSRAdaptiveStep,0,0.2);
    float geometricSum=growth>1e-4 ? ((pow(1+growth,maxSteps)-1)/growth) : maxSteps;
    // Redistribute steps over an explicit distance budget. BaseStep is a lower bound.
    float stepSize=max(clamp(_SSRBaseStep,0.001,maxDistance),maxDistance/max(geometricSum,1));
    float jitter=frac(sin(dot(screenUV*_ScaledScreenParams.xy,float2(12.9898,78.233)))*43758.5453);
    float previousT=0, travel=min(maxDistance,stepSize*0.25*jitter*saturate(_SSRJitter*0.5));
    float2 previousUV;float previousDelta;
    if(!TraceSample(originVS,previousUV,previousDelta)) return 0;
    bool previousFront=previousDelta<0;
    [loop] for(int i=0;i<maxSteps;i++)
    {
        travel=min(travel+stepSize,maxDistance);
        float3 p=originVS+dirVS*travel;
        float2 uv;float delta;
        iterations=i+1;
        if(!TraceSample(p,uv,delta)) break;
        // Local tangent plane reject, instead of a fixed global-Y plane.
        if(dot((originWS+directionWS*travel)-positionWS,normalWS)<-max(_SSRWaterPlaneBias,0)) break;
        if(previousFront&&delta>=0)
        {
            float lo=previousT,hi=travel;float2 hitUV=uv;float hitDelta=delta;
            bool valid=true;
            [loop] for(int j=0;j<refineSteps;j++)
            {
                float mid=(lo+hi)*0.5;float2 midUV;float midDelta;
                if(!TraceSample(originVS+dirVS*mid,midUV,midDelta)){valid=false;break;}
                if(midDelta>=0){hi=mid;hitUV=midUV;hitDelta=midDelta;}else lo=mid;
            }
            float thickness=clamp(_SSRBaseThickness,0.005,5);
            if(valid&&hitDelta<=thickness)
            {
                float edge=min(min(hitUV.x,hitUV.y),min(1-hitUV.x,1-hitUV.y));
                confidence=smoothstep(0,max(_SSREdgeFade,0.001),edge);
                confidence*=1-smoothstep(maxDistance*0.85,maxDistance,hi);
                confidence*=1-smoothstep(thickness*0.5,thickness,hitDelta);
                actualLOD=saturate(_SSRRoughness)*max(_WaterReviewColorInfo.z,0);
                float2 sampleUV=clamp(UnityStereoTransformScreenSpaceTex(hitUV),0.5/_WaterReviewColorInfo.xy,1-0.5/_WaterReviewColorInfo.xy);
                float3 color=SAMPLE_TEXTURE2D_X_LOD(_WaterReviewReflectionTexture,sampler_LinearClamp,sampleUV,actualLOD).rgb;
                return max((color*max(_SSRBrightness,0)-0.18)*max(_SSRContrast,0)+0.18,0);
            }
        }
        previousT=travel; previousFront=delta<0;
        if(travel>=maxDistance) break;
        stepSize*=1+growth;
    }
    #endif
    return 0;
}

float3 WaterTileNormal(float2 uv, float scale)
{
    // Explicit gradients keep mip selection continuous across the periodic blend masks.
    float2 dx=ddx(uv),dy=ddy(uv);
    float3 n=UnpackNormalScale(SAMPLE_TEXTURE2D_GRAD(_NormalMap,sampler_NormalMap,uv,dx,dy),scale);
    float3 result=n;
    [branch] if(_NormalSeamBlend>0.0001)
    {
        float2 f=frac(uv);
        float2 w=smoothstep(0,clamp(_NormalSeamBlend,0.001,0.25),min(f,1-f));
        result=n*w.x*w.y;
        // At each texture seam its own sample has zero weight; the half-tile-shifted sample is continuous there.
        [branch] if(w.x<1) result+=UnpackNormalScale(SAMPLE_TEXTURE2D_GRAD(_NormalMap,sampler_NormalMap,uv+float2(0.5,0),dx,dy),scale)*(1-w.x)*w.y;
        [branch] if(w.y<1) result+=UnpackNormalScale(SAMPLE_TEXTURE2D_GRAD(_NormalMap,sampler_NormalMap,uv+float2(0,0.5),dx,dy),scale)*w.x*(1-w.y);
        [branch] if(w.x<1&&w.y<1) result+=UnpackNormalScale(SAMPLE_TEXTURE2D_GRAD(_NormalMap,sampler_NormalMap,uv+0.5,dx,dy),scale)*(1-w.x)*(1-w.y);
    }
    return WaterSafeNormalize(result,float3(0,0,1));
}

float4 frag(Varyings input):SV_Target
{
    float opacity=saturate(_WaterOpacity);
    clip(opacity-0.0001);
    float2 uv=input.screenPos.xy/max(input.screenPos.w,1e-5);
    [branch] if(_LegacyWaterlineEnabled>0.5 && _OrthoSize>1e-4)
    {
        float3 nearWS=lerp(lerp(_CameraNearPlane0,_CameraNearPlane1,uv.x),lerp(_CameraNearPlane2,_CameraNearPlane3,uv.x),uv.y);
        float2 maskUV=(nearWS.xz-_OrthoCenter.xy)/_OrthoSize+0.5;
        if(all(maskUV>=0)&&all(maskUV<=1))
        {
            float height=SAMPLE_TEXTURE2D_LOD(_WaterMaskTex,sampler_WaterMaskTex,maskUV,0).r*4-2;
            clip(nearWS.y-height);
        }
    }
    float rawDepth=SceneDepthLOD(uv);
    float surfaceDepth=-TransformWorldToView(input.positionWS).z;
    float signedWaterDepth=EyeDepth(rawDepth)-surfaceDepth;
    // Resolved scene depth can belong to foreground geometry even on partially covered MSAA pixels.
    // Such samples must not turn into zero-depth white foam or opaque water around an object's silhouette.
    float contactCoverage=saturate(signedWaterDepth/max(_ContactSoftness,0.0001));
    float waterDepth=max(0,signedWaterDepth);
    float2 baseUV=input.uv*_NormalMap_ST.xy;
    float scale=clamp(_NormalScale,0,4);
    float3 n1=WaterTileNormal(baseUV+_NormalMap_ST.zw+_Time.y*_NormalSpeed.xy,scale);
    float2 secondUV=float2(-baseUV.y,baseUV.x)*max(_NormalLayer2Scale,0.01)+_NormalMap_ST.zw+_Time.y*_NormalSpeed.zw;
    float3 n2=WaterTileNormal(secondUV,scale);
    n2.xy=float2(n2.y,-n2.x);
    float3 nt=n1+float3(0,0,1),nu=n2*float3(-1,-1,1);
    float3 tangentNormal=WaterSafeNormalize(nt*dot(nt,nu)/max(nt.z,0.001)-nu,float3(0,0,1));
    float rippleH=0;float2 rippleGradient=0;
    [branch] if(RippleValid()&&(_RippleNormalStrength>0 || _RippleCrestStrength>0 || _DebugMode>=11))
    {
        float2 rippleUV=RippleUV(input.positionWS);
        rippleH=RippleHeight(rippleUV);
        float dx=RippleHeight(rippleUV+float2(_RippleGrid.x,0))-RippleHeight(rippleUV-float2(_RippleGrid.x,0));
        float dz=RippleHeight(rippleUV+float2(0,_RippleGrid.y))-RippleHeight(rippleUV-float2(0,_RippleGrid.y));
        rippleGradient=float2(dx,dz)/max(2*_RippleGrid.zw,0.00001)*_RippleNormalStrength*_RippleIntensity;
    }
    float3 normal=WaterSafeNormalize(input.normalWS,float3(0,1,0));
    // Adding world-space height h(x,z) changes N to (Nx-hx*Ny, Ny, Nz-hz*Ny).
    // The slope is independent of the mesh UV/tangent orientation.
    normal=WaterSafeNormalize(normal-float3(rippleGradient.x,0,rippleGradient.y)*normal.y,normal);
    float3 tangent=WaterSafeNormalize(input.tangentWS-normal*dot(input.tangentWS,normal),float3(1,0,0));
    float3 bitangent=cross(tangent,normal);
    float3 finalN=WaterSafeNormalize(tangentNormal.x*tangent+tangentNormal.y*bitangent+tangentNormal.z*normal,normal);
    float3 viewDir=GetWorldSpaceNormalizeViewDir(input.positionWS);
    float ndv=saturate(dot(finalN,viewDir));
    float fresnel=pow(max(1-ndv,0),clamp(_FresnelPower,0.01,100));
    #if defined(_WATER_DEBUG)
    if(_DebugMode==4) return float4(finalN*0.5+0.5,1);
    if(_DebugMode==7) return float4(fresnel.xxx,1);
    if(_DebugMode==11) return float4(saturate(0.5+rippleH*5).xxx,1);
    if(_DebugMode==12) return float4(saturate(rippleGradient*0.5+0.5),0.5,1);
    if(_DebugMode==6)
    {
        float2 texel=_CameraDepthTexture_TexelSize.xy;
        float2 gradient=float2(EyeDepth(SceneDepthLOD(uv-float2(texel.x,0)))-EyeDepth(SceneDepthLOD(uv+float2(texel.x,0))),
            EyeDepth(SceneDepthLOD(uv-float2(0,texel.y)))-EyeDepth(SceneDepthLOD(uv+float2(0,texel.y))));
        gradient*=rsqrt(max(dot(gradient,gradient),1e-8));return float4(gradient*0.5+0.5,0,1);
    }
    #endif

    float3 normalVS=mul((float3x3)UNITY_MATRIX_V,finalN-normal);
    float2 offset=normalVS.xy*_UnderWaterDistort*0.01*smoothstep(0,0.5,waterDepth);
    float edge=min(min(uv.x,uv.y),min(1-uv.x,1-uv.y));
    offset*=smoothstep(0,0.025,edge);
    float2 uvG=ValidRefractionUV(uv+offset,uv,surfaceDepth);
    float3 refracted=Background(uvG);
    [branch] if(_ChromaticAberration>0.0001 && dot(offset,offset)>1e-10)
    {
        float dispersion=clamp(_ChromaticAberration,0,5);
        float2 uvR=ValidRefractionUV(uv+offset*(1+dispersion),uv,surfaceDepth);
        float2 uvB=ValidRefractionUV(uv+offset*(1-dispersion),uv,surfaceDepth);
        refracted.r=Background(uvR).r;refracted.b=Background(uvB).b;
    }
    float rawDist=SceneDepthLOD(uvG);
    float depth=max(0,EyeDepth(rawDist)-surfaceDepth);
    float fN=1,foam=0,shoreCoverage=1;
    [branch] if(_FoamEnabled>0.5 || _EdgeErosion>0)
    {
        float2 foamUV=input.positionWS.xz*_FoamNoiseTex_ST.xy+_FoamNoiseTex_ST.zw+_Time.y*_FoamSpeed.xy;
        fN=SAMPLE_TEXTURE2D(_FoamNoiseTex,sampler_FoamNoiseTex,foamUV).r;
        if(_EdgeErosion>0)
        {
            float shoreDistance=depth-(1-fN)*_EdgeErosion;
            float shoreAA=max(fwidth(shoreDistance),0.001);
            clip(shoreDistance+shoreAA);
            shoreCoverage=smoothstep(-shoreAA,shoreAA,shoreDistance);
        }
        if(_FoamEnabled>0.5)
        {
            float width=max(_FoamDistance+sin(_Time.y*_FoamWaveSpeed-depth*_FoamWaveFrequency)*_FoamPushPull,0.01);
            float depthFade=1-smoothstep(0,max(_FoamMaxDepth,0.001),depth);
            float signal=(1-saturate(depth/width))*fN*depthFade;
            float aa=max(fwidth(signal),0.0001);
            float shore=smoothstep(_FoamDissolve-aa,_FoamDissolve+max(_FoamThickness,0.001)+aa,signal);
            foam=saturate(max(shore,input.crestFoam*fN));
        }
    }
    #if defined(_WATER_DEBUG)
    if(_DebugMode==5) return float4(foam.xxx,1);
    #endif
    float depthRange=max(_DeepRange,0.001);
    float fogFactor=pow(saturate(depth/depthRange),0.8);
    float3 waterColor=lerp(_ShallowColor.rgb,_DeepColor.rgb,fogFactor);
    float3 bottom=lerp(waterColor,refracted*waterColor*max(_BottomExposure,0),saturate(_BottomRetain));
    float3 color=lerp(refracted,bottom,saturate(lerp(_ShallowColor.a,_DeepColor.a,fogFactor)*_WaterAlpha));

    Light light=GetMainLight(TransformWorldToShadowCoord(input.positionWS));
    float3 radiance=light.color*light.distanceAttenuation*light.shadowAttenuation;
    float ndl=saturate(dot(finalN,light.direction));
    color+=radiance*ndl*waterColor*max(_DiffuseContribution,0);
    [branch] if(_CausticsIntensity>0 && _CausticsRange>0 && DepthValid(rawDist))
    {
        float3 seabed=SeabedPosition(uvG,rawDist);
        float2 cauUV=seabed.xz*_CausticsTex_ST.xy+_CausticsTex_ST.zw;
        float3 caustics=min(SAMPLE_TEXTURE2D(_CausticsTex,sampler_CausticsTex,cauUV+_Time.y*_CausticsSpeed1.xy).rgb,
                           SAMPLE_TEXTURE2D(_CausticsTex,sampler_CausticsTex,cauUV+_Time.y*_CausticsSpeed2.xy).rgb);
        float fade=1-smoothstep(0,max(_CausticsRange,0.001),depth);
        Light bottomLight=GetMainLight(TransformWorldToShadowCoord(seabed));
        color+=caustics*lerp(float3(1,1,1),waterColor,0.6)*_CausticsIntensity*fade*fade*bottomLight.shadowAttenuation;
    }

    bool reflectionDebug=false;
    #if defined(_WATER_DEBUG)
    reflectionDebug=(_DebugMode>=1&&_DebugMode<=3)||_DebugMode==8||_DebugMode==9||_DebugMode==10||_DebugMode>=13;
    #endif
    float3 reflectedDir=reflect(-viewDir,finalN);
    float3 rawProbe=0,ssr=0;float confidence=0,steps=0,lod=0;
    [branch] if(_SSRIntensity>0 || _FresnelGlowIntensity>0 || reflectionDebug)
        rawProbe=GlossyEnvironmentReflection(reflectedDir,input.positionWS,saturate(_SSRRoughness),1,uv);
    #if defined(_WATER_SSR)
    [branch] if(_SSRIntensity>0 || reflectionDebug)
        ssr=TraceSSR(input.positionWS,finalN,reflectedDir,uv,confidence,steps,lod);
    #endif
    float3 probe=rawProbe*max(_ProbeIntensity,0);
    float3 reflection=lerp(probe,ssr,confidence);
    float glowFactor=pow(max(1-ndv,0),clamp(_FresnelGlowPower,0.01,100));
    float3 glow=rawProbe*_FresnelColor.rgb*glowFactor*max(_FresnelGlowIntensity,0)*(1-smoothstep(0,depthRange*0.5,depth));
    float reflectWeight=saturate(_SSRIntensity)*lerp(saturate(_SSRMinReflect),1,fresnel)*lerp(1,1-fresnel,saturate(_GlowReflectionSplit));
    color=lerp(color,reflection,reflectWeight)+glow;
    #if defined(_WATER_DEBUG)
    if(_DebugMode==1) return float4(ssr*confidence,1);
    if(_DebugMode==2) return float4(probe,1);
    if(_DebugMode==3) return float4(reflection,1);
    if(_DebugMode==8) return float4(glow,1);
    if(_DebugMode==9) return float4(glowFactor.xxx,1);
    if(_DebugMode==10) return float4((lod/max(_WaterReviewColorInfo.z,1)).xxx,1);
    if(_DebugMode==13) return float4(confidence.xxx,1);
    if(_DebugMode==14) return float4((steps/max((float)_SSRMaxSteps,1)).xxx,1);
    #endif
    float3 halfDir=WaterSafeNormalize(light.direction+viewDir,finalN);
    float ndh=saturate(dot(finalN,halfDir));
    [branch] if(_GlintStrength>0)
    {
        float2 glintUV=input.positionWS.xz*_FoamNoiseTex_ST.xy*max(_GlintScale,0.001)+_FoamNoiseTex_ST.zw+_Time.y*_GlintSpeed.xy;
        float noise=SAMPLE_TEXTURE2D(_FoamNoiseTex,sampler_FoamNoiseTex,glintUV).r;
        float signal=pow(ndh,16)*noise;
        float aa=max(fwidth(signal),0.01);
        float glint=smoothstep(_GlintThreshold-aa,_GlintThreshold+0.05+aa,signal);
        color+=_GlintColor.rgb*glint*_GlintStrength*radiance*fresnel;
    }
    [branch] if(_SSSIntensity>0)
    {
        float3 sssDir=WaterSafeNormalize(light.direction+finalN*saturate(_SSSDistortion),finalN);
        float transmission=pow(saturate(dot(viewDir,-sssDir)),clamp(_SSSPower,0.01,128));
        color+=_SSSColor.rgb*transmission*_SSSIntensity*radiance*saturate(depth/depthRange);
    }
    float3 normalDx=ddx(finalN),normalDy=ddy(finalN);
    [branch] if(_PBRSpecularIntensity>0 && ndl>0 && ndv>0)
    {
        float alpha=max(2/(max(_PBRSmoothness,0)+2),0.02);
        float alpha2=clamp(alpha*alpha+max(_SpecularAA,0)*(dot(normalDx,normalDx)+dot(normalDy,normalDy)),0.0004,1);
        float denom=ndh*ndh*(alpha2-1)+1;
        float D=alpha2/max(PI*denom*denom,1e-7);
        float visibility=0.5/max(ndl*sqrt(ndv*ndv*(1-alpha2)+alpha2)+ndv*sqrt(ndl*ndl*(1-alpha2)+alpha2),1e-4);
        float F=lerp(saturate(_SpecularF0),1,pow(1-saturate(dot(viewDir,halfDir)),5));
        color+=_PBRSpecularColor.rgb*radiance*(D*visibility*F*ndl*max(_PBRSpecularIntensity,0));
    }
    // A separate optional visual cue for small interaction waves amid strong background normals.
    // Only positive ripple height contributes; it fades with the simulated wave, not with a timer.
    float crestHeight=rippleH*_RippleIntensity;
    float crestAA=max(fwidth(crestHeight),0.001);
    float rippleCrest=smoothstep(0.01-crestAA,0.06+crestAA,crestHeight)*saturate(_RippleCrestStrength);
    color=lerp(color,_FoamColor.rgb,saturate(max(foam,rippleCrest)*_FoamColor.a));
    // Composited color is opaque at 1; opacity fades the whole effect against the current framebuffer.
    return float4(max(color,0),opacity*shoreCoverage*contactCoverage);
}
#endif
