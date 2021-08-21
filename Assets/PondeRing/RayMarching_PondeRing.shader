Shader "RayMarching/PondeRing"
{

    Properties
    {
        [Enum(PondeRing, 0, Excramation, 1, Question, 2)] _Mode("Mode", Float) = 0

        _Color ("Color", Color) = (0.5, 0.5, 0.5, 1.0)
        _Loop("Loop", Range(1, 100)) = 30 
        _MinDist ("Minimum Distance", Range(0.001, 0.1)) = 0.01

        _PonOffset("Donuts Offset", Vector) = (0.0, 0.0, 0.0)
        _PonMajorRadius("Donuts Major Radius", Range(0, 0.5)) = 0.2
        _PonMinorRadius("Donuts Minor Radius", Range(0, 0.1)) = 0.05

        _ExcraOffset("Excramation Offset", Vector) = (0.0, 0.0, 0.0)
        _ExcraHeight("Excramation Height", Range(0, 1.0)) = 0.3
        _ExcraGap("Excramatino Gap", Range(0, 1.0)) = 0.2
        _ExcraMajorRadius("Excramation Major Radius", Range(0, 1)) = 0.1
        _ExcraMinorRadius("Excramation Minor Radius", Range(0, 1)) = 0.05

        _QuestOffset("Question Offset", Vector) = (0.0, 0.0, 0.0)
        _QuestBarLength("Question Bar Length", Range(0, 0.1)) = 0.05 
        _QuestGap("Question Gap", Range(0, 1)) = 0.2
    }

		SubShader
	{
		Tags { "RenderType" = "Opaque"  "LightMode" = "ForwardBase" }
		LOD 100
		Cull Front
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"


			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float3 pos : TEXCOORD1;
				float4 vertex : SV_POSITION;
			};

			struct pout
			{
				fixed4 color : SV_Target;
				float depth : SV_Depth;
			};

            #define PI 3.141592
            #define EQUAL(x, y) 1 - abs(sign(x - y))
            int _Mode;
            float4 _Color;
            int _Loop;
            float _MinDist;
            
            float3 _PonOffset;
            float _PonMajorRadius;
            float _PonMinorRadius;
            float3 _ExcraOffset;

            float _ExcraMinorRadius;
            float _ExcraMajorRadius;
            float _ExcraHeight;
            float _ExcraGap;

            float3 _QuestOffset;
            float _QuestBarLength;
            float _QuestGap;


            inline float2 Rotate2d(float2 pos, float angle)
            {
                float2x2 R = float2x2(
                    cos(angle), -sin(angle), sin(angle), cos(angle)
                );

                return mul(R, pos);
            }

			inline float sdSphere(float3 p, float3 o, float r) 
			{
				return length(p - o) - r;
			}

            inline float sdCapsule( float3 p, float3 a, float3 b, float r )
            {
                float3 pa = p - a, ba = b - a;
                float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
                return length( pa - ba*h ) - r;
            }

            inline float sdRoundCone( float3 p, float r1, float r2, float h )
            {
                float2 q = float2( length(p.xz), p.y );
                    
                float b = (r1-r2)/h;
                float a = sqrt(1.0-b*b);
                float k = dot(q,float2(-b,a));
                
                float d = dot(q, float2(a,b) ) - r1;
                d = (k < 0.0) ? length(q) - r1 : d;
                d = (k > a*h) ? length(q-float2(0.0, h)) - r2 : d;

                return d; 
            }

            float sdCappedTorus(in float3 p, in float2 sc, in float ra, in float rb)
            {
                p.x = abs(p.x);
                float k = (sc.y*p.x>sc.x*p.y) ? dot(p.xy,sc) : length(p.xy);
                return sqrt( dot(p,p) + ra*ra - 2.0*ra*k ) - rb;
            }

            float smoothMin(float d1, float d2, float k)
            {
                float h = exp(-k * d1) + exp(-k * d2);
                return -log(h) / k;
            }

            inline float sdPondeRing(float3 p)
            {
                int N = 8;
                float s[8];
                float r = _PonMinorRadius;
                float3 o = float3(_PonMajorRadius, 0.0, 0.0);
                float angle = 2 * PI  / N;
                float k = 15.0;

                p -= _PonOffset;

                s[0] = sdSphere(p, float3(Rotate2d(o.xy, angle * 0), o.z), r);
                s[1] = sdSphere(p, float3(Rotate2d(o.xy, angle * 1), o.z), r);
                s[2] = sdSphere(p, float3(Rotate2d(o.xy, angle * 2), o.z), r);
                s[3] = sdSphere(p, float3(Rotate2d(o.xy, angle * 3), o.z), r);
                s[4] = sdSphere(p, float3(Rotate2d(o.xy, angle * 4), o.z), r);
                s[5] = sdSphere(p, float3(Rotate2d(o.xy, angle * 5), o.z), r);
                s[6] = sdSphere(p, float3(Rotate2d(o.xy, angle * 6), o.z), r);
                s[7] = sdSphere(p, float3(Rotate2d(o.xy, angle * 7), o.z), r);


                float d= smoothMin(s[0], s[1], k);

                [unroll]
                for (int n=2; n<N; ++n)
                {
                    d = smoothMin(d, s[n], k);
                }
                return d;
            }

            inline float sdExcramation(float3 p)
            {
                float roundCone =  sdRoundCone(p - _ExcraOffset, _ExcraMinorRadius, _ExcraMajorRadius, _ExcraHeight);
                float sphere = sdSphere(p - _ExcraOffset, float3(0.0, -_ExcraGap, 0.0), _ExcraMinorRadius);
                return min(roundCone, sphere);
            }

            inline float sdQuestion(float3 p)
            {
                float cappedTorus;
                float theta = 0.7 * PI;

                float3 pTorus = p - float3(0.0, 0.12, 0.0) - _QuestOffset;
                pTorus = float3(Rotate2d(pTorus.xy, 0.3 * PI), pTorus.z);
                cappedTorus = sdCappedTorus(pTorus, float2(sin(theta), cos(theta)), 0.1, 0.03);

                float capsule  = sdCapsule(p - _QuestOffset, float3(0.0, -_QuestBarLength, 0.0), float3(0.0, 0.01, 0.0), 0.03);
                float sphere = sdSphere(p - _QuestOffset, float3(0.0, -_QuestGap, 0.0), 0.03);

                return min(min(capsule, cappedTorus), sphere);
            }

			float DistFunction(float3 p) {
                float d = 0.0;

                d = (EQUAL(_Mode, 0)) ? sdPondeRing(p) : d;
                d = (EQUAL(_Mode, 1)) ? sdExcramation(p) : d;
                d = (EQUAL(_Mode, 2)) ? sdQuestion(p) : d;

                return d;
			}


			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.pos = v.vertex.xyz;
				o.uv = v.uv;
				return o;
			}

			pout frag(v2f i)
			{
				float3 ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;
				float3 rd = normalize(i.pos.xyz - ro);

				float d =0;
				float t=0;
				float3 p = float3(0, 0, 0);
				for (int i = 0; i < _Loop; ++i) { 
					p = ro + rd * t;
					d = DistFunction(p);
					t += d;

                    if (d < _MinDist) break;
				}
				p = ro + rd * t;
				float4 col = _Color;

                if (d > _MinDist) discard;

				pout o;
				o.color = col;
				float4 projectionPos = UnityObjectToClipPos(float4(p, 1.0));
				o.depth = projectionPos.z / projectionPos.w;
				return o;

			}
			ENDCG
		}

	}
}