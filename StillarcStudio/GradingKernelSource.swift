// Shared source for modern Metal and the portable Core Image compatibility path.
enum GradingKernelSource {
    static let code = """
    float encodeComponent(float x) { return x <= 0.0031308 ? x * 12.92 : 1.055 * pow(max(x,0.0),1.0/2.4)-0.055; }
    float decodeComponent(float x) { return x <= 0.04045 ? x / 12.92 : pow((x+0.055)/1.055,2.4); }
    float rangeWeight(float hue, float center, float leftWidth, float rightWidth) {
        float distance = mod(hue-center+9.0,6.0)-3.0;
        float width = distance < 0.0 ? leftWidth : rightWidth;
        return 1.0-smoothstep(0.0,width,abs(distance));
    }
    vec2 warpChange(float hue,float saturation,vec4 point,vec2 reach) {
        float h=abs(mod(hue-point.x+9.0,6.0)-3.0)/reach.x;
        float s=abs(saturation-point.y)/reach.y;
        float weight=1.0-smoothstep(0.0,1.0,sqrt(h*h+s*s));
        return point.zw*weight;
    }
    vec3 mixChannels(vec3 rgb, vec4 rowR, vec4 rowG, vec4 rowB, float monochrome) {
        vec3 mixed = vec3(dot(rgb,rowR.xyz)+rowR.w,dot(rgb,rowG.xyz)+rowG.w,dot(rgb,rowB.xyz)+rowB.w);
        if (monochrome > 0.5) mixed = vec3(dot(mixed,vec3(0.2126,0.7152,0.0722)));
        return mixed;
    }
    float gamutLimit(float luminance, float chroma) {
        if (chroma > 0.000001) return (1.0-luminance)/chroma;
        if (chroma < -0.000001) return luminance/(-chroma);
        return 1000000.0;
    }
    kernel vec4 studioSelective(__sample pixel, vec3 red, vec3 orange, vec3 yellow, vec3 green,
                                vec3 aqua, vec3 blue, vec3 purple, vec3 magenta, float previewRange,
                                vec4 shadows, vec4 midtones, vec4 highlights, vec4 globalWheel, vec2 toneControl,
                                vec4 rowR, vec4 rowG, vec4 rowB, vec4 gradingControl, float selectiveActive,
                                vec4 warp0,vec2 reach0,vec4 warp1,vec2 reach1,vec4 warp2,vec2 reach2,vec4 warp3,vec2 reach3,float warpActive) {
        vec4 original = unpremultiply(pixel);
        // A mixer-only edit stays in linear light: no transfer functions or hue work.
        if (warpActive < 0.5 && selectiveActive < 0.5 && gradingControl.x < 0.5 && previewRange < -0.5) {
            return premultiply(vec4(mixChannels(original.rgb,rowR,rowG,rowB,gradingControl.z),original.a));
        }
        vec3 encoded = vec3(encodeComponent(original.r),encodeComponent(original.g),encodeComponent(original.b));
        if (warpActive > 0.5 || selectiveActive > 0.5 || previewRange > -0.5) {
        float low = min(encoded.r,min(encoded.g,encoded.b));
        float high = max(encoded.r,max(encoded.g,encoded.b));
        float offset = min(0.0,low);
        float span = max(1.0,high-offset);
        vec3 rgb = (encoded-vec3(offset))/span;
        float maximum = (high-offset)/span;
        float minimum = (low-offset)/span;
        float chroma = maximum-minimum;
        float hue = 0.0;
        if (chroma > 0.00001) {
            if (maximum == rgb.r) hue = (rgb.g-rgb.b)/chroma;
            else if (maximum == rgb.g) hue = 2.0+(rgb.b-rgb.r)/chroma;
            else hue = 4.0+(rgb.r-rgb.g)/chroma;
            hue = mod(hue+6.0,6.0);
        }
        float w0 = rangeWeight(hue,0.0,1.0,0.5);
        float w1 = rangeWeight(hue,0.5,0.5,0.5);
        float w2 = rangeWeight(hue,1.0,0.5,1.0);
        float w3 = rangeWeight(hue,2.0,1.0,1.0);
        float w4 = rangeWeight(hue,3.0,1.0,1.0);
        float w5 = rangeWeight(hue,4.0,1.0,0.5);
        float w6 = rangeWeight(hue,4.5,0.5,0.5);
        float w7 = rangeWeight(hue,5.0,0.5,1.0);
        float chromaGate = smoothstep(0.0,0.08,chroma);
        vec3 change = (red*w0+orange*w1+yellow*w2+green*w3+aqua*w4+blue*w5+purple*w6+magenta*w7)*chromaGate;
        if (warpActive > 0.5 && previewRange < -0.5 && chroma > 0.00001) {
            float l=(maximum+minimum)*0.5;
            float s=chroma/max(0.00001,1.0-abs(2.0*l-1.0));
            vec2 delta=warpChange(hue,s,warp0,reach0)+warpChange(hue,s,warp1,reach1)+warpChange(hue,s,warp2,reach2)+warpChange(hue,s,warp3,reach3);
            change.x+=clamp(delta.x,-1.0,1.0)*chromaGate;
            // Existing mix uses multiplicative saturation; map warp's additive move into that domain.
            change.y+=clamp(delta.y,-0.5,0.5)*chromaGate/max(s,0.00001);
        }
        if (dot(abs(change),vec3(1.0)) > 0.000001 && chroma > 0.00001) {
            float lightness = (maximum+minimum)*0.5;
            float saturation = chroma/max(0.00001,1.0-abs(2.0*lightness-1.0));
            hue += change.x;
            saturation = clamp(saturation*(1.0+change.y),0.0,1.0);
            lightness = clamp(lightness+change.z*0.25,0.0,1.0);
            float adjustedChroma = (1.0-abs(2.0*lightness-1.0))*saturation;
            vec3 shape = clamp(abs(mod(vec3(hue)+vec3(0.0,4.0,2.0),6.0)-vec3(3.0))-vec3(1.0),0.0,1.0);
            encoded = (vec3(lightness)+adjustedChroma*(shape-vec3(0.5)))*span+vec3(offset);
        }
        if (previewRange > -0.5) {
            float weight = w0;
            if (previewRange > 0.5) weight = w1;
            if (previewRange > 1.5) weight = w2;
            if (previewRange > 2.5) weight = w3;
            if (previewRange > 3.5) weight = w4;
            if (previewRange > 4.5) weight = w5;
            if (previewRange > 5.5) weight = w6;
            if (previewRange > 6.5) weight = w7;
            float gray = dot(encoded,vec3(0.2126,0.7152,0.0722))*0.35;
            encoded = mix(vec3(gray),encoded,weight*chromaGate);
        } else if (dot(abs(change),vec3(1.0)) <= 0.000001 && gradingControl.x < 0.5 && gradingControl.y < 0.5) { return pixel; }
        }
        float exposure = 0.0;
        if (gradingControl.x > 0.5 && previewRange < -0.5) {
            float luminance = dot(encoded,vec3(0.2126,0.7152,0.0722));
            float tone = clamp(luminance+toneControl.x*0.25,0.0,1.0);
            float spread = (0.25+toneControl.y*0.20)*1.5;
            float shadowWeight = 1.0-smoothstep(0.10,0.10+spread,tone);
            float highlightWeight = smoothstep(0.90-spread,0.90,tone);
            float midtoneWeight = max(0.0,1.0-shadowWeight-highlightWeight);
            vec3 tint = shadows.xyz*shadowWeight+midtones.xyz*midtoneWeight+highlights.xyz*highlightWeight+globalWheel.xyz;
            encoded += tint;
            if (gradingControl.w > 0.5 && dot(abs(tint),vec3(1.0)) > 0.000001 && luminance >= 0.0 && luminance <= 1.0) {
                // Keep the original encoded luminance and compress chroma before a channel clips.
                encoded += vec3(luminance-dot(encoded,vec3(0.2126,0.7152,0.0722)));
                vec3 chromaVector = encoded-vec3(luminance);
                float compression = clamp(min(gamutLimit(luminance,chromaVector.r),min(gamutLimit(luminance,chromaVector.g),gamutLimit(luminance,chromaVector.b))),0.0,1.0);
                encoded = vec3(luminance)+chromaVector*compression;
            }
            exposure = shadows.w*shadowWeight+midtones.w*midtoneWeight+highlights.w*highlightWeight+globalWheel.w;
        }
        vec3 linear = vec3(decodeComponent(encoded.r),decodeComponent(encoded.g),decodeComponent(encoded.b))*exp2(exposure);
        if (gradingControl.y > 0.5 && previewRange < -0.5) linear = mixChannels(linear,rowR,rowG,rowB,gradingControl.z);
        return premultiply(vec4(linear,original.a));
    }
    """
}
