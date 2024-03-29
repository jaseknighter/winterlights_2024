s = Server.default;

s.options.numAnalogInChannels = 8; // can be 2, 4 or 8
s.options.numAnalogOutChannels = 8; // can be 2, 4 or 8
s.options.numDigitalChannels = 16;
s.options.maxLogins = 8;
// s.options.bindAddress = "0.0.0.0"; // allow anyone on the network connect to this server

s.options.pgaGainLeft = 5;     // sets the pregain for the left audio input (dB)
s.options.pgaGainRight = 5;    // sets the pregain for the right audio input (dB)
s.options.headphoneLevel = 0; //-1; // sets the headphone level (-dB)
s.options.speakerMuted = 0;    // set true to mute the speaker amp and draw a little less power
s.options.dacLevel = 0;       // sets the gain of the stereo audio dac (+dB)
s.options.adcLevel = 0;       // sets the gain of the stereo audio adc (+dB)

s.options.blockSize = 64; //16;
s.options.numInputBusChannels = 2; //10;
s.options.numOutputBusChannels = 2;


s.waitForBoot {
  var freader = FileReader.read("bela_leader_ip_port.txt", true, true, delimiter:$;).postcs;
  var ip = freader[0][0]; // the port to receive from/send to TouchDesigner
  var port = freader[1][0].asInteger; // the port to send to TouchDesigner
  // var receiver = NetAddr.new(ip); // create the NetAddr to receive msgs from TouchDesigner
  // var receiver = NetAddr.new("127.0.0.1"); // create the NetAddr to receive msgs from TouchDesigner
	var sender = NetAddr.new(ip, port); // create the NetAddr to receive msgs from TouchDesigner
	// var sender = NetAddr.new("127.0.0.1", 7562); // create the NetAddr to receive msgs from TouchDesigner
  var oscReceiverFunc;

  var pairs;
  //i2c bela stuff
  var i2c_bus = 1;
  //var i2c_address = 0x18;
  // var i2c_address_bar = 0x20; //
  var i2c_address_hex = 0x40; //
  var i2c_address_ring1 = 0x38; //
  var i2c_address_ring2 = 0x3e; //
  var noiseThreshold = 0.04; //0.0625; //0.02; // float: 0-0.0625, with 0.0625 being the highest noise thresh
  var prescalerOpt = 2; // int: 1-8 with 1 being the highest sensitivity
  // var touchsigs = DC.ar(0).dup(3); // use 3 touches
  var centroids_bar;
  var centroids_hex;
  var centroids_ring;
  var centroids_ring2;
  var out, ping;	

  var hex_pressed = false;
  var bar_pressed = false;
  var ring_pressed1 = false;
  var ring_pressed2 = false;
  var selectedEnvelope = 1;
  var recording = false;

  var max30102_pressed = false;
  
  var laptop_osc_ip_port = FileReader.read("laptop_ip_port.txt", true, true, delimiter:$;).postcs;

	thisProcess.openUDPPort(7562); 

  ("ip/port: "+ip +"/"+port).postln;

	// oscReceiverFunc = OSCFunc({ arg msg, time, addr, recvPort;


		// ("received td: " + [msg, time, addr, recvPort]).postln;
		// sender.sendMsg("/chan1", msg[1]); // send value to touchdesigner
	// }, '/chan2', receiver);

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
  
  SynthDef(\trillSynth_ring1, {|t_recalibrate_ring=0.0|
    // returns an array with format: [num_active_touches, t1_pos, t1_size, t2_pos, t2_size, t3_pos, t3_size, t4_pos, t4_size, t5_pos, t5_size]
    centroids_ring = TrillCentroids.kr(i2c_bus, i2c_address_ring1, noiseThreshold, prescalerOpt, t_recalibrate_ring);		
		SendReply.kr(Impulse.kr(4), "/trill_ring1", centroids_ring);
    ("trill ring 1 initialized").postln;
  }).send(s);

  SynthDef(\trillSynth_ring2, {|t_recalibrate_ring=0.0|
    // returns an array with format: [num_active_touches, t1_pos, t1_size, t2_pos, t2_size, t3_pos, t3_size, t4_pos, t4_size, t5_pos, t5_size]
    centroids_ring = TrillCentroids.kr(i2c_bus, i2c_address_ring2, noiseThreshold, prescalerOpt, t_recalibrate_ring);		
		SendReply.kr(Impulse.kr(4), "/trill_ring2", centroids_ring);
    ("trill ring 2 initialized").postln;
  }).send(s);
  s.sync;

  SynthDef(\trillSynth_hex, {|t_recalibrate_hex=0.0|
    // returns an array with format: [num_active_touches, t1_pos, t1_size, t2_pos, t2_size, t3_pos, t3_size, t4_pos, t4_size, t5_pos, t5_size]
    centroids_hex = TrillCentroids.kr(i2c_bus, i2c_address_hex, noiseThreshold, prescalerOpt, t_recalibrate_hex);		
		SendReply.kr(Impulse.kr(2), "/trill_hex", centroids_hex);
    ("trill hex initialized").postln;
  }).send(s);
  
  s.sync;
  s.queryAllNodes(queryControls: false);

  ~tr_ring1 = Synth(\trillSynth_ring1);
  s.sync;
  ~tr_ring2 = Synth(\trillSynth_ring2);
  // s.sync;
  // ~tr_hex = Synth(\trillSynth_hex);
  // s.sync;
  ~max30102 = Synth(\max30102);
  s.sync;



OSCdef(\max30102, {|msg| 

  if (max30102_pressed == true,{
      ("fmax30102: " 
        + "ir_bpm: " + msg[3] + ", "
        // + "ir_avg_dc_est: " + msg[4] + ", "
      ).postln;
      sender.sendMsg("/fmax30102_bpm",msg[3]);

      // sender.sendMsg("/max30102_bpm", msg[3]); // send value to touchdesigner
  });

  if (msg[4] == 0 && max30102_pressed == true,{
    max30102_pressed = false;
    ("follower: fmax30102 released"+ msg[4]).postln;
      sender.sendMsg("/fmax30102_pressed", 0); // send value to touchdesigner

  });
  if (max30102_pressed==false,{
    if ((msg[4] > 1000), {
      max30102_pressed = true;
      sender.sendMsg("/fmax30102_pressed", 1); // send value to touchdesigner
      ("follower fmax30102 pressed").postln;
    });
    if ((msg[4] < -1000), {
      max30102_pressed = true;
      sender.sendMsg("/fmax30102_pressed", 1); // send value to touchdesigner
      ("follower fmax30102 presed").postln;
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



 OSCdef(\trill_ring1, {|msg| 
    if (recording == false && msg[3] == 1,{
      if (ring_pressed1 == false){
        ring_pressed1 = true
        // (msg[4] + " / " + msg[5]).postln;
      };
      sender.sendMsg("/fring1_pressed", 1); // send value to touchdesigner
      sender.sendMsg("/fring1_location", msg[4]); // send touch location to touchdesigner
      sender.sendMsg("/fring1_pressure", msg[5]); // send touch pressure to touchdesigner
    });

    if (msg[3] == 0,{
        if (ring_pressed1 == true){
          ring_pressed1 = false; 
          ("ring 1 off").postln;
          sender.sendMsg("/fring1_pressed", 0); // send value to touchdesigner
        }
    });
  }, "/trill_ring1");
 

 OSCdef(\trill_ring2, {|msg| 
    if (msg[3] == 1,{
      if (ring_pressed2 == false){
        ring_pressed2 = true
        // (msg[4] + " / " + msg[5]).postln;
      };
      sender.sendMsg("/fring2_pressed", 1); // send value to touchdesigner
      sender.sendMsg("/fring2_location", msg[4]); // send touch location to touchdesigner
      sender.sendMsg("/fring2_pressure", msg[5]); // send touch pressure to touchdesigner
    });

    if (msg[3] == 0,{
        if (ring_pressed2 == true){
          ring_pressed2 = false; 
          ("ring 2 off").postln;
          sender.sendMsg("/fring2_pressed", 0); // send value to touchdesigner
        }
    });
  }, "/trill_ring2");
 
 
 OSCdef(\trill_hex, {|msg| 
    if (msg[3] == 1,{
      if (hex_pressed == false){
        hex_pressed = true
        // (msg[4] + " / " + msg[5]).postln;
      };
      sender.sendMsg("/fhex_pressed", 1); // send value to touchdesigner
      sender.sendMsg("/fhex_location", msg[4]); // send touch location to touchdesigner
      sender.sendMsg("/fhex_pressure", msg[5]); // send touch pressure to touchdesigner
    });

    if (msg[3] == 0,{
        if (hex_pressed == true){
          hex_pressed = false; 
          ("hex off").postln;
          sender.sendMsg("/fhex_pressed", 0); // send value to touchdesigner
        }
    });
  }, "/trill_hex");
 

}