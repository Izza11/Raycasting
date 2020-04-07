#version 430

layout(location = 1) uniform int pass;
layout(location = 2) uniform sampler2D backfaces_tex;
layout(location = 3) uniform int mode = 0;
layout(location = 6) uniform float time;
layout(location = 7) uniform vec4 slider;
layout(location = 8) uniform int scene = 0;
layout(location = 9) uniform float atime = 0;
layout(location = 10) uniform bool ambO;


layout(location = 0) out vec4 fragcolor;  
         
in vec3 vpos;  

//forward function declarations
vec4 raytracedcolor(vec3 rayStart, vec3 rayStop);
vec4 lighting(vec3 pos, vec3 rayDir);
float distToShape(vec3 pos);
vec3 normal(vec3 pos);
float combineobjs(vec3 pos);

void main(void)
{   
	if(pass == 1)
	{
		fragcolor = vec4((vpos), 1.0); //write cube positions to texture
	}
	else if(pass == 2) 
	{
		if(mode==0) // for debugging: show backface colors
		{
			fragcolor = texelFetch(backfaces_tex, ivec2(gl_FragCoord), 0);
			return;
		}
		else if(mode==1) // for debugging: show frontface colors
		{
			fragcolor = vec4((vpos), 1.0);
			return;
		}
		else // raycast
		{
			vec3 rayStart = vpos.xyz;
			vec3 rayStop = texelFetch(backfaces_tex, ivec2(gl_FragCoord.xy), 0).xyz;
			fragcolor = raytracedcolor(rayStart, rayStop);

			

			if(fragcolor.a==0.0) {
				float len = abs(rayStart.z - rayStop.z) / 2.0; 

				float a = smoothstep(len-0.2, len+0.6, rayStop.z);
				vec4 green = vec4(0.0, 0.8, 0.5, 1.0);
				vec4 blue = vec4(0.1, 0.4, 0.6, 1.0);
				fragcolor = mix (green, blue, a);
			}
		}
	}
}

//shape function declarations
float sdSphere( vec3 p, float s );
float DE_julia(vec3 p);
float opRep(vec3 p, vec3 c);
float sdPlane( vec3 p, vec4 n );
float sdBox( vec3 p, vec3 b );
float sdEllipsoid( in vec3 p, in vec3 r );
float udRoundBox( vec3 p, vec3 b, float r );
float sdTorus( vec3 p, vec2 t );


// trace rays until they intersect the surface
vec4 raytracedcolor(vec3 rayStart, vec3 rayStop)
{
	vec4 color = vec4(0.0, 0.0, 0.0, 0.0);
	const int MaxSamples = 1000;

	vec3 rayDir = normalize(rayStop-rayStart);
	float travel = distance(rayStop, rayStart);
	float stepSize = travel/MaxSamples;
	vec3 pos = rayStart;
	vec3 step = rayDir*stepSize;
	
	for (int i=0; i < MaxSamples && travel > 0.0; ++i, pos += step, travel -= stepSize)
	{
		float dist = distToShape(pos);

		stepSize = dist;
		step = rayDir*stepSize;
		
		if(dist<=0.001)
		{
			color = lighting(pos, rayDir);
			return color;
		}	
	}
	return color;
}

//distance to the shape we are drawing
float distToShape(vec3 pos)
{
	if(scene == 0)
	{
		const float radius = 0.4;
		return opRep(pos, vec3(radius*1.5, radius*1.5, radius*1.5));
		//return sdSphere(pos, radius);
	}

	if(scene == 1)
	{
		return (1.0/1.2)*DE_julia(1.2*pos);
	}
	if(scene == 3)
	{
		// new scene
		//return sdPlane( pos, vec4(0.0, 0.0, 1.0, 1.0) );
		return combineobjs(pos);

	}
}

float sdPlane( vec3 p, vec4 n )
{
  // n must be normalized
  return dot(p,n.xyz) + n.w;
}

float shadow (vec3 ro, vec3 rd, float mint, float maxt, float k)
{
	//rd = normalize(rd-ro);
	float pf = 1.0;      // penumbra factor
	for (float t = mint; t < maxt;) 
	{
		float h = distToShape(ro + rd*t);
		if (h < 0.001)
			return 0.0;
		
		t += h;
		pf = min(pf, k * h / t);
	
	}
	return pf;

}

float ambientOcclusion(vec3 pos, vec3 normal)
{
	float s = 2.0;
	float k = 1.0;
	float kmax = 5.0;
	float distAlongNorm = 0.0;
	float signedDist = 0.0;
	float occlusion = 0.0;

	while (k < kmax) {
		distAlongNorm = length(normal*k);
		signedDist = distToShape(pos + (normal*k));
		occlusion = (1/pow(2,k))*(distAlongNorm - signedDist);
		k++;		
	}

	return 1.0 - clamp(s*occlusion, 0.0, 1.0);

}

//Compute lighting on the raycast surface using Phong lighting model
vec4 lighting(vec3 pos, vec3 rayDir)
{
	const vec3 light = vec3(0.577, 0.577, 0.577); //light direction
	const vec4 ambient_color = vec4(0.071, 0.188, 0.294, 1.0);
	const vec4 diffuse_color = vec4(0.722, 0.627, 0.545, 1.0);
	const vec4 spec_color = vec4(0.120, 0.120, 0.060, 1.0);

	vec3 n = normal(pos);
	vec3 v = -rayDir;
	vec3 r = reflect(-light, n);

	//float shad = 1.0;
	//float shad = shadow(pos, light, 0.01, length(light-pos), 2.0);
	float shad = shadow(pos, light, 0.01, 5.0, 2.0);
	float ac = ambientOcclusion(pos, n);

	if (ambO) {
		return ac*ambient_color + shad*(diffuse_color*max(0.0, dot(n, light)) + spec_color*pow(max(0.0, dot(r, v)), 15.0));	
	} else {
		return ambient_color + shad*(diffuse_color*max(0.0, dot(n, light)) + spec_color*pow(max(0.0, dot(r, v)), 15.0));	
	}
	
}


float opRep(vec3 p, vec3 c)
{	
	vec3 q = mod(p,c)-0.5*c;
	return sdSphere(q, c.x/3);   
}


// shape function definitions
                
float sdSphere( vec3 p, float s )
{
	return length(p)-s;
}


float DE_julia(vec3 pos)
{
	const vec4 c = slider;
	vec4 z = vec4(pos, 0.0);
	vec4 nz;
	float md2 = 1.0;
	float mz2 = dot(z,z);

	for(int i=0;i<18;i++)
	{
		// |dz|^2 -> 4*|dz|^2
		md2 *= 4.0*mz2;
		// z -> z2 + c
		nz.x = sin(time)*z.x*z.x-dot(z.yzw,z.yzw);
		nz.yzw = 2.0*z.x*z.yzw;
		z = nz + c;
		mz2 = dot(z,z);

		if(mz2 > 22.0) //Bailout
		{
			break;
		}
	}
	return 0.25*sqrt(mz2/md2)*log(mz2);
}

//normal vector of the shape we are drawing.
//Estimated as the gradient of the signed distance function.
vec3 normal(vec3 pos)
{
	const float h = 0.001;
	const vec3 Xh = vec3(h, 0.0, 0.0);	
	const vec3 Yh = vec3(0.0, h, 0.0);	
	const vec3 Zh = vec3(0.0, 0.0, h);	

	return normalize(vec3(distToShape(pos+Xh)-distToShape(pos-Xh), distToShape(pos+Yh)-distToShape(pos-Yh), distToShape(pos+Zh)-distToShape(pos-Zh)));
}

// For more distance functions see
// http://iquilezles.org/www/articles/distfunctions/distfunctions.htm

// Soft shadows
// http://www.iquilezles.org/www/articles/rmshadows/rmshadows.htm

// WebGL example and a simple ambient occlusion approximation
// https://www.shadertoy.com/view/Xds3zN


float opU( float d1, float d2)
{
	return min(d1, d2);
}

float sdBox( vec3 p, vec3 b )
{
    vec3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdEllipsoid( in vec3 p, in vec3 r )
{
    return (length( p/r ) - 1.0) * min(min(r.x,r.y),r.z);
}

float udRoundBox( vec3 p, vec3 b, float r )
{
    return length(max(abs(p)-b,0.0))-r;
}

float sdTorus( vec3 p, vec2 t )
{
    return length( vec2(length(p.xz)-t.x,p.y) )-t.y;
}

mat3 rotationMat(vec3 v, float angle)
{
	float c = cos(angle);
	float s = sin(angle);
	return mat3(c + (1.0 - c) * v.x * v.x, (1.0 - c) * v.x * v.y - s * v.z, (1.0 - c) * v.x * v.z + s * v.y,
                (1.0 - c) * v.x * v.y + s * v.z, c + (1.0 - c) * v.y * v.y, (1.0 - c) * v.y * v.z - s * v.x,
                (1.0 - c) * v.x * v.z - s * v.y, (1.0 - c) * v.y * v.z + s * v.x, c + (1.0 - c) * v.z * v.z);
}

float hash( float n )
{
    return fract(sin(n)*1751.5453);
}

float wings(vec3 p)
{
	//float atime = 90; time+12.0;
    vec2 o = floor( 0.5 + p.xz/50.0  );
    float o1 = hash( o.x*57.0 + 12.1234*o.y );
    float f = sin( 1.0 + (2.0*atime + 31.2*o1)/2.0 );
    p.y -= 2.0*(atime + f*f);
    p = mod( (p+25.0)/50.0, 1.0 )*50.0-25.0;
    //if( abs(o.x)>0.5 )  p += (-1.0 + 2.0*o1)*10.0;

	vec3 axis = normalize(vec3(0.3, -1.0, -0.4));
	mat3 roma = rotationMat(axis, 0.34 + 0.7*sin(31.2*o1+2.0*atime + 0.01*p.z) );
	for( int i=0; i<16; i++ )
	{
        p = roma*abs(p);
        p.y-= 1.0;
    }
	float d = length(p*vec3(1.0,0.1,1.0))-0.75;
    float h = 0.5 + p.z;
    return min( d, h );
}

float combineobjs(vec3 pos)
{	
	float res = opU( sdPlane(pos, vec4(0.0, 0.0, 1.0, 1.0)), sdSphere(pos-vec3(0.0, 0.25, 0.0), 0.4) );
	res = opU(res, wings(pos));
	return res;
}






