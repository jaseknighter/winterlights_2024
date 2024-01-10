/**
Functional example of using TrillCentroids UGen

(C) 2019 Jonathan Reus

**/

s = Server.default;

s.options.numAnalogInChannels = 8; // can be 2, 4 or 8
s.options.numAnalogOutChannels = 8; // can be 2, 4 or 8
s.options.numDigitalChannels = 16;
s.options.maxLogins = 8;

s.options.pgaGainLeft = 5;     // sets the pregain for the left audio input (dB)
s.options.pgaGainRight = 5;    // sets the pregain for the right audio input (dB)
s.options.headphoneLevel = 0; //-1; // sets the headphone level (-dB)
s.options.speakerMuted = 0;    // set true to mute the speaker amp and draw a little less power
s.options.dacLevel = 0;       // sets the gain of the stereo audio dac (+dB)
s.options.adcLevel = 0;       // sets the gain of the stereo audio adc (+dB)

s.options.blockSize = 256; //16;
s.options.numInputBusChannels = 2; //10;
s.options.numOutputBusChannels = 2;


s.waitForBoot {
  var pairs;
  //i2c bela stuff
  var i2c_bus = 1;
  //var i2c_address = 0x18;
  var i2c_address_bar = 0x20; //
  var i2c_address_hex = 0x40; //
  var noiseThreshold = 0.2; //0.02; // float: 0-0.0625, with 0.0625 being the highest noise thresh
  var prescalerOpt = 2; // int: 1-8 with 1 being the highest sensitivity
  var touchsigs = DC.ar(0).dup(3); // use 3 touches
  var centroids_bar;
  var centroids_hex;
  var out, ping;	

  var hex_pressed = false;
  var bar_pressed = false;
  var recording = false;

  ("booted").postln;
  SynthDef(\trillSynth_bar, {|t_recalibrate_bar=0.0|
    // returns an array with format: [num_active_touches, t1_pos, t1_size, t2_pos, t2_size, t3_pos, t3_size, t4_pos, t4_size, t5_pos, t5_size]
    centroids_bar = TrillCentroids.kr(i2c_bus, i2c_address_bar, noiseThreshold, prescalerOpt, t_recalibrate_bar);		
    SendReply.kr(Impulse.kr(2), "/trill_bar", centroids_bar);
    ("trill bar initialized").postln;
  }).send(s);

  SynthDef(\trillSynth_hex, {|t_recalibrate_hex=0.0|
    // returns an array with format: [num_active_touches, t1_pos, t1_size, t2_pos, t2_size, t3_pos, t3_size, t4_pos, t4_size, t5_pos, t5_size]
    centroids_hex = TrillCentroids.kr(i2c_bus, i2c_address_hex, noiseThreshold, prescalerOpt, t_recalibrate_hex);		
		SendReply.kr(Impulse.kr(2), "/trill_hex", centroids_hex);
    ("trill hex initialized").postln;
  }).send(s);

  // define the "looper"
	SynthDef("looper",{ 
		// main arguments
		arg t_recalibrate=0.0,
    // core looper args
    buf,monobuf0,monobuf1,tape,player,baseRate=1.0,amp=1.0,timescale=0.2,
    // 
    grainSize0=0.1,
    grainSize1=0.2,
    grainSpeed0=5,
    grainSpeed1=10,
    gWinEnv,
    lfoStartFreqDivisor=30, //Rand(30,60),
		lfoWindowFreqDivisor=60, //Rand(60,120),
		lfoAmpFreqDivisor=10, //Rand(10,30),
		lfoPanFreqDivisor=10, //Rand(10,30),
		gate=1, 
    //wow+flutter
		effect_amp=0.05, wobble_exp=39,
		flutter_amp=0.03, flutter_fixedfreq=6,   flutter_variationfreq=2;
		// var signed_wobble = effect_amp*(SinOsc.kr(wobble_rpm/60)**wobble_exp);
		var wobble_rpm = 33;

		var signed_wobble = effect_amp*(SinOsc.kr(wobble_rpm/60)**wobble_exp);
		var wow = Select.kr(signed_wobble > 0, signed_wobble, 0);
		var flutter = flutter_amp*SinOsc.kr(flutter_fixedfreq+LFNoise2.kr(flutter_variationfreq));
		var combined_defects = 1 + wow + flutter;

		// variables to store UGens later
		var volume;
		var switch=0,snd,snd1,snd2,pos,pos1,pos2,posStart,posEnd,index;
		// store the number of frames and the duraiton
		var frames=BufFrames.kr(buf);
		var duration=BufDur.kr(buf);
    var grain0, grain1, gEnv;
    // var gWinenv = Env([0, 1, 0], [0.5, 0.5], [8, -8]);
    // var gWinenv = Env([0, 1, 0], [0.5*gEnvMult, 0.5*gEnvMult], [8, -8]);
		// var gWinenvBuf  = Buffer.sendCollection(s, gWinenv.discretize, 1);





		///////////////////////////////////////////////////////
		// ----- START ADDING YOUR OWN MODULATION HERE ----- //
		///////////////////////////////////////////////////////


		// LFO for the start point
		var lfoStart=SinOsc.kr(timescale/lfoStartFreqDivisor,Rand(hi:2*pi)).range(1024,frames-10240);

		// LFO for the window lenth
		var lfoWindow=SinOsc.kr(timescale/lfoWindowFreqDivisor,Rand(hi:2*pi)).range(4096,frames/2);

		// LFO for the rate (right now its not an LFO)
		var lfoRate=baseRate;

		// LFO for switching between forward and reverse
		var lfoForward=Demand.kr(Impulse.kr(timescale/Rand(5,15)),0,Drand([0,1],inf));

		// LFO for the volume
		var lfoAmp=SinOsc.kr(timescale/lfoAmpFreqDivisor,Rand(hi:2*pi)).range(0.05,0.5);

		// LFO for the panning
		var lfoPan=SinOsc.kr(timescale/lfoPanFreqDivisor,Rand(hi:2*pi)).range(-1,1);

		///////////////////////////////////////////////////////
		// ----- DONE ADDING YOUR OWN MODULATION HERE ------ //
		///////////////////////////////////////////////////////



		// calculate the final rate
		var rate=Lag.kr(lfoRate*(2*lfoForward-1),1)*BufRateScale.kr(buf);

		// modulate the start/stop
		posStart = lfoStart;
		posEnd = Clip.kr(posStart + lfoWindow,0,frames-1024);

		// LocalIn collects the a trigger whenever the playhead leaves the window
		switch=ToggleFF.kr(LocalIn.kr(1));

		// playhead 1 has a play position and buffer reader
		pos1=Phasor.ar(trig:1-switch,rate:rate*combined_defects,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
		snd1=BufRd.ar(2,buf,pos1,1.0,4);

		// playhead 2 has a play position and buffer reader
		pos2=Phasor.ar(trig:switch,  rate:rate*combined_defects,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
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
		volume = amp*lfoAmp*EnvGen.ar(Env.new([0,1],[Rand(1,10)],4));

		// send data to the GUI
		// SendReply.kr(Impulse.kr(25),"/position",[tape,player,posStart/frames,posEnd/frames,pos/frames,volume,(lfoPan+1)/2]);
  	gEnv = EnvGen.kr(
        Env([0, 1, 0], [0.5, 1], \lin, 1),
        gate,
        levelScale: 1,
        // timeScale:grainSize0,
        doneAction: Done.freeSelf);
		
    // grain0 = GrainBuf.ar(2, Impulse.kr(grainSpeed0), grainSize0, monobuf0, rate, pos1, 2, 0, -1) * gEnv;
    grain0 = GrainBuf.ar(2, Impulse.kr(10), MouseX.kr(0.01,3), monobuf0, rate, pos1, 2, lfoPan, gWinenv ) * gEnv;
    // grain1 = GrainBuf.ar(2, Impulse.kr(grainSpeed1), grainSize1, monobuf1, rate, pos1, 2, 0, -1) * gEnv;
    grain1 = GrainBuf.ar(2, Impulse.kr(10), MouseX.kr(0.01,3), monobuf1, rate, pos1, 2, lfoPan, gWinenv ) * gEnv;

		// do the panning
    // snd=Balance2.ar(grain0,grain1,lfoPan);
		// snd=Balance2.ar(snd[0],snd[1],lfoPan);
    snd = snd*volume/3;
		snd=Balance2.ar(Mix.new(grain0+snd[0]),Mix.new(grain1+snd[1]),lfoPan);
		
		///////////////////////////////////////////////////////
		// ------ START ADDING PLAYER EFFECTS HERE --------- //
		///////////////////////////////////////////////////////

		// snd = CombC.ar(snd,0.5,Rand(0.05,0.5),2); // random delay
		// snd = LPF.ar(snd,SinOsc.kr(0.1).exprange(20,2000)); // modulated filter
		// snd = (snd * MouseX.kr(1,10)).tanh / 2; // mouse-controlled distortion
		// ?????

		///////////////////////////////////////////////////////
		// ------- DONE ADDING PLAYER EFFECTS HERE --------- //
		///////////////////////////////////////////////////////


		
		// touchsigs[0] = Resonz.ar(
		// 	Pluck.ar(PinkNoise.ar, (centroids_bar[2] < 0.05), 0.2, centroids_bar[1].linexp(0.0, 1.0, 80, 1000).reciprocal, 3, 0.5, mul: 6.0),
		// 	centroids_bar[1].linexp(0.0, 1.0, 800, 2400), 0.1, 4.0).tanh;
		

		// final output
		Out.ar(0,snd*volume/3);
		// Out.ar(0,snd*volume/5);
		// Out.ar(0,snd*volume/5 + ping);
	}).send(s);
  
  	// basic players
	SynthDef("recorder",{
		arg buf,recLevel=1.0,preLevel=0.0;
		RecordBuf.ar(SoundIn.ar([0,1]),buf,0.0,recLevel,preLevel,loop:0,doneAction:2);
	}).send(s);

	// effects
	SynthDef("effects",{
		arg amp=1.0;

		// collect the sound coming from the bus "0" on 2 channels (stereo)
		var snd=In.ar(0,2);

		///////////////////////////////////////////////////////
		// ----- START ADDING YOUR GLOBAL EFFECTS HERE ----- //
		///////////////////////////////////////////////////////

		// add some nice tape compression
		// snd = AnalogTape.ar(snd,0.9,0.8,0.9,2);

		// add some delay
		snd = CombC.ar(snd,0.5,delaytime:0.1,decaytime:1.1);

		// add some reverb
		// snd = SelectX.ar(LFNoise2.kr(1/3).range(0.1,0.5),[
		// 	snd,
		// 	FreeVerb2.ar(snd[0],snd[1],50)
		// 	//Fverb.ar(snd[0],snd[1],50,decay:LFNoise2.kr(1/3).range(70,90))
		// ]);

		// // add some analog chewing (PortedPlugins needed)
		// snd = SelectX.ar(LFNoise2.kr(1/3).range(0,1),[
		// 	snd,
		// 	AnalogChew.ar(snd);
		// ]);

		///////////////////////////////////////////////////////
		// ----- DONE ADDING YOUR GLOBAL EFFECTS HERE ------ //
		///////////////////////////////////////////////////////

		// replace the output with the effected output
		ReplaceOut.ar(0,snd*Lag.kr(amp));
	}).send(s);

  s.sync;

  ~tr_bar = Synth(\trillSynth_bar);
  ~tr_hex = Synth(\trillSynth_hex);

	// load the ube class
	u=Ube.new(s);

/*
  recordAndPlay {
    // record another tape and play it
    recording = true;
    Routine {
      u.recordTape(tape:1,seconds:3,recLevel:2); 3.5.wait;
      0.5.wait; // give time for buffer to load
      // u.pauseTape(tape:1,player:1);
      // u.pauseTape(tape:1,player:2);
      // u.pauseTape(tape:1,player:3);
      // u.pauseTape(tape:1,player:4);
      // u.pauseTape(tape:1,player:5);

      u.playTape(tape:1,player:1,rate:0.5,db:3,timescale:1.0);
      u.playTape(tape:1,player:2,rate:0.25,db:6,timescale:1.0);
      u.playTape(tape:1,player:3,rate:0.125,db:9,timescale:1.0);
      u.playTape(tape:1,player:4,rate:2,db:-6,timescale:1.0);
      u.playTape(tape:1,player:5,rate:4,db:-12,timescale:1.0);
      recording = false;
    }.play;
  };
*/

  OSCdef(\trill_bar, {|msg| 
    // if (msg[3] > 0,{
    if (recording == false && msg[3] == 1,{
      // var touch1
      if (bar_pressed == false){
        //change tape rates
        // msg[3].do({ arg v,i;
        //   var rates = [0.125,0.25,0.5,0.75,1,1.25,1.5,2];
        //   var rate_idx = msg[v+5].linlin(0,1,0,7).floor;
        //   var newrate = rates[rate_idx];
        //   var tapenums = [1,2,3,4,5];
        //   ([v,tapenums[v], rate_idx, newrate]).postln;
        //   u.setRate(tape:tapenums[v],player:1,rate:newrate);
        // });

        //change grain size
        msg[3].do({ arg v,i;
          var grainSize = msg[v+4].linlin(0,1,0.05,1.5);
          var rates = [0.125,0.25,0.5,0.75,1,1.25,1.5,2,5,10];
          var rate = rates[msg[v+4].linlin(0,1,0,9).floor];
          var grainSpeed = msg[v+5].linexp(0,1,0.1,5);
          var tapenums = [1,2,3,4,5];
          
          var gWinenv = Env([0, 1, 0], [0.5*rate, 0.5*rate], [8, -8]);
          var gWinenvBuf  = Buffer.sendCollection(s, gWinenv.discretize, 1);

    
          // ([msg[v+4],msg[v+5],v,tapenums[v], grainSize]).postln;
          u.setRate(tape:tapenums[v],player:1,val:rate);
          u.setGrainSize0(tape:tapenums[v],player:1,val:grainSize);
          u.setGrainSize1(tape:tapenums[v],player:1,val:grainSize*2);
          u.setGrainSpeed0(tape:tapenums[v],player:1,val:grainSpeed);
          u.setGrainSpeed1(tape:tapenums[v],player:1,val:grainSpeed*2);
          u.setGrainWinEnv(tape:tapenums[v],player:1,val:gWinenvBuf);
        });
        // bar_pressed = true;
      };
      // msg[0..].postln;
    });

    if (msg[3] == 0,{
        if (bar_pressed == true){
          // bar_pressed = false;
        }
    });
  }, "/trill_bar");

  OSCdef(\trill_hex, {|msg| 

    if (msg[3] == 0.0){
      if (hex_pressed == true){
        Routine {
          ("hex released").postln;
          hex_pressed = false;
        }.play;
      };
    };

    if (msg[3] == 1.0){
      if (hex_pressed == false){
        hex_pressed = true;
        "hex pressed".postln;
        // msg[0..].postln; 
        if (recording == false){
          "record".postln;
          // recordAndPlay()
          recording = true;
          Routine {
            u.recordTape(tape:1,seconds:3,recLevel:2); 3.5.wait;
            0.5.wait; // give time for buffer to load
            // u.pauseTape(tape:1,player:1);
            // u.pauseTape(tape:1,player:2);
            // u.pauseTape(tape:1,player:3);
            // u.pauseTape(tape:1,player:4);
            // u.pauseTape(tape:1,player:5);

            u.playTape(tape:1,player:1,rate:0.5,db:3,timescale:1.0);
            // u.playTape(tape:1,player:2,rate:0.25,db:6,timescale:1.0);
            // u.playTape(tape:1,player:3,rate:5,db:9,timescale:1.0);
            // u.playTape(tape:1,player:4,rate:2,db:-6,timescale:1.0);
            // u.playTape(tape:1,player:5,rate:4,db:-12,timescale:1.0);
            1.do({arg v,i;
              u.setLfoStartFreqDivisor(tape:1,player:1+i,val:30.rand+30);
            	u.setLfoWindowFreqDivisor(tape:1,player:1+i,val:60.rand+60);
            	u.setLfoAmpFreqDivisor(tape:1,player:1+i,val:10.rand+20);
            	u.setLfoPanFreqDivisor(tape:1,player:1+i,val:10.rand+20);


            });

            recording = false;
          }.play;
        }
      };
    };
    // msg[0].postln 
  }, "/trill_hex");

  // OSCFunc({|...args| 
    //args.postln;
    // "number of fingers_ : ".post; 
    // args[0][3].postln;
    // x.set(\duration,args[0][4].linlin(0,1,0.1,0.3));
  // }, "/trill");

/**

  Routine {
    u.loadTape(tape:1,filename:thisProcess.nowExecutingPath.dirname++"/kalimba.wav");
    0.5.wait; // give time for buffer to load
    u.playTape(tape:1,player:1,rate:0.5,db:3,timescale:1.0);
    u.playTape(tape:1,player:2,rate:0.25,db:6,timescale:1.0);
    u.playTape(tape:1,player:3,rate:0.125,db:9,timescale:1.0);
    u.playTape(tape:1,player:4,rate:2,db:-6,timescale:1.0);
    u.playTape(tape:1,player:5,rate:4,db:-12,timescale:1.0);

  }.play;
  Routine {
		// either load a file into the tape
		// u.loadTape(tape:1,filename:thisProcess.nowExecutingPath.dirname++"/kalimba.wav");
		// OR record another tape and play it
		// u.recordTape(tape:1,seconds:3,recLevel:2); 3.5.wait;

		0.5.wait; // give time for buffer to load
		// create players to play the tape
		u.playTape(tape:1,player:0,rate:1,db:0,timescale:1.0);
		u.playTape(tape:1,player:0,rate:10,db:0,timescale:1.0);
    u.pauseTape(tape:1,player:0);
    u.restartTape(tape:1,player:0);
    u.setRate(tape:1,player:0,rate:1);

		u.playTape(tape:1,player:1,rate:0.5,db:3,timescale:1.0);
		u.playTape(tape:1,player:2,rate:0.25,db:6,timescale:1.0);
		u.playTape(tape:1,player:3,rate:0.125,db:9,timescale:1.0);
		u.playTape(tape:1,player:4,rate:2,db:-6,timescale:1.0);
		u.playTape(tape:1,player:5,rate:4,db:-12,timescale:1.0);

	}.play;
**/
}