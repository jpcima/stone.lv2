declare name "Stone Phaser";
declare author "Jean Pierre Cimalando";
declare version "1.2.1";
declare license "CC0-1.0";

// Référence :
//     Kiiski, R., Esqueda, F., & Välimäki, V. (2016).
//     Time-variant gray-box modeling of a phaser pedal.
//     In 19th International Conference on Digital Audio Effects (DAFx-16).

import("stdfaust.lib");

/////////////
// Control //
/////////////

bypass = checkbox("[0] Bypass");
lfotype = checkbox("[1] Color");
lf = hslider("[2] LFO frequency [unit:Hz]"/*[scale:log]*/, 0.2, 0.01, 5., 0.01) : si.smoo;
fb = hslider("[3] Feedback depth", 0.75, 0., 0.9, 0.01) : si.smoo;
fbHf = hslider("[4] Feedback bass cut [unit:Hz]"/*[scale:log]*/, 500., 10., 5000., 1.) : si.smoo;
dw = hslider("[5] Dry/wet mix [unit:%]", 50, 0, 100, 1) : *(0.01);
w = sin(dw*(ma.PI/2)) : si.smoo;
d = cos(dw*(ma.PI/2)) : si.smoo;
ph = hslider("[6] Stereo phase [unit:deg]", 45., 0., 359., 1.) : /(360.) : si.smoo;

//////////////////////////
// All-pass filter unit //
//////////////////////////

allpass1(f) = fi.iir((a,1.),(a)) with {
  a = -1.+2.*ma.PI*f/ma.SR;
};

//////////////////////
// High-pass filter //
//////////////////////

highpass1(f) = fi.iir((0.5*(1.+p), -0.5*(1.+p)), (-p)) with {
  p = exp(-2.*ma.PI*f/ma.SR);
};

//////////////////////
// Low-pass filter //
//////////////////////

lowpass1(f) = fi.iir((1.-p), (-p)) with {
  p = exp(-2.*ma.PI*f/ma.SR);
};

//////////
// LFOs //
//////////

lfoTriangle(pos, y1, y2) = val*(y2-y1)+y1 with {
  val = 1.-abs(2.*pos-1.);
};

lfoRectifiedSine(pos, y1, y2) = val*(y2-y1)+y1 with {
  val = rsin(pos);
};

lfoAnalogTriangle(roundness, pos, y1, y2) = val*(y2-y1)+y1 with {
  val = sineTri(roundness, pos);
};

////////////
// Phaser //
////////////

mono_phaser(x, lfo_pos) = ba.if(bypass, x, dry + wet) with {
  dry = x*d;
  wet = (x <: highpass1(33.0) : (+:a1:a2:a3:a4)~feedback)*w;

  feedback = highpass1(fbHf) : *(ba.if(lfotype, fb, 0.1*fb));

  modFreq = ba.midikey2hz(ba.if(lfotype,
                                lfoAnalogTriangle(0.95, lfo_pos, ba.hz2midikey(80.), ba.hz2midikey(2200.)),
                                lfoAnalogTriangle(0.95, lfo_pos, ba.hz2midikey(300.), ba.hz2midikey(6000.))));

  a1 = allpass1(modFreq);
  a2 = allpass1(modFreq);
  a3 = allpass1(modFreq);
  a4 = allpass1(modFreq);
};

stereo_phaser(x1, x2, lfo_pos) = mono_phaser(x1, lfo_pos), mono_phaser(x2, lfo_pos2) with {
  lfo_pos2 = wrap(lfo_pos + ph);
  wrap(p) = p-float(int(p));
};

/////////////
// Utility //
/////////////

lerp(tab, pos, size) = (tab(i1), tab(i2)) : si.interpolate(mu) with {
  fracIndex = pos*size;
  i1 = int(fracIndex);
  i2 = (i1+1)%size;
  mu = fracIndex-float(i1);
};

rsin(pos) = lerp(tab, pos, ts) with {
  ts = 128;
  tab(i) = rdtable(ts, abs(os.sinwaveform(ts)), i);
};

sineTriWaveform(roundness, tablesize) = 1.-sin(2.*ba.if(x<0.5, x, 1.-x)*asin(a))/a with {
  a = max(0., min(1., roundness * 0.5 + 0.5));
  x = wrap(float(ba.time)/float(tablesize));
  wrap(p) = p-float(int(p));
};

sineTri(roundness, pos) = lerp(tab, pos, ts) with {
  ts = 128;
  tab(i) = rdtable(ts, sineTriWaveform(roundness, ts), i);
};

/*
  # Gnuplot code of the sineTri function
  sineTri(r, x)=sineTri_(r, wrap(x+0.5))
  sineTri_(r, x)=1.-sin(((x<0.5)?x:(1.-x))*2.*asin(r))/r
  wrap(x)=x-floor(x)
  set xrange [0:1]
  plot(sineTri(0.99, x))
*/

//////////
// Main //
//////////

process_mono(x) = mono_phaser(x, os.lf_sawpos(lf));
process_stereo(x1, x2) = stereo_phaser(x1, x2, os.lf_sawpos(lf));
process = process_mono;
