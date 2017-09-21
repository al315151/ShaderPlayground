// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Playground/RayMarching"
{
	Properties
	{
		_Radius("Radius", float) = 1
		_Centre("Centre", float) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
						
			#include "UnityCG.cginc"

			#define STEPS 64
			#define STEP_SIZE 0.01
			#define MIN_DISTANCE 0.01

			float _Centre;
			float _Radius;


			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 wPos : TEXCOORD1;
			};



			//============== PARTE 1 DEL TUTORIAL==============
			bool sphereHit(float3 p)
			{
				return distance(p,_Centre) < _Radius;
			}

			fixed4 raymarch(float3 position, float3 direction)
			{
				for (int i = 0; i < STEPS; i++)
				{
					if (sphereHit(position))
					{
						return fixed4(1,0,0,1);
					}

					position += direction * STEP_SIZE;
				}

				return (0,0,0,1);

			}
			//======== FIN DE PARTE 1 ================

			//=========DISTANCE AIDED RAYMARCHING ===========

			float sphereDistance(float3 p)
			{
				return distance (p, _Centre) - _Radius;
			}

			fixed4 distanceAidedRayMarch (float3 position, float3 direction)
			{
				for (int i = 0; i < STEPS; i++)
				{
					float distance = sphereDistance(position);
					if (distance < MIN_DISTANCE)
					{
						return i / (float) STEPS;
					}

					position += distance * direction;

				}
				return 0;
			}


			//=========FIN DE DISTANCE AIDED RAYMARCHING

			v2f vert (appdata_full v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float3 worldPosition = i.wPos;
				float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);
				return distanceAidedRayMarch(worldPosition, viewDirection);

			}
			ENDCG
		}
	}
}
