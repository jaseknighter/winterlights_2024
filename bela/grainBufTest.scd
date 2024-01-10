Server.killAll;
//grainbuf test
(
var winenv=Env([0, 1, 0], [0,1], [8, -8]);
var z = Buffer.sendCollection(s, winenv.discretize, 1);
​
b = Buffer.read(s, thisProcess.nowExecutingPath.dirname++"/flora_wowless_mono.wav");
// b=Buffer.read(s,thisProcess.nowExecutingPath.dirname++"/kalimba_mono.wav");

s.queryAllNodes(queryControls: false).postln;
​
SynthDef(\buf_grain_test, { |out, gate = 1, amp = 1, sndbuf, envbuf, trigRate=10, rate=1, env_curve=\sin, rNode=nil, dur=1|
	var pan, env, freqdev, snd;


  pan = 0;//SinOsc.kr(1);
  // use mouse x to control panning
	// pan = MouseX.kr(-1, 1);
  env = EnvGen.kr(
	Env([0, 1, 0], [dur/2,dur/2], env_curve, 1),
        gate,
        levelScale: amp,
        doneAction: Done.freeSelf);
	snd=GrainBuf.ar(2, Impulse.kr(trigRate), dur, sndbuf,
		LFSaw.kr(10).range(0,1)/*rate*/,
		MouseX.kr(0,1),//LFNoise2.kr(0.1).range(0, 1),//position
		2, pan, envbuf) /** env*/;
	// snd=BPF.ar(snd,SinOsc.kr(100).range(400,420),MouseY.kr(0.001,1));
	Out.ar(out,snd);
}).add;
)
x = Synth(\buf_grain_test, [\sndbuf, b, \envbuf, -1, \rate,1,\trigRate, 1,\env_curve,\wel]);
​
// use built-in env
// var winenv = Env([0, 1, 0], [0.01, 0.01], [8, -8]);
(
var dur = 0.1;
// var winenv = Env([0, 1, 0], [dur/2, dur/2], \lin);
// var winenv = Env([0, 1, 0], [dur/2, dur/2], \lin);
// var winenv = Env([0, 1, 0], [dur/16, dur/16], \lin);
// var winenv = Env([0, 1, 0], [dur/2, dur/2], [8, -8]);
var winenv = Env([0, 1, 0], [dur/2, dur/2], [1, -1]);

// var winenv = Env([0, 1, 0], [dur/2, dur/2], \sin);
// var winenv = Env([0, 1, 0], [dur/2, dur/2], \sin);
z = Buffer.sendCollection(s, winenv.discretize, 1);
x.set(\envbuf, z);
x.set(\dur, dur);
x.set(\trigRate, 8);

)

x.set(\trigRate, 45);
x.set(\env_curve, \lin);
x.set(\env_time, 0.1)
20.do({arg i; Buffer.cachedBufferAt(s, i).postln;});
// x = Synth(\buf_grain_test, [\sndbuf, b, \envbuf, -1])
​
// switch to the custom env
x.set(\envbuf, -1);
​
x.set(\gate, 0);

