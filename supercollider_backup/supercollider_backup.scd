//from: "https://github.com/schollz/workshops/tree/main/2023-03-ceti-supercollider/record-once-replay-many"

// IMPORTANT: see "two important setup notes" below on line 18

//////// 17 ////////
// __   __  _______  _______
// |  | |  ||  _    ||       |
// |  | |  || |_|   ||    ___|
// |  |_|  ||       ||   |___
// |       ||  _   | |    ___|
// |       || |_|   ||   |___
// |_______||_______||_______|
//
// ube is a little tool I made to play with all these ideas:
// it is a "macrogranulator" that modulates all sorts of things of buffers
// and does recording/playback with the buffers
//
// two important setup notes:
// 1. before running this you must first save `Ube.sc` to the extensions directory.
// open `Ube.sc` in SuperCollider.
// now save it by doing `File -> Save As Extension...` and type `Ube.sc`.
// 2. also, for this version of UBE, FluCoMa needs to be installed...
// see instructions here: https://learn.flucoma.org/installation/sc/

// after running the above two setup steps, to run this code, put a cursor
// anywhere in the code block (a code block is enclosed in parentheses)
// and hit <Ctrl>+Enter

// note from jaseknighter: this version of ube adds two GrainBuf granulators
// to the audio path generated from whatever each player is currently playing.
// these size of the GrainBuf grains are controlled by the X location of the mouse.

// if you run into trouble, restart everything <Ctrl>+<Shift>+L and then <Ctrl>+Enter

// flutter and wow code from: "https://sccode.org/1-5bP"

// #1 run this code first to define the looper
(
s.waitForBoot({
	var pairs;

	// define the "looper"
	SynthDef("looper",{
		// main arguments
		arg buf,monobuf0,monobuf1,tape,player,baseRate=1.0,amp=1.0,timescale=0.2,
		rand1=30, //Rand(30,60),
		rand2=2, //Rand(hi:2*pi),
		rand3=60, //Rand(60,120),
		rand4=2, //Rand(hi:2*pi),
		rand5=5, //Rand(5,15),
		rand6=1, //Drand([0,1],inf),
		rand7=10, //Rand(10,30),
		rand8=2, //Rand(hi:2*pi),
		rand9=10, //Rand(10,30),
		rand10=2, //Rand(hi:2*pi),
		gate=1,

		//wow+flutter
		wobble_amp=MouseX.kr(0.01,0.05)/*0.05*/, wobble_exp=39,
		flutter_amp=0.03, flutter_fixedfreq=6,   flutter_variationfreq=2;
		// var signed_wobble = wobble_amp*(SinOsc.kr(wobble_rpm/60)**wobble_exp);
		var wobble_rpm = 33;

		var signed_wobble = wobble_amp*(SinOsc.kr(wobble_rpm/60)**wobble_exp);
		var wow = Select.kr(signed_wobble > 0, signed_wobble, 0);
		var flutter = flutter_amp*SinOsc.kr(flutter_fixedfreq+LFNoise2.kr(flutter_variationfreq));
		var combined_defects = 1 + wow + flutter;

		// winPct
		// variables to store UGens later
		var volume;
		var switch=0,snd,snd1,snd2,pos,pos1,pos2,posStart,posEnd,index;
		// store the number of frames and the duraiton
		var frames=BufFrames.kr(buf);
		var duration=BufDur.kr(buf);
		var grain0, grain1, gEnv0, gEnv1;



		///////////////////////////////////////////////////////
		// ----- START ADDING YOUR OWN MODULATION HERE ----- //
		///////////////////////////////////////////////////////

		// LFO for the start point
		var lfoStart=SinOsc.kr(timescale/rand1,rand2).range(1024,frames-10240);

		// LFO for the window length
		var lfoWindow=SinOsc.kr(timescale/rand3,rand4).range(4096,frames/2);

		// LFO for the rate (right now its not an LFO)
		var lfoRate=baseRate;

		// LFO for switching between forward and reverse
		var lfoForward=Demand.kr(Impulse.kr(timescale/rand5),0,rand6);

		// LFO for the volume
		var lfoAmp=SinOsc.kr(timescale/rand7,rand8).range(0.05,0.5);
		// var lfoAmp=SinOsc.kr(timescale/Rand(10,30),Rand(hi:2*pi)).range(0.05,1);

		// LFO for the panning
		var lfoPan=SinOsc.kr(timescale/rand9,rand10).range(-1,1);



		///////////////////////////////////////////////////////
		// ----- DONE ADDING YOUR OWN MODULATION HERE ------ //
		///////////////////////////////////////////////////////

		// calculate the final rate
		var rate=Lag.kr(lfoRate*(2*lfoForward-1),5)*BufRateScale.kr(buf);

		// modulate the start/stop
		posStart = lfoStart;
		posEnd = Clip.kr(posStart + lfoWindow,0,frames-1024);

		// LocalIn collects the a trigger whenever the playhead leaves the window
		switch=ToggleFF.kr(LocalIn.kr(1));


		// playhead 1 has a play position and buffer reader
		pos1=Phasor.ar(trig:1-switch,rate:rate,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
		snd1=BufRd.ar(2,buf,pos1,1.0,4);


		// playhead 2 has a play position and buffer reader
		pos2=Phasor.ar(trig:switch,  rate:rate,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
		snd2=BufRd.ar(2,buf,pos2,1.0,4);

		// current position changes according to the swtich
		pos=Select.ar(switch,[pos1,pos2]);

		// send out a trigger anytime the position is outside the window
		LocalOut.kr(
			Changed.kr(Stepper.kr(Impulse.kr(20),max:1000000000,
				step:(pos>posEnd)+(pos<posStart)
			))
		);

		// crossfade bewteen the two sounds over 50 milliseconds
		snd=SelectX.ar(Lag.kr(switch,0.05),[snd1,snd2]);

		// apply the volume lfo
		volume = 2*amp*lfoAmp*EnvGen.ar(Env.new([0,1],[Rand(1,10)],4));

		// send data to the GUI
		SendReply.kr(Impulse.kr(25),"/position",[tape,player,posStart/frames,posEnd/frames,pos/frames,volume,(lfoPan+1)/2]);

		gEnv0 = EnvGen.kr(
        Env([0, 1, 0], [1, 1], \sin, 1),
        gate,
        levelScale: 1,
        doneAction: Done.freeSelf);
		gEnv1 = EnvGen.kr(
        Env([0, 1, 0], [1, 1], \sin, 1),
        gate,
        levelScale: 1,
        doneAction: Done.freeSelf);

		grain0 = GrainBuf.ar(2, Impulse.kr(10), MouseX.kr(0.01,3), monobuf0, rate, pos1, 2, 0, -1) * gEnv0;
		grain1 = GrainBuf.ar(2, Impulse.kr(10), MouseX.kr(0.01,3), monobuf1, rate, pos1, 2, 0, -1) * gEnv1;
		// grain0 = GrainBuf.ar(2, Impulse.kr(10), 1.5, monobuf0, rate, pos1, 2, 0, -1) * gEnv0;
		// grain1 = GrainBuf.ar(2, Impulse.kr(10), 1.5, monobuf1, rate, pos1, 2, 0, -1) * gEnv1;

		// do the panning
		// snd=Balance2.ar(grain0,grain1,lfoPan);
		// snd=Balance2.ar(snd[0],snd[1],lfoPan);
		snd=Balance2.ar(grain0+snd[0],grain1+snd[1],lfoPan);


		///////////////////////////////////////////////////////
		// --------- START ADDING ANY EFFECTS HERE --------- //
		///////////////////////////////////////////////////////
		// snd = CombC.ar(snd,0.5,SinOsc.ar(0.01).range(1,1.5),3);
		// snd = CombC.ar(snd,0.5,SinOsc.ar(MouseX.kr(0.01,0.09),0.1).range(0.1,0.3),MouseX.kr(0.01,0.09));
		// snd = CombC.ar(snd,0.5,0.1,5)*SinOsc.ar(MouseX.kr(5)); // random delay
		// snd = CombC.ar(snd,0.5,Rand(0.05,0.5),5); // random delay
		// snd = LPF.ar(snd,SinOsc.kr(0.1).exprange(20,2000)); // modulated filter
		// snd = (snd * MouseX.kr(1,10)).tanh / 2; // mouse-controlled distortion
		// ?????




		///////////////////////////////////////////////////////
		// -------=-- DONE ADDING ANY EFFECTS HERE --------- //
		///////////////////////////////////////////////////////

		// final output
		Out.ar(0,snd*volume/3);
		// Out.ar(0,snd*volume*2);
	}).send(s);

	// basic players
	SynthDef("recorder",{
		arg buf,recLevel=1.0,preLevel=0.0;
		RecordBuf.ar(SoundIn.ar([0,1]),buf,0.0,recLevel,preLevel,loop:0,doneAction:2);
	}).send(s);

	// effects
	SynthDef("effects",{
		arg amp=1.0,tempo=8.0, envdur=0.25;
		//chorus args

		// collect the sound coming from the bus "0" on 2 channels (stereo)
		var sig;
		var snd=In.ar(0,2);

		// add some delay
		snd = CombC.ar(snd,0.5,delaytime:0.25,decaytime:3);

		// add some reverb
		snd = SelectX.ar(LFNoise2.kr(1/3).range(0.1,0.5),[
			snd,
			FreeVerb2.ar(snd[0],snd[1],50,MouseY.kr(1,0))
		]);



		///////////////////////////////////////////////////////
		// ----- DONE ADDING YOUR GLOBAL EFFECTS HERE ------ //
		///////////////////////////////////////////////////////

		snd = snd*Lag.kr(amp);
		// replace the output with the effected output

		ReplaceOut.ar(0,snd);
	}).send(s);

	// load the ube class
	u=Ube.new(Server.default);


});
)

// #2 run this code second to load a file and start playing three versions of it
(
Routine {
	u.loadTape(tape:1,filename:thisProcess.nowExecutingPath.dirname++"/flora_wowless.wav");
	// u.loadTape(tape:1,filename:thisProcess.nowExecutingPath.dirname++"/kalimba.wav");

	1.wait; // give time for buffer to load
	u.playTape(tape:1,player:1,rate:0.5,db:0,timescale:1.0);
	u.playTape(tape:1,player:2,rate:0.25,db:0,timescale:1.0);
	u.playTape(tape:1,player:3,rate:0.125,db:3,timescale:1.0);
	// u.playTape(tape:1,player:4,rate:2,db:-3,timescale:1.0);
	// u.playTape(tape:1,player:5,rate:1,db:-2,timescale:1.0);
	3.do({arg v,i;
		// i.postln;
  	u.setR1(tape:1,player:1+i,val:30.rand+60);
  	u.setR2(tape:1,player:1+i,val:(2*pi).rand);
  	u.setR3(tape:1,player:1+i,val:60.rand+120);
  	u.setR4(tape:1,player:1+i,val:(2*pi).rand);
  	u.setR5(tape:1,player:1+i,val:5.rand+15);
  	u.setR6(tape:1,player:1+i,val:2.rand);
  	u.setR7(tape:1,player:1+i,val:10.rand+30);
  	u.setR8(tape:1,player:1+i,val:(2*pi));
  	u.setR9(tape:1,player:1+i,val:10.rand+30);
  	u.setR10(tape:1,player:1+i,val:(2*pi).rand);
  });
	u.gui;
}.play;
)
