uniform float4 lowland_fog_params;
uniform float4 eye_direction;
uniform float3x4 m_v2w;
uniform float4 fog_shaders_values;

#ifndef FOG_H
#define FOG_H
#include "common.hlsli"

static const float min_dist = 0.f; //-' decommissioned

static const float3x3 rotate_y = float3x3
(
    cos(timers.y * 0.75), 0, sin(timers.y * 0.75),
    0,                    1, 0,
    -sin(timers.y * 0.75), 0, cos(timers.y * 0.75)
);

float3 random3(float3 c)
{
    float4 seed = float4(0.0, c) * float4(123.456, 456.789, 789.123, 321.654);
    seed = frac(sin(seed) * 43758.5453);
    return (seed.xyz * 2.0 - 1.0);
}

float noise(float3 p)
{
    float3 i = floor(p);
    float3 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);

    float3 rand1 = random3(i);
    float3 rand2 = random3(i + float3(1.0, 0.0, 0.0));
    float3 rand3 = random3(i + float3(0.0, 1.0, 0.0));
    float3 rand4 = random3(i + float3(0.0, 0.0, 1.0));

    float a = dot(rand1, f);
    float b = dot(rand2, f - float3(1.0, 0.0, 0.0));
    float c = dot(rand3, f - float3(0.0, 1.0, 0.0));
    float d = dot(rand4, f - float3(0.0, 0.0, 1.0));

    return (a + b + c + d) * 0.5 * timers.x;
}

float smoothstep_fog_density(float distance, float min_dist, float max_dist, float density)
{
    // Calculate the percentage of distance from min_dist to max_dist
    float dist_percentage = saturate((distance - min_dist) / (max_dist - min_dist));
    
    // Smoothly interpolate the density based on the dist_percentage
    float smooth_density = smoothstep(0.0, 1.0, dist_percentage) * density;

    return smooth_density;
}

float get_height_weight(float3 P, float height_min, float height_max, float weight_min, float weight_max)
{
    float height_weight = 0.0f;
    if (P.y < height_min)
    {
        height_weight = weight_min;
    }
    else if (P.y > height_max)
    {
        height_weight = weight_max;
    }
    else
    {
        height_weight = lerp(weight_min, weight_max, (P.y - height_min) / (height_max - height_min));
    }
    return height_weight;
}

float4 get_linear_fog(float3 P)
{
    float sun_intensity = 0.05;
    
    //get distance
    float distance = length(P.xyz);

    //calculate linear fog
    float fog = saturate(distance*fog_params.w + fog_params.x);
    
    //calculate pseudoscattering!
    float sun = max(saturate(dot(-eye_direction.xyz, normalize(L_sun_dir_w.xyz))), 0);

    // final color mixing
    float3 final_color = lerp(fog_color.rgb, (L_sun_color.rgb * sun_intensity) + fog_color.rgb, smoothstep(0.3, 0.7, pow(sun, 1.5)));

    return float4(final_color.xyz,fog);
}

float4 get_height_fog(float3 P)
{
    float sun_intensity = 0.05;
    float height_weight = get_height_weight(P, 0.0f, 10.0f, 0.0f, 1.0f);
    float height = lerp(0.f, lowland_fog_params.x, height_weight);
    float density = lowland_fog_params.y;
    float max_dist = lowland_fog_params.z;    
    
    //get world position and distance!
    float3 P_world = mul(m_v2w, float4(P,1.f)).xyz;
    
    // Apply rotation
    float3 rotated_P = mul(rotate_y, P);
    
    float distance = length(rotated_P);
    
    //height falloff (workaround for hard edges)
    float falloff = max(0.0, max(height - P_world.y, height - eye_position.y));
    
    //calculate exponential fog
    float fog_density = smoothstep_fog_density(distance, min_dist, max_dist, density);
    float fog = pow(1.0f - exp(-max(0.0f, distance - min_dist) / ((max_dist - min_dist))), 2.0)*fog_density;
    
    //add second dynamic layer
    fog += (fog*0.125) * sin(timers.x*0.75 + P_world.x*0.1);
    
    //calculate pseudoscattering!
    float sun = max(saturate(dot(-eye_direction.xyz, normalize(L_sun_dir_w.xyz))), 0);
    
    float edge_dist = 0.9; // расстояние, на котором начинается рассеяние краев
    float edge_falloff = 1.5; // показатель степени для функции smoothstep
    float edge = smoothstep(0.0, 1.0, (distance - max_dist + edge_dist) / edge_dist);
    
    // final color mixing
    float3 final_color = lerp(fog_color.rgb, (L_sun_color.rgb * sun_intensity) + fog_color.rgb, smoothstep(0.3, 0.7, pow(sun, 1.5)));
    final_color.rgb = lerp(final_color.rgb, fog_color.rgb, edge * pow(edge, edge_falloff));
    
    density += noise(P) * sin(timers.x*0.75 + P_world.xyz*0.1);
    
    static float ground_fog = 1; // Added missing uniform

    return float4(final_color.xyz, saturate(fog*falloff*ground_fog));
}

