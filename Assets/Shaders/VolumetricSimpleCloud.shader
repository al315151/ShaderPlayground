Shader "Playground/VolumetricSimpleCloud"
{
	Properties
	{
		//[Header("SIMPLE CLOUD VARIABLES")]
	    _Iterations("Iterations", Range (0,200)) = 100
		_ViewDistance("View Distance", Range (0,10)) = 2
		//==linea propuesta
		_SkyColor ("Sky Color", Color) = (0.176, 0.478, 0.871, 0)
		_CloudColor("Cloud Color", Color) = (1,1,1,1)
		_CloudDensity("Cloud Density", Range (0,1)) = 0.5

		//The longer your view distance is, the more steps are required.
		//The smaller your clouds are, the bigger a render target is needed.

		_AlphaCutOff("Alpha Cutoff", Range (0,1)) = 0.8
		_DenseCloudsActive("Dense Clouds [ACTIVE: 1]", Range(0, 1)) = 1
		_LightCloudsActive("Light Clouds [ACTIVE: 1]", Range (0,1)) = 1
		_AnimationActive("Animation [ACTIVE: 1]", Range (0,1)) = 1

		_CloudSize("Cloud Size", Range (0,16)) = 0.5 // De normal es hasta 8, pero para tamanos pequenos...
		_CloudSpeed ("Cloud Speed", Range (0, 0.25)) = 0.1


		//[Header("VOLUMETRIC RENDERING VARIABLES")]

			_Radius("Radius", float) = 1
			_Centre("Centre", float) = 0
			_SpecularPower("Specular Power", float) = 1
			_Gloss("Gloss", float) = 1
			_MinDistance("Raymarching Minimum Distance" ,Range (-0.05, 0.5)) = 0.01 

	}
	SubShader
	{
		Tags {"Queue" = "Transparent" "RenderType" = "Transparent"}
		LOD 200

		Pass
		{
			Cull Off
			Lighting On
			Blend SrcAlpha One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag Lambert alpha:fade

			#include "Lighting.cginc"
			#include "UnityCG.cginc"

			#define STEPS 64
			#define STEP_SIZE 0.01

			//== VARIABLES DE ILUMINACION VOL.RENDERING ==
			float _Centre;
			float _Radius;
			float _SpecularPower;
			float _Gloss;
			float _MinDistance;

			//=== VARIABLES DE NUBES ============
			//Variables globales
			sampler2D _NoiseOffsets;
			float3 _CamPos;
			float3 _CamRight;
			float3 _CamUp;
			float3 _CamForward;
			float4 _AspectRatio;
			float4 _FieldOfView;

			float _AlphaCutOff;
			float _DenseCloudsActive;
			float _LightCloudsActive;
			float _AnimationActive;
			float _CloudSize;
			float _CloudSpeed;
			float _BlurAmount;

			//Variables locales
			int _Iterations;
			float3 _SkyColor;
			float4 _CloudColor;
			float _ViewDistance;
			float _CloudDensity;

			//== Funciones básicas para el shader: obtenemos los datos que queremos para usarlos luego
			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 wPos : TEXCOORD1;
				float4 color : COLOR;
			};

			v2f vert (appdata_base v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos (v.vertex);
				o.uv = v.texcoord;
				o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.color = EncodeFloatRGBA(v.vertex);
				return o;
			}

			///========== PARTE DEL CODIGO: RUIDO PARA COLOR DE NUBES
			//== Funcion de ruido de Inigo Quilez https://www.shadertoy.com/view/4sfGzS
			float noise (float3 x)
			{
				x*= _CloudSize; // El valor inicial era 4.0 ==> 
						 //A más pequeño el valor, más pequeñas y dispersas las nubes ^^
				// Obteniendo valor aleatorio entre 1 y 256 usando la textura de _NoiseOffsets y la posicion (x).
				float3 p = floor(x);
				float3 f = frac (x);
				f = f * f * (3.0 - 2.0 * f);
				float2 uv = (p.xy + float2(37.0, 17.0) * p.z) + f.xy;
				float2 rg = tex2D(_NoiseOffsets, (uv + 0.5) / 256.0).yx;
				return lerp(rg.x, rg.y, f.z);
			}

			//A más octavas, mas detalle tendremos en el ruido.
			float fbm (float3 pos, int octaves)
			{
				float f = 0.0;
				for (int i = 0; i < octaves; i++)
				{
					f += noise(pos) / pow(2, i + 1);
					pos *= 2.01;
				}
				f /= 1 - 1 / pow (2, octaves + 1);
				return f;
			}

			fixed4 colorSubstraction (float3 initialColor)
			{
			//Retocar si queremos que haya huecos, tratamos de solucionarlo con cambio de colores y au
					float alphaThreshold = _AlphaCutOff / 50;
					fixed3 finalColor = initialColor;
					
					//Si no es un color cercano al blanco, lo quitamos.
					if (!(finalColor.r > _AlphaCutOff && finalColor.g > _AlphaCutOff && finalColor.b > _AlphaCutOff)) 
					{
						if ( abs(_AlphaCutOff - finalColor.r) < alphaThreshold)
						{
							return (finalColor, abs(_AlphaCutOff - finalColor.r) * alphaThreshold);

							//TEST RETURN
							//return fixed4 (1,0,0,1);
						}
						//Si es un color cercano al blanco, y cercano al límite, lo pintamos distinto.
						//discard;
					}
					return fixed4(finalColor, 1);
			}

			//======== PARTE DE VOLUMETRIC RENDERING: REFLEXION ESPECULAR
			float sphereDistance(float3 p)
			{
				return distance (p, _Centre) - _Radius;
			}
			 float cloudDistance(float3 cloudPos, float3 cameraPos)
			{
				return distance (cloudPos, cameraPos);
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
				//float3 n = normal(p);
				//return simpleLambert(n);
				//return reflectiveLambert(n);
				return reflectiveLambert(newViewDirection);
			}

			fixed4 distanceAidedRayMarch (float3 position, float3 direction, fixed4 preRender)
			{
				for (int i = 0; i < STEPS; i++)
				{
					float distance = cloudDistance(position,  _WorldSpaceCameraPos);
					if (distance < _MinDistance)
					{
						return renderSurface(position) * preRender;
					}

					position += distance * direction;

				}
				return 0;
			}

			//===============FIN PARTE RENDERIZADO VOLUMETRICO
			
			fixed4 frag (v2f i) : SV_Target
			{
				float2 uv = (i.uv - 0.5) * _FieldOfView;
				uv.x *= _AspectRatio;

				//float3 pos = _CamPos * 0.4;
				float4 currentTime = _Time;
				if (_AnimationActive != 1) 
					{ currentTime = (0,0,0,0);}
				float3 pos = i.wPos * 0.001  - currentTime * _CloudSpeed;
				float3 ray = _CamUp * uv.y + _CamRight * uv.x + _CamForward;

				float3 p = pos;
				float density = 0;
				float denseClouds = 0;
				float lightClouds = 0;

				for (float i = 0; i < _Iterations; i++)
				{
					float f = i / _Iterations;

					float alpha = smoothstep(0, _Iterations * 0.2, i) * (1 - f) * (1 - f);

					if (_DenseCloudsActive == 1)
					{
						 denseClouds = smoothstep(_CloudDensity, 0.75, fbm(p, 2)); //el segundo valor pasado a fbm era 5.
					}
					if (_LightCloudsActive == 1)
					{
						//El primer valor del smoothstep es -0.2.
						// el segundo valor pasado a fbm era 2.
						lightClouds = (smoothstep(_CloudDensity, 1.2, fbm (p * 2, 3)) - 0.5) * 0.5; 
					}

					density += (lightClouds + denseClouds) * alpha;
					p = pos + ray * f * _ViewDistance;

				}

			
				float3 color = _SkyColor + (_CloudColor.rgb - 0.5) * (density / _Iterations) * 20 * _CloudColor.a;

				//Aqui elimino fragmentos... ¿NO DEERIA????
				fixed4 substractedClouds = colorSubstraction(color);

				//Una vez calculo las nubes, hago el renderizado volumetrico.		

				float3 viewDirection = normalize(pos - _WorldSpaceCameraPos);
				newViewDirection = viewDirection;
				return distanceAidedRayMarch(pos, viewDirection, substractedClouds);

			}
			ENDCG
		}
	}
}
