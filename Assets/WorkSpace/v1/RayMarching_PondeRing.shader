Shader "RayMarching/PondeRing"
{

    Properties
    {
        _Color ("Color", Color) = (0.5, 0.5, 0.5, 1.0)
        _Loop("Loop", Range(1, 100)) = 30 
        _MinDist ("Minimum Distance", Range(0.001, 0.1)) = 0.01

        _RadiusMajor("Donuts Major Radius", Range(0, 0.5)) = 0.2
        _RadiusMinor("Donuts Minor Radius", Range(0, 0.1)) = 0.05
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
            float4 _Color;
            int _Loop;
            float _MinDist;
            float _RadiusMajor;
            float _RadiusMinor;

            inline float2 Rotate2d(float2 pos, float angle)
            {
                float2x2 R = float2x2(
                    cos(angle), -sin(angle), sin(angle), cos(angle)
                );

                return mul(R, pos);
            }

			float DistSphere(float3 p, float3 o, float r) 
			{
				return length(p - o) - r;
			}

            float smoothMin(float d1, float d2, float k)
            {
                float h = exp(-k * d1) + exp(-k * d2);
                return -log(h) / k;
            }

            inline float DistPondeRing(float3 p)
            {
                int N = 8;
                float s[8];
                float r = _RadiusMinor;
                float3 o = float3(_RadiusMajor, 0.0, 0.0);
                float angle = 2 * PI  / N;
                float k = 15.0;

                s[0] = DistSphere(p, float3(Rotate2d(o.xy, angle * 0), o.z), r);
                s[1] = DistSphere(p, float3(Rotate2d(o.xy, angle * 1), o.z), r);
                s[2] = DistSphere(p, float3(Rotate2d(o.xy, angle * 2), o.z), r);
                s[3] = DistSphere(p, float3(Rotate2d(o.xy, angle * 3), o.z), r);
                s[4] = DistSphere(p, float3(Rotate2d(o.xy, angle * 4), o.z), r);
                s[5] = DistSphere(p, float3(Rotate2d(o.xy, angle * 5), o.z), r);
                s[6] = DistSphere(p, float3(Rotate2d(o.xy, angle * 6), o.z), r);
                s[7] = DistSphere(p, float3(Rotate2d(o.xy, angle * 7), o.z), r);


                float d= smoothMin(s[0], s[1], k);

                [unroll]
                for (int n=2; n<N; ++n)
                {
                    d = smoothMin(d, s[n], k);
                }
                return d;
            }

			float DistFunction(float3 p) {
                float d = DistPondeRing(p);
                return d;
			}

			float3 GetNormal(float3 p)
			{
				float d = 0.0001;
				return normalize(float3(
					DistFunction(p + float3(d, 0.0, 0.0)) - DistFunction(p + float3(-d, 0.0, 0.0)),
					DistFunction(p + float3(0.0, d, 0.0)) - DistFunction(p + float3(0.0, -d, 0.0)),
					DistFunction(p + float3(0.0, 0.0, d)) - DistFunction(p + float3(0.0, 0.0, -d))
				));
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
				}
				p = ro + rd * t;
				float4 col = _Color;

                if (d > _MinDist) discard;

                // float3 normal = GetNormal(p);
                // float3 lightdir = normalize(mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz);//ローカル座標で計算しているので、ディレクショナルライトの角度もローカル座標にする
                // float NdotL = max(0, dot(normal, lightdir));//ランバート反射を計算
                // col = float4(float3(1, 1, 1) * NdotL, 1) * col;//描画

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