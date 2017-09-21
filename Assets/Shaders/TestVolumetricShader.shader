// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Playground/TestVolumetricShader"
{
	Properties
	{
		//_MainTex ("Texture", 2D) = "white" {}
		_Radius("Radius", float) = 1
		_Centre("Centre", float) = 0
	
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" }
		//LOD 100

		Pass
		{
			Blend SrcAlpha One

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			#define STEPS 64
			#define STEP_SIZE 0.01

			float _Centre;
			float _Radius;

			struct appdata
			{
				float4 vertex : POSITION;
				//float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				//float2 uv : TEXCOORD0;
				//UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float3 wPos : TEXCOORD1;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
			}


			bool sphereHit(float3 p)
			{
				return distance(p,_Centre) < _Radius;
			}

			bool rayMarchHit(float3 position, float3 direction)
			{
				for (int i = 0; i < STEPS; i++)
				{
					if (sphereHit(position))
					{
					return true;
					}
					position += direction * STEP_SIZE;
				}
				return false;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float3 worldPosition = i.wPos;
				float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);

				if (rayMarchHit(worldPosition, viewDirection))
				{
					return fixed4(1,0,0,1);
				}
				else
				{
					return fixed4(1,1,1,1);
				}

				// sample the texture
				//fixed4 col = tex2D(_MainTex, i.uv);
				// apply fog
				//UNITY_APPLY_FOG(i.fogCoord, col);
				//return col;
			}
			ENDCG
		}
	}
}
