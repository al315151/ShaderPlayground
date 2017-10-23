Shader "Playground/SurfaceShading"
{
	Properties
	{
			_Radius("Radius", float) = 1
			_Centre("Centre", float) = 0
			_SpecularPower("Specular Power", float) = 1
			_Gloss("Gloss", float) = 1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Blend SrcAlpha One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Lighting.cginc"
			#include "UnityCG.cginc"

			#define STEPS 64
			#define STEP_SIZE 0.01
			#define MIN_DISTANCE 0.01

			float _Centre;
			float _Radius;
			float _SpecularPower;
			float _Gloss;

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 wPos : TEXCOORD1;
			};


			//========= INICIO TUTORIAL PARTE 3 ============
			float sphereDistance(float3 p)
			{
				return distance (p, _Centre) - _Radius;
			}


			float3 normal (float3 p)
			{
				const float eps = 0.01;

				return normalize(float3
								(
								sphereDistance(p + float3(eps, 0, 0)) - sphereDistance(p - float3(eps, 0, 0)), 
								sphereDistance(p + float3(0, eps, 0)) - sphereDistance(p - float3(0, eps, 0)),
								sphereDistance(p + float3(0, 0, eps)) - sphereDistance(p - float3(0, 0, eps))
								)
								);

			}


			// === SIN REFLEXION ESPECULAR ======
			fixed4 simpleLambert(fixed3 normal)
			{
				fixed3 lightDir = _WorldSpaceLightPos0.xyz;
				fixed3 lightCol = _LightColor0.rgb;

				fixed NdotL = max(dot(normal, lightDir), 0);
				fixed4 c;

				c.rgb = lightCol * lightCol * NdotL;
				c.a = 1;

				return c;

			}
			//=== FIN SIN REFLEXION ESPECULAR =====

			//===CON REFLEXION ESPECULAR ====

			float3 newViewDirection;

			fixed4 reflectiveLambert(fixed3 normal)
			{
			    fixed3 lightDir = _WorldSpaceLightPos0.xyz;
				fixed3 lightCol = _LightColor0.rgb;

				//specular
				 fixed3 h = (lightDir - newViewDirection) / 2;
				 fixed s = pow(dot(normal, h), _SpecularPower) * _Gloss;

				fixed NdotL = max(dot(normal, lightDir), 0);
				fixed4 c;

				c.rgb = lightCol * lightCol * NdotL + s;
				c.a = 1;

				return c;
			}

				fixed4 renderSurface(float3 p)
			{
				float3 n = normal(p);
				//return simpleLambert(n);
				return reflectiveLambert(n);
			}

			fixed4 distanceAidedRayMarch (float3 position, float3 direction)
			{
				for (int i = 0; i < STEPS; i++)
				{
					float distance = sphereDistance(position);
					if (distance < MIN_DISTANCE)
					{
						return renderSurface(position);
					}

					position += distance * direction;

				}
				return 0;
			}

		


			 //=============FIN TUTORIAL PARTE 3 ===================
			v2f vert (appdata v)
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
				newViewDirection = viewDirection;
				return distanceAidedRayMarch(worldPosition, viewDirection);
			}
			ENDCG
		}
	}
}
