/**
From: Functional example of using TrillCentroids UGen

(C) 2019 Jonathan Reus

**/

s = Server.default;

s.options.numAnalogInChannels = 8; // can be 2, 4 or 8
s.options.numAnalogOutChannels = 8; // can be 2, 4 or 8
s.options.numDigitalChannels = 16;
s.options.maxLogins = 8;
// s.options.bindAddress = "0.0.0.0"; // allow anyone on the network connect to this server

s.options.pgaGainLeft = 5;     // sets the pregain for the left audio input (dB)
s.options.pgaGainRight = 5;    // sets the pregain for the right audio input (dB)
s.options.headphoneLevel = 0; //-1; // sets the headphone level (-dB)
s.options.speakerMuted = true;    // set true to mute the speaker amp and draw a little less power
s.options.dacLevel = 0;       // sets the gain of the stereo audio dac (+dB)
s.options.adcLevel = 0;       // sets the gain of the stereo audio adc (+dB)

s.options.blockSize = 256; //16;
s.options.numInputBusChannels = 2; //10;
s.options.numOutputBusChannels = 2;


s.waitForBoot {
  var freader = FileReader.read("laptop_ip_port.txt", true, true, delimiter:$;).postcs;
  var ip = freader[0][0]; // the port to receive from/send to TouchDesigner
  var port = freader[1][0].asInteger; // the port to send to TouchDesigner
  var sender = NetAddr.new(ip, port); // create the NetAddr to send msgs
  // var sender = NetAddr.new("127.0.0.1", 1000); // create the NetAddr to send msgs
  
  
  var follower_freader = FileReader.read("bela_follower_ip.txt", true, true, delimiter:$;).postcs;
  var follower_ip = follower_freader[0][0]; // the port to receive from/send to TouchDesigner
  var receiver = NetAddr.new(follower_ip, 57120); // create the NetAddr to receive msgs
	// var receiver = NetAddr.new("127.0.0.1"); // create the NetAddr to receive msgs
	var oscReceiverFunc;

  var pairs;
  //i2c bela stuff
  var i2c_bus = 1;
  //var i2c_address = 0x18;
  var i2c_address_bar = 0x20; //
  var i2c_address_hex = 0x40; //
  var i2c_address_ring = 0x38; //

  var noiseThreshold = 0.02; //0.02; // float: 0-0.0625, with 0.0625 being the highest noise thresh
  var prescalerOpt = 2; // int: 1-8 with 1 being the highest sensitivity
  // var touchsigs = DC.ar(0).dup(3); // use 3 touches
  var centroids_bar;
  var centroids_hex;
  var centroids_ring;
  var out, ping;	

  var hex_pressed = false;
  var bar_pressed = false;
  var ring_pressed = false;
  var selectedEnvelope = 1;
  var recording = false;

  var max30102_pressed = false;
  var fmax30102_pressed = false;
  
  // var laptop_osc_ip_port = FileReader.read("laptop_ip_port.txt", true, true, delimiter:$;).postcs;

  /////////////////////////////////////
  //code for receiving messages from bela_follower
  /////////////////////////////////////
	thisProcess.openUDPPort(57120); 
	thisProcess.openUDPPort(7562); 
  // OSCFunc.trace(true); // Turn posting on
  ("laptop ip/port: "+ip +"/"+port).postln;
  ("follower ip: "+follower_ip).postln;
  ("receiver: " + receiver).postln;

  //follower max30102 receiving code
	OSCFunc({ arg msg, time, addr, recvPort;
		// ("received ring pressed: " + [msg, time, addr, recvPort]).postln;
		("fmax30102 bpm: " + msg).postln;
    sender.sendMsg("/fmax30102_bpm", msg[1]); // send value to touchdesigner
	}, '/fmax30102_bpm', receiver);

	OSCFunc({ arg msg, time, addr, recvPort;
		// ("received ring pressed: " + [msg, time, addr, recvPort]).postln;
		("fmax30102 touched: " + msg).postln;
    if (msg[1]==0,{
        sender.sendMsg("/fmax30102_pressed", 0); // send value to touchdesigner
        fmax30102_pressed = false;
        ("fmax30102 released").postln;
    });
    if (msg[1]==1,{
      if (fmax30102_pressed==false,{
        sender.sendMsg("/fmax30102_pressed", 1); // send value to touchdesigner
        fmax30102_pressed = true;
        recording = true;
        ("fmax 30102 pressed record").postln;
        Routine {
          u.recordTape(tape:1,seconds:3,recLevel:2,sender:sender); 3.5.wait;
          0.5.wait; // give time for buffer to load
          u.playTape(tape:1,player:1,rate:0.5,db:10,timescale:1.0);
          u.playTape(tape:1,player:2,rate:0.25,db:10,timescale:1.0);
          // u.playTape(tape:1,player:3,rate:1.25,db:-9,timescale:1.0);
          2.do({arg v,i;
            u.setLfoStartFreqDivisor(tape:1,player:1+i,val:30.rand+30);
            u.setLfoWindowFreqDivisor(tape:1,player:1+i,val:5.rand+10);
            u.setLfoAmpFreqDivisor(tape:1,player:1+i,val:10.rand+20);
            u.setLfoPanFreqDivisor(tape:1,player:1+i,val:10.rand+20);
          });
          recording = false;
        }.play;
      });
    });
    
	}, '/fmax30102_pressed', receiver);

  //follower ring1 receiving code
	OSCFunc({ arg msg, time, addr, recvPort;
		// ("received ring pressed: " + [msg, time, addr, recvPort]).postln;
		// ("received ring1 pressed: " + msg[1]).postln;
    sender.sendMsg("/fring1_pressed", msg[1]); // send value to touchdesigner    
	}, '/fring1_pressed', receiver);
	
  OSCFunc({ arg msg, time, addr, recvPort;
    var effect1;
		// ("received ring pressed: " + [msg, time, addr, recvPort]).postln;
		// ("received ring1 location: " + msg[1]).postln;
    if (msg[1] < 0.5, {
      effect1 = msg[1].linlin(0,0.5,0,1);
      // effect1 = msg[4].linlin(0,0.5,0,0.8).postln;
    },{
      effect1 = msg[1].linlin(0.5,1,1,0);
      // effect1 = msg[4].linlin(0.5,1,0.8,0).postln;
    });
    ("effect1: " + effect1).postln;
    sender.sendMsg("/fring1_location", msg[1]); // send touch location to touchdesigner
    2.do({ arg v,i;        
        var tapenums = [1,2,3,4,5];
        u.setEffect1(tape:tapenums[v],player:1,val:effect1);
        u.setEffect1(tape:tapenums[v],player:2,val:effect1);
      })

	}, '/fring1_location', receiver);
	
  OSCFunc({ arg msg, time, addr, recvPort;
		// ("received ring pressed: " + [msg, time, addr, recvPort]).postln;
		sender.sendMsg("/fring1_pressure", msg[1]); // send touch pressure to touchdesigner
    // ("received ring1 pressure: " + msg[1]).postln;
	}, '/fring1_pressure', receiver);

//follower ring2 receiving code
	OSCFunc({ arg msg, time, addr, recvPort;
		// ("received ring pressed: " + [msg, time, addr, recvPort]).postln;
		sender.sendMsg("/fring2_pressed", msg[1]); // send value to touchdesigner    
    // ("received ring2 pressed: " + msg[1]).postln;
	}, '/fring2_pressed', receiver);
	
  OSCFunc({ arg msg, time, addr, recvPort;
    var effect3;
		// ("received ring pressed: " + [msg, time, addr, recvPort]).postln;
		// ("received ring1 location: " + msg[1]).postln;
    if (msg[1] < 0.5, {
      effect3 = msg[1].linlin(0,0.5,0,1);
    },{
      effect3 = msg[1].linlin(0.5,1,1,0);
    });
    ("effect3: " + effect3).postln;
    sender.sendMsg("/fring2_location", msg[1]); // send touch location to touchdesigner
    2.do({ arg v,i;        
      var tapenums = [1,2,3,4,5];
      u.setEffect3(tape:tapenums[v],player:1,val:effect3);
      u.setEffect3(tape:tapenums[v],player:2,val:effect3);
    })

	}, '/fring2_location', receiver);
	
  OSCFunc({ arg msg, time, addr, recvPort;
		// ("received ring pressed: " + [msg, time, addr, recvPort]).postln;
		sender.sendMsg("/fring2_pressure", msg[1]); // send touch pressure to touchdesigner
    // ("received ring2 pressure: " + msg[1]).postln;
	}, '/fring2_pressure', receiver);

  s.sync;

  /////////////////////////////////////
  //code for receiving messages from onboard trill sensors
  /////////////////////////////////////

  SynthDef(\max30102, {
    // channels
    // 0: IR_AC
    // 1: IR_BEAT
    // 2: IR_RAW
    // 3: RED_RAW
    // 4: IR_BPM
    // 5: HZ
    // 6: TEMP_C
    // 7: IR_AVG_DC_EST
    // var ir_ac = Max30102.kr(0);
    // var ir_beat = Max30102.kr(1);
    // var ir_raw = Max30102.kr(2);
    // var red_raw = Max30102.kr(3);
    var ir_bpm = Max30102.kr(4);
    // var hz = Max30102.kr(5);
    // var temp_c = Max30102.kr(6);
    var ir_avg_dc_est = Max30102.kr(7);
    // returns an array with format: [num_active_touches, t1_pos, t1_size, t2_pos, t2_size, t3_pos, t3_size, t4_pos, t4_size, t5_pos, t5_size]
    SendReply.kr(Impulse.kr(1), "/max30102", [
      // ir_ac,
      // ir_beat,
      // ir_raw,
      // red_raw,
      ir_bpm,
      // hz,
      // temp_c,
      ir_avg_dc_est
    ]);
    
    // ("max30102 initialized").postln;
  }).send(s);

  SynthDef(\trillSynth_bar, {|t_recalibrate_bar=0.0|
    // returns an array with format: [num_active_touches, t1_pos, t1_size, t2_pos, t2_size, t3_pos, t3_size, t4_pos, t4_size, t5_pos, t5_size]
    centroids_bar = TrillCentroids.kr(i2c_bus, i2c_address_bar, noiseThreshold, prescalerOpt, t_recalibrate_bar);		
    SendReply.kr(Impulse.kr(10), "/trill_bar", centroids_bar);
    ("trill bar initialized").postln;
  }).send(s);

  SynthDef(\trillSynth_hex, {|t_recalibrate_hex=1.0|
    // returns an array with format: [num_active_touches, t1_pos, t1_size, t2_pos, t2_size, t3_pos, t3_size, t4_pos, t4_size, t5_pos, t5_size]
    centroids_hex = TrillCentroids.kr(i2c_bus, i2c_address_hex, noiseThreshold, prescalerOpt, t_recalibrate_hex);		
		SendReply.kr(Impulse.kr(2), "/trill_hex", centroids_hex);
    ("trill hex initialized").postln;
  }).send(s);
  
  // SynthDef(\trillSynth_ring, {|t_recalibrate_ring=0.0|
  //   // returns an array with format: [num_active_touches, t1_pos, t1_size, t2_pos, t2_size, t3_pos, t3_size, t4_pos, t4_size, t5_pos, t5_size]
  //   centroids_ring = TrillCentroids.kr(i2c_bus, i2c_address_ring, noiseThreshold, prescalerOpt, t_recalibrate_ring);		
	// 	SendReply.kr(Impulse.kr(10), "/trill_ring", centroids_ring);
  //   ("trill ring initialized").postln;
  // }).send(s);


  s.sync;
  /////////////////////////////////////
  // define the "looper"
  /////////////////////////////////////

	SynthDef("looper",{ 
		// main arguments
		arg t_recalibrate=0.0,
    // core looper args
    buf,monobuf0,monobuf1,tape,player,baseRate=1.0,amp=1.0,timescale=0.2,
    // 
    loopAmt=0.5, //amount of macrogranulated sound to pass through (0 to 1)
    grainAmt=0.5, //amount of microgranulated sound to pass through (0 to 1)
    grainSize0=0.1,
    grainSize1=0.2,
    gTriggerSpeed=10,
    lfoStartFreqDivisor=30, //Rand(30,60),
		lfoWindowFreqDivisor=100, //Rand(60,120),
		lfoAmpFreqDivisor=10, //Rand(10,30),
		lfoPanFreqDivisor=10, //Rand(10,30),
		gate=1, 
    envbuf,
    //wow+flutter
		effect1=0, effect2=0, effect3=0, wobble_amp=0.05, wobble_exp=39,
		flutter_amp=0.03, flutter_fixedfreq=6, flutter_variationfreq=2;
		var wobble_rpm = 33;

		// var signed_wobble = (SinOsc.kr(wobble_amp/60)**wobble_exp);
		// var wow = Select.kr(signed_wobble > 0, signed_wobble, 0);
		// var flutter = flutter_amp*SinOsc.kr(flutter_fixedfreq+LFNoise2.kr(flutter_variationfreq));
		var combined_defects = 1;//((wow) + flutter);

		// variables to store UGens later
		var volume;
		var switch=0,snd,snd1,snd2,pos,pos1,pos2,posStart,posEnd,index;
		// store the number of frames and the duraiton
		var frames=BufFrames.kr(buf);
		var duration=BufDur.kr(buf);
    var grain0, grain1, gEnv;
    
    


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
		var rate=Lag.kr(lfoRate*(2*lfoForward-1),0.1)*BufRateScale.kr(buf);
		// var rate=Lag.kr(lfoRate*(2*lfoForward-1),1)*BufRateScale.kr(buf);
		// modulate the start/stop
		posStart = lfoStart;
		posEnd = Clip.kr(posStart + lfoWindow,0,frames-1024);

		// LocalIn collects the a trigger whenever the playhead leaves the window
		switch=ToggleFF.kr(LocalIn.kr(1));

		// playhead 1 has a play position and buffer reader
		pos1=Phasor.ar(trig:1-switch,rate:rate,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
		snd1=BufRd.ar(2,buf,pos1*combined_defects,1.0,4);

		// playhead 2 has a play position and buffer reader
		pos2=Phasor.ar(trig:switch,  rate:rate,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
		snd2=BufRd.ar(2,buf,pos2*combined_defects,1.0,4);

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
  	// gEnv = EnvGen.kr(
    //     Env([0, 1, 0], [0.5, 1], \lin, 1),
    //     gate,
    //     levelScale: 1,
    //     doneAction: Done.freeSelf);
    grain0 = GrainBuf.ar(2, Impulse.kr(gTriggerSpeed), grainSize0, monobuf0, rate, pos, 4, lfoPan, envbuf, maxGrains: 32, mul:1 );
    grain1 = GrainBuf.ar(2, Impulse.kr(gTriggerSpeed), grainSize1, monobuf1, rate, pos, 4, lfoPan, envbuf, maxGrains: 32, mul:1 );
    
		// do the panning
    // snd = snd*volume;
    // snd=Balance2.ar(grain0,grain1,lfoPan);
		// snd=Balance2.ar(snd[0],snd[1],lfoPan);

    //mix mono input to stereo   
    // snd=Mix.new((grain0*grainAmt)+(snd[0]*loopAmt)+(grain1*grainAmt)+(snd[1]*loopAmt));
    // snd=Mix.new((grain0*grainAmt)+(snd[0]*(1-effect2))+(grain1*grainAmt)+(snd[1]*(1-effect2)));
    
    // snd=Mix.new((grain0*grainAmt)+(snd[0]*(1-effect2))+(grain1)+(snd[1]*(1-effect2)))/2;
		// snd=[snd,snd]/(2+(1-effect2));

    //mix a stereo input
    snd=Balance2.ar(Mix.new(grain0)+(snd[0]*(1-effect1)),Mix.new((grain1)+(snd[1]*(1-effect1))),lfoPan);
    // snd=Balance2.ar(Mix.new((grain0*grainAmt)+(snd[0]*loopAmt)),Mix.new((grain1*grainAmt)+(snd[1]*loopAmt)),lfoPan);

		
		///////////////////////////////////////////////////////
		// ------ START ADDING PLAYER EFFECTS HERE --------- //
		///////////////////////////////////////////////////////

    // snd = CombL.ar(snd,0.5,(effect2/2)+0.05,2); // delay
		// snd = ((1-effect2)*snd) + (effect2 * CombC.ar(snd,0.5,Rand(0.05,0.5),2)); // random delay
		// snd = ((1-effect2)*snd) + (effect2 * CombC.ar(snd,0.5,effect2/2,2)); // random delay
		
		
    // snd = LPF.ar(snd,SinOsc.kr(0.1).exprange(20,2000*effect2)); // modulated filter
		// snd = LPF.ar(snd,SinOsc.kr(0.1).exprange(20,2000)); // modulated filter
    
		// snd = ((1-effect1)*snd) + ((effect1 * 10).tanh / 2); // distortion
		// snd = (snd * Lag.kr((effect1*10))).tanh / 2; // distortion distortion
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
	}).send(s);
	
	
  	// basic players
	// SynthDef("recorder",{
	// 	arg buf,recLevel=1.0,preLevel=0.0;
	// 	RecordBuf.ar(SoundIn.ar([0,1]),buf,0.0,recLevel,preLevel,loop:0,doneAction:2);
	// }).send(s);

  s.sync;
  /////////////////////////////////////
  // define the global effects
  /////////////////////////////////////

	// effects
	SynthDef("effects",{
		arg amp=1.0,effect1=0,effect2=0,effect3=0,delayTime=0.5;

		// collect the sound coming from the bus "0" on 2 channels (stereo)
		var snd=In.ar(0,2);

		///////////////////////////////////////////////////////
		// ----- START ADDING YOUR GLOBAL EFFECTS HERE ----- //
		///////////////////////////////////////////////////////

		// add some nice tape compression
		// snd = AnalogTape.ar(snd,0.9,0.8,0.9,2);

    // distortion distortion
		// snd = (snd*(1-effect1))+(snd * Lag.kr(effect1*3,3)).tanh / 2; 
		// snd = (snd*(1-effect1))+((snd * Lag.kr(effect1,0.25) * 3.dbamp).tanh);


		// add some delay
    snd = ((1-effect2)*snd)+(Lag.kr(effect2,0.25)*CombL.ar(snd,1,delaytime:Lag.kr(delayTime,delayTime*2),decaytime:3));
    // snd = ((1-effect2)*snd)+(Lag.kr(effect2,0.25)*CombL.ar(snd,1,delaytime:0.5,decaytime:3));
    
    
    // snd = ((1-effect2)*snd)+(effect2*CombL.ar(snd,1,delaytime:Lag.kr(delayTime,2),decaytime:3));
		// snd = CombC.ar(snd,0.5,delaytime:Lag.kr(effect2+0.1),decaytime:3);
		// snd = CombC.ar(snd,0.5,delaytime:effect2+0.1,decaytime:3);
		// snd = CombC.ar(snd,0.5,delaytime:0.5,decaytime:1);

		// add some reverb
		snd = ((1-effect3)*snd)+(Lag.kr(effect3,0.25)*FreeVerb2.ar(snd[0],snd[1],0.5,effect3));

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
  // s.queryAllNodes(queryControls: false);

  ~tr_bar = Synth(\trillSynth_bar);
  ~tr_hex = Synth(\trillSynth_hex);
  // ~tr_ring = Synth(\trillSynth_ring);
  ~max30102 = Synth(\max30102);

  s.sync;
  /////////////////////////////////////
  // OSC definitions for the sensors
  /////////////////////////////////////
  OSCdef(\max30102, {|msg| 
    
    if (max30102_pressed == true,{
        ("max30102: " 
          + "ir_bpm: " + msg[3] + ", "
          // + "ir_avg_dc_est: " + msg[4] + ", "
        ).postln;
        sender.sendMsg("/max30102_bpm", msg[3]); // send value to touchdesigner
    });

    if (msg[4] == 0 && max30102_pressed == true,{
      max30102_pressed = false;
      ("max30102 released").postln;
        sender.sendMsg("/max30102_pressed", 0); // send value to touchdesigner

    });
    if (max30102_pressed==false,{
      if ((msg[4] > 1000), {
        max30102_pressed = true;
        sender.sendMsg("/max30102_pressed", 1); // send value to touchdesigner
        ("max30102 presed").postln;
        
        recording = true;
        Routine {
          // u.loadTape(tape:1,filename:"flora_wowless.wav");


          u.recordTape(tape:1,seconds:3,recLevel:2,sender:sender); 3.5.wait;
          0.5.wait; // give time for buffer to load
          u.playTape(tape:1,player:1,rate:0.5,db:10,timescale:1.0);
          u.playTape(tape:1,player:2,rate:0.25,db:10,timescale:1.0);
          // u.playTape(tape:1,player:3,rate:1.25,db:-9,timescale:1.0);
          2.do({arg v,i;
            u.setLfoStartFreqDivisor(tape:1,player:1+i,val:30.rand+30);
            u.setLfoWindowFreqDivisor(tape:1,player:1+i,val:5.rand+10);
            u.setLfoAmpFreqDivisor(tape:1,player:1+i,val:10.rand+20);
            u.setLfoPanFreqDivisor(tape:1,player:1+i,val:10.rand+20);
          });
          recording = false;
        }.play;
      });
      if ((msg[4] < -1000), {
        max30102_pressed = true;
        sender.sendMsg("/max30102_pressed", 1); // send value to touchdesigner
        ("max30102 presed").postln;
        
        recording = true;
        Routine {
          // u.loadTape(tape:1,filename:"flora_wowless.wav");


          u.recordTape(tape:1,seconds:3,recLevel:2,sender:sender); 3.5.wait;
          0.5.wait; // give time for buffer to load
          u.playTape(tape:1,player:1,rate:0.5,db:10,timescale:1.0);
          u.playTape(tape:1,player:2,rate:0.75,db:10,timescale:1.0);
          // u.playTape(tape:1,player:3,rate:1.25,db:-9,timescale:1.0);
          2.do({arg v,i;
            u.setLfoStartFreqDivisor(tape:1,player:1+i,val:30.rand+30);
            u.setLfoWindowFreqDivisor(tape:1,player:1+i,val:5.rand+10);
            u.setLfoAmpFreqDivisor(tape:1,player:1+i,val:10.rand+20);
            u.setLfoPanFreqDivisor(tape:1,player:1+i,val:10.rand+20);
          });
          recording = false;
        }.play;
      });
    });


      // ("max30102: " 
        // + "ir_ac: " + msg[3] + ", "
        // + "ir_beat: " + msg[4] + ", "
        // + "ir_raw: " + msg[5] + ", "
        // + "red_raw: " + msg[6] + ", "
        // + "ir_bpm: " + msg[7] + ", "
        // + "hz: " + msg[8] + ", "
        // + "temp_c: " + msg[9] + ", "
        // + "ir_avg_dc_est: " + msg[10] + ", "
      // ).postln;
    // });
  }, "/max30102");

  OSCdef(\trill_bar, {|msg| 
    // if (msg[3] > 0,{
    if (recording == false && msg[3] == 1,{
      // recording.postln;
      // var touch1
      if (bar_pressed == false){
        sender.sendMsg("/bar_pressed", 1); // send value to touchdesigner
        sender.sendMsg("/bar_location", msg[4]); // send touch location to touchdesigner
        sender.sendMsg("/bar_pressure", msg[5]); // send touch pressure to touchdesigner

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
        // msg[3].do({ arg v,i;



        2.do({ arg v,i;
          var tapenums = [1,2,3,4,5];
          var triggerSpeed = msg[5].linexp(0,1,0.05,1);
          
          // change the grain rate size 
          var grainSize = msg[4].linlin(0,1,0.05,0.25);
          // var grainSize = msg[v+4].linlin(0,1,0.05,1.5).postln;
          // var grainSpeed = msg[v+5].linexp(0,1,0.1,5);
          
          var rates = [0.25, 0.3, 0.5,0.75,1,1.25,1.3];
          var rate = rates[msg[4].linlin(0,1,6,0).floor];
          // var rates = [0.125,0.25, 0.3, 0.5,0.75,1,1.25,1.3, 1.5,1.51,1.52,1.53,1.54,1.55,1.56,1.57,1.58,1.59,1.6, 1.75, 2];
          // var rate = rates[msg[4].linlin(0,1,20,0).floor];
          // var rate = rates[msg[4].linlin(0,1,9,0).floor];
          // var rate = msg[4].linlin(0,1,2,0.25);
          
          u.setRate(tape:tapenums[i],player:1,val:rate);
          u.setGrainSize0(tape:tapenums[v],player:1,val:grainSize);
          u.setGrainSize1(tape:tapenums[v],player:1,val:grainSize*2);

          u.setGrainTriggerSpeed(tape:tapenums[v],player:1,val:triggerSpeed);
          u.setGrainTriggerSpeed(tape:tapenums[v],player:1,val:triggerSpeed);
          // ("grainSize / triggerSpeed" + grainSize+"/"+triggerSpeed).postln;
          
        });
        // bar_pressed = true;
      };
      // msg[0..].postln;

    });

    if (msg[3] == 0,{
        sender.sendMsg("/bar_pressed", 0); // send value to touchdesigner
        //uncomment if only a single press per touch should be registered
        // if (bar_pressed == true){
          // bar_pressed = false; 
        // }
    });
  }, "/trill_bar");

 OSCdef(\trill_hex, {|msg| 
    // if (msg[3] > 0,{
    // if (recording == false && msg[3] == 1,{
    var tapenums = [1,2,3,4,5];
    var effect2 = msg[5].linlin(0,1,0,1);
    if (recording == false && msg[3] == 1,{
      if (hex_pressed == false){
        hex_pressed = true;
      };
      // (msg[4] + " / " + msg[5]).postln;
      sender.sendMsg("/hex_pressed", 1); // send value to touchdesigner
      sender.sendMsg("/hex_location", msg[4]); // send touch location to touchdesigner
      sender.sendMsg("/hex_pressure", msg[5]); // send touch pressure to touchdesigner
      2.do({ arg v,i;
        var dTime = (effect2)+0.1; //delayTimes[dIndex];
        u.setEffect2(tape:tapenums[v],player:1,val:effect2);
        u.setEffectDelayTime(tape:tapenums[v],player:1,val:dTime);
        u.setEffect2(tape:tapenums[v],player:2,val:effect2);
        u.setEffectDelayTime(tape:tapenums[v],player:2,val:dTime);
      })

    });

    if (recording == false && msg[3] == 0,{
      if (hex_pressed == true){
        hex_pressed = false; 
        ("off").postln;
        2.do({ arg v,i;
          u.setEffect2(tape:tapenums[v],player:1,val:0);
        });

        sender.sendMsg("/hex_pressed", 0); // send value to touchdesigner
        
      }
    });
  }, "/trill_hex");


  /////////////////////////////////////
  // load the ube class and define the "looper"
  /////////////////////////////////////
	// load the ube class
  s.sync;

	u=Ube.new(s);

  Routine {
    u.loadTape(tape:2,filename:thisProcess.nowExecutingPath.dirname++"/flora_wowless.wav");
    // u.loadTape(tape:1,filename:thisProcess.nowExecutingPath.dirname++"/kalimba.wav");

    1.wait; // give time for buffer to load
    u.playTape(tape:2,player:1,rate:0.5,db:20,timescale:1.0);
    u.playTape(tape:2,player:2,rate:0.25,db:20,timescale:1.0);
    // u.playTape(tape:2,player:3,rate:0.125,db:20,timescale:1.0);
    2.do({arg v,i;
        u.setLfoStartFreqDivisor(tape:2,player:1+i,val:30.rand+30);
        u.setLfoWindowFreqDivisor(tape:2,player:1+i,val:5.rand+10);
        u.setLfoAmpFreqDivisor(tape:2,player:1+i,val:10.rand+20);
        u.setLfoPanFreqDivisor(tape:2,player:1+i,val:10.rand+20);
    });
    

  }.play;



}