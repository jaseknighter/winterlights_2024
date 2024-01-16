Ube {

	var server;
	var bufs;
  var monobufs;
  // var envbufs;
	var oscs;
	var <syns;
	// var win;
	var recording;
	// var windata;
  var winenv;
  var envbuf;
	*new {
		arg argServer;
		^super.new.init(argServer);
	}

	init {
		arg argServer;

    var gWinenv1, gWinenvBuf1, gWinenv2, gWinenvBuf2, 
    gWinenv3, gWinenvBuf3, gWinenv4, gWinenvBuf4;

    server=argServer;

		// initialize variables
		bufs = Dictionary.new();
		monobufs = Dictionary.new();
		syns = Dictionary.new();
		oscs = Dictionary.new();
		// envbufs = Dictionary.new();
    winenv=Env([0, 1, 0], [1,1], [8, -8]);
    envbuf = Buffer.sendCollection(server, winenv.discretize, 1);

		// windata = Array.newClear(128);
		recording = false;

    // gWinenv1 = Env([0, 1, 0], [1, 1], [8, -8]);
    // gWinenvBuf1  = Buffer.sendCollection(server, gWinenv1.discretize, 1);
    // gWinenv2 = Env([0, 1, 0], [1, 1], [4, -4]);
    // gWinenvBuf2  = Buffer.sendCollection(server, gWinenv2.discretize, 1);
    // gWinenv3 = Env([0, 1, 0], [1, 1], [0, -4]);
    // gWinenvBuf3  = Buffer.sendCollection(server, gWinenv3.discretize, 1);
    // gWinenv4 = Env([0, 1, 0], [1, 1], [4, 4]);
    // gWinenvBuf4  = Buffer.sendCollection(server, gWinenv4.discretize, 1);
    // envbufs.put("env1",gWinenvBuf1);
    // envbufs.put("env2",gWinenvBuf1);
    // envbufs.put("env3",gWinenvBuf1);
    // envbufs.put("env4",gWinenvBuf1);


		// basic players
		SynthDef("recorder",{
			arg buf,recLevel=1.0,preLevel=0.0;
      //mono recorder
			// RecordBuf.ar(SoundIn.ar(1),buf,0.0,recLevel,preLevel,loop:0,doneAction:2);
			//stereo recorder
      RecordBuf.ar(SoundIn.ar([0,1]),buf,0.0,recLevel,preLevel,loop:0,doneAction:2);
		}).send(server);


		oscs.put("position",OSCFunc({ |msg|
			var oscRoute=msg[0];
			var synNum=msg[1];
			var dunno=msg[2];
			var tape=msg[3].asInteger;
			var player=msg[4].asInteger;
			var posStart=msg[5];
			var posEnd=msg[6];
			var pos=msg[7];
			var volume=msg[8];
			var pan=msg[9];
			// windata.put(player,[tape,posStart,posEnd,pos,volume,pan]);
		}, '/position'));

		server.sync;

		syns.put("fx",Synth.tail(server,"effects"));

		"done loading.".postln;
	}

	pauseTape {
		arg tape=1,player=1;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		("pause").postln;
		syns.at(playid).run(false);
	}

	restartTape {
		arg tape=1,player=1;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		("restart").postln;
		syns.at(playid).run(true);
	}

	setRate {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		// (playid++ ": set rate "++val).postln;
		syns.at(playid).set(\baseRate,val);
	}

	setLfoStartFreqDivisor {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\lfoStartFreqDivisor,val);
	}

	setLfoWindowFreqDivisor {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\lfoWindowFreqDivisor,val);
	}

	setLfoAmpFreqDivisor {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\lfoAmpFreqDivisor,val);
	}

  setLfoPanFreqDivisor {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\lfoPanFreqDivisor,val);
	}

  setGrainWinEnv {
    
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
    // 20.do({arg i; Buffer.cachedBufferAt(server, i).postln;});
		syns.at(playid).set(\envbuf,val);
	}

  setGrainSize0 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\grainSize0,val);
	}

  setGrainSize1 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\grainSize1,val);
	}

  setGrainTriggerSpeed {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
    syns.at(playid).set(\gTriggerSpeed,val);
	}

  setGrainLoopMix {
		arg tape=1,player=1,loopAmt=0.5,grainAmt=0.5;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
    syns.at(playid).set(\loopAmt,loopAmt);
		syns.at(playid).set(\grainAmt,grainAmt);

  }



	// setArg {
	// 	arg tape=1,player=1,synsarg="\rate",val=1.0;
	// 	var tapeid="tape"++tape;
	// 	var playid="player"++player++tapeid;
	// 	("set arg: "++ synsarg ++ " :" ++val).postln;
	// 	syns.at(playid).set(synsarg,val);
	// }

	setTimescale {
		arg tape=1,player=1,timescale=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		("set timescale").postln;
		syns.at(playid).set(\timescale,timescale);
	}

	setEffect1 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\effect1,val);
		syns.at("fx").set(\effect1,val);
	}

	setEffect2 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\effect2,val);
    syns.at("fx").set(\effect2,val);
	}

	setEffectDelayTime {
		arg tape=1,player=1,val=1;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at("fx").set(\delayTime,val);
	}

	playTape {
		arg tape=1,player=1,rate=1.0,db=0.0,timescale=1;
		var amp=db.dbamp;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
    var buf=bufs.at(tapeid);
    var bufl, bufr;
    // server.cachedBuffersDo({ |buf| buf.postln; buf.isNil.postln; });

		if (buf.isNil,{
			("[ube] cannot play empty tape"+tape).postln;
			^0
		});
		("[ube] player"+player+"playing tape"+tape).postln;

		if (syns.at(playid).notNil,{
			(playid + " is not nil ").postln;
      
      fork{
        ("monobufs is nil. split the stereo file: ").postln;
        bufl=Buffer.alloc(server, buf.sampleRate*(buf.numFrames/2));
        bufr=Buffer.alloc(server, buf.sampleRate*(buf.numFrames/2));
        FluidBufCompose.processBlocking(server,source:buf,destination:bufl,startChan:0,numChans:1,action:{
          FluidBufCompose.processBlocking(server,source:buf,destination:bufr,startChan:1,numChans:1,action:{
            syns.at("fx").set(\amp,0);
            syns.at(playid).free;
            // envbufs.at(playid).free;
            // envbufs.put(playid,envbuf);
            syns.put(playid,Synth.head(server,"looper",[\tape,tape,\player,player,\buf,buf,\envbuf,envbuf,\monobuf0,bufl,\monobuf1,bufr,\baseRate,rate,\amp,amp,\timescale,timescale]).onFree({
              ("[ube] player"+player+"finished with two mono bufs created.").postln;
              syns.at("fx").set(\amp,1);
            }));
            NodeWatcher.register(syns.at(playid));

          });
        });

      }
		},{
			("syns.at is nil").postln;
        // envbufs.put(playid,envbuf);
        // new code to split stereo buffer into two mono bufs from: https://scsynth.org/t/load-stereo-file-to-mono-buffer/5043/2
        if (monobufs.at(tapeid).isNil,{
          fork{
            ("monobufs is nil. split the stereo file: ").postln;
            bufl=Buffer.alloc(server, buf.sampleRate*(buf.numFrames/2));
            bufr=Buffer.alloc(server, buf.sampleRate*(buf.numFrames/2));
            FluidBufCompose.processBlocking(server,source:buf,destination:bufl,startChan:0,numChans:1,action:{
              FluidBufCompose.processBlocking(server,source:buf,destination:bufr,startChan:1,numChans:1,action:{
                syns.put(playid,Synth.head(server,"looper",[\tape,tape,\player,player,\buf,buf,\envbuf,envbuf,\monobuf0,bufl,\monobuf1,bufr,\baseRate,rate,\amp,amp,\timescale,timescale]).onFree({
                  ("[ube] player"+player+"finished with two mono bufs created.").postln;
                  // 20.do({arg i; Buffer.cachedBufferAt(server, i).postln;});
                }));
                NodeWatcher.register(syns.at(playid));

              });
            });

          }
        },{
          syns.put(playid,Synth.head(server,"looper",[\tape,tape,\player,player,\buf,bufs.at(tapeid),\envbuf,envbuf,\monobuf0,monobufs.at(tapeid)[0],\monobuf1,monobufs.at(tapeid)[1],\baseRate,rate,\amp,amp,\timescale,timescale]).onFree({
            ("[ube] player"+player+"finished.").postln;
          }));
          NodeWatcher.register(syns.at(playid));

        });
		});
	}

	loadTape {
		arg tape=1,filename="";
		var tapeid="tape"++tape;
		if (filename=="",{
			("[ube] error: need to provide filename").postln;
			^nil
		});
		monobufs.put(tapeid,[Buffer.readChannel(server,filename,channels:0,action:{ arg buf;
			("[ube] mono buffer 0 loaded"+tape+filename).postln;
		}),Buffer.readChannel(server,filename,channels:1,action:{ arg buf;
			("[ube] mono buffer 1 loaded"+tape+filename).postln;
		})]);
		bufs.put(tapeid,Buffer.read(server,filename,action:{ arg buf;
			("[ube] loaded"+tape+filename).postln;
		}));
	}

	recordTape {
		arg tape=1,seconds=30,recLevel=1.0,sender;
		var tapeid="tape"++tape;
		("record tape").postln;
    sender.sendMsg("/recording",1); // send value to touchdesigner
		Buffer.alloc(server,server.sampleRate*seconds,2,{ arg buf; //stereo recording
			// silence all output to prevent feedback?
			syns.at("fx").set(\amp,0);
			recording=true;

			// initiate recorder
			("[ube] record"+buf.bufnum+tape+seconds+recLevel).postln;
			syns.put("record"++tape,Synth.head(server,"recorder",[\buf,buf,\recLevel,recLevel,\preLevel,0]).onFree({
        ("[ube] recording to buf"+buf.bufnum+"finished.").postln;
				// update the buffers in synths
				syns.keysValuesDo({ arg k,v;
					if (k.contains(tapeid),{
						("[ube] updating"+k+"with buffer"+buf.bufnum).postln;
						syns.at(k).set(\buf,buf);
					});
				});

				// // update the buffer
        /*
				if (bufs.at(tapeid).notNil,{
          ("free bufs at "+tapeid).postln;
					bufs.at(tapeid).free;
				});
				if (monobufs.at(tapeid).notNil,{
          ("free monobufs at"+tapeid).postln;
					monobufs.at(tapeid).free;
				});
        */
				bufs.put(tapeid,buf);
                // turn on the main fx again
        Routine({
          5.wait;
				  syns.at("fx").set(\amp,1);
          ("vol up").postln;
        }).play;
        sender.sendMsg("/recording",0); // send value to touchdesigner
				recording=false;

			}));
			NodeWatcher.register(syns.at("record"++tape));

		});

	}

	free {
		oscs.keysValuesDo({ arg k, val;
			val.free;
		});
		bufs.keysValuesDo({ arg k, val;
			val.free;
		});
		monobufs.keysValuesDo({ arg k, val;
			val.free;
		});
		// envbufs.keysValuesDo({ arg k, val;
		// 	val.free;
		// });
		syns.keysValuesDo({ arg k, val;
			val.free;
		});
	}
}