float get_height_fog_sky_effect(float3 P)
{
    //our settings
    float height = lowland_fog_params.x;
    float density = lowland_fog_params.y;
    float max_dist = lowland_fog_params.z; 

    //get world position and distance!
    float3 P_world = mul(m_v2w, float4(P,1.f)).xyz; // Fixed from mul(0.f, ...)
    float distance = length(P.xyz);

    //Check if we need height fog
    //height falloff (workaround for hard edges)
    float falloff = max(0.0, max(height - P_world.y, height - eye_position.y));

    //calculate exponential fog
    float fog_density = smoothstep_fog_density(distance, min_dist, max_dist, density);
    float fog = pow(1.0f - exp(-max(0.0f, distance - min_dist) / ((max_dist - min_dist))), 2.0)*fog_density;
    
    fog += (fog*0.125) * sin(timers.x*0.75 + P_world.x*0.1);
    
    static float ground_fog = 1; // Added missing uniform

    return saturate(fog*falloff*ground_fog);
}

float get_height_fog_water(float3 P, float3 P_world)
{
    //our settings    
    int error = 1;
    
    float height = fog_shaders_values.x;
    float density = fog_shaders_values.y;
    float max_dist = fog_shaders_values.z; 

    //get world position and distance!
    float distance = length(P.xyz);

    //Check if we need height fog
    //height falloff (workaround for hard edges)
    float falloff = abs(P_world.y - height);

    //cut ugly fog!!1!
    if(P_world.y > height+0.025)
        error = 0;
    
    //calculate exponential fog
    float fog = pow(1.0f - exp(-max(0.0f, distance - min_dist) / ((max_dist - min_dist))), 2.0)*density;
    
    //add second dynamic layer
    fog += (fog*0.125) * sin(timers.x*0.75);

    static float ground_fog = 1; // Added missing uniform

    return saturate(fog*falloff*error*ground_fog);
}

float3 get_fog_color(float3 Pos)
{
    const float _distOffset = -150;  
    const float _distRange = 500;  
    const float _mul = 1.0 / _distRange;  
    const float _bias = _distOffset * _mul;  

    float3 w_pos = mul(m_v2w, float4(Pos,1.f)).xyz;

    float frag_dist = length(w_pos.xyz);  
    float3 frag_dir = w_pos.xyz / frag_dist;  
   
    float dot_fragDirSunDir = dot(-L_sun_dir_w.xyz, frag_dir); 
    float disk_size = 3;

    float FoggySunDisk = dot_fragDirSunDir;  
    {  
        FoggySunDisk = abs(FoggySunDisk);  
        FoggySunDisk *= FoggySunDisk;  
        FoggySunDisk *= saturate(frag_dist * _mul + _bias);  
        FoggySunDisk = pow(FoggySunDisk, disk_size);
    }  

    return lerp(fog_color.rgb, (dot_fragDirSunDir < 0.0f ? fog_color.rgb : L_sun_color.xyz), FoggySunDisk); 
}
#endif