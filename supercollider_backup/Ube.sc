Ube {

	var server;
	var bufs;
  var monobufs;
	var oscs;
	var <syns;
	var win;
	var recording;
	var windata;

	*new {
		arg argServer;
		^super.new.init(argServer);
	}

	init {
		arg argServer;

		server=argServer;

		// initialize variables
		bufs = Dictionary.new();
		monobufs = Dictionary.new();
		syns = Dictionary.new();
		oscs = Dictionary.new();
		windata = Array.newClear(128);
		recording = false;



		// basic players
		SynthDef("recorder",{
			arg buf,recLevel=1.0,preLevel=0.0;
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
			windata.put(player,[tape,posStart,posEnd,pos,volume,pan]);
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
		arg tape=1,player=1,rate=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		("set rate").postln;
		syns.at(playid).set(\baseRate,rate);
	}

	setR1 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\rand1,val);
	}

	setR2 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\rand2,val);
	}

	setR3 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\rand3,val);
	}

		setR4 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\rand4,val);
	}

		setR5 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\rand5,val);
	}

		setR6 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\rand6,val);
	}

		setR7 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\rand7,val);
	}

		setR8 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\rand8,val);
	}

		setR9 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\rand9,val);
	}

		setR10 {
		arg tape=1,player=1,val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		syns.at(playid).set(\rand10,val);
	}

	setArg {
		arg tape=1,player=1,synsarg="\rate",val=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		("set arg: "++ synsarg ++ " :" ++val).postln;
		syns.at(playid).set(synsarg,val);
	}

	setTimescale {
		arg tape=1,player=1,timescale=1.0;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
		("set timescale").postln;
		syns.at(playid).set(\timescale,timescale);
	}

	playTape {
		arg tape=1,player=1,rate=1.0,db=0.0,timescale=1;
		var amp=db.dbamp;
		var tapeid="tape"++tape;
		var playid="player"++player++tapeid;
    var buf=bufs.at(tapeid);
    var bufl, bufr;

		if (buf.isNil,{
			("[ube] cannot play empty tape"+tape).postln;
			^0
		});
		("[ube] player"+player+"playing tape"+tape).postln;

		if (syns.at(playid).notNil,{
			("syns.at is not nil").postln;
			syns.at(playid).free;
			// syns.removeAt(playid);
			syns.put(playid,Synth.head(server,"looper",[\tape,tape,\player,player,\buf,buf,\baseRate,rate,\amp,amp,\timescale,timescale]).onFree({
          ("[ube] player"+player+"finished.").postln;
		    }));
		},{
			("syns.at is nil").postln;
        // new code to split stereo buffer into two mono bufs from: https://scsynth.org/t/load-stereo-file-to-mono-buffer/5043/2
        if (monobufs.at(tapeid).isNil,{
          fork{
            ("monobufs is nil. split the stereo file: ").postln;
            bufl=Buffer.alloc(server, buf.sampleRate*(buf.numFrames/2));
            bufr=Buffer.alloc(server, buf.sampleRate*(buf.numFrames/2));
            FluidBufCompose.processBlocking(server,source:buf,destination:bufl,startChan:0,numChans:1,action:{
              FluidBufCompose.processBlocking(server,source:buf,destination:bufr,startChan:1,numChans:1,action:{
                syns.put(playid,Synth.head(server,"looper",[\tape,tape,\player,player,\buf,buf,\monobuf0,bufl,\monobuf1,bufr,\baseRate,rate,\amp,amp,\timescale,timescale]).onFree({
                  ("[ube] player"+player+"finished with two mono bufs created.").postln;
                }));
                NodeWatcher.register(syns.at(playid));

              });
            });

          }
        },{
          syns.put(playid,Synth.head(server,"looper",[\tape,tape,\player,player,\buf,bufs.at(tapeid),\monobuf0,monobufs.at(tapeid)[0],\monobuf1,monobufs.at(tapeid)[1],\baseRate,rate,\amp,amp,\timescale,timescale]).onFree({
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
		arg tape=1,seconds=30,recLevel=1.0;
		var tapeid="tape"++tape;
		("record tape").postln;
		Buffer.alloc(server,server.sampleRate*seconds,2,{ arg buf;
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
				("not nil? " + bufs.at(tapeid).notNil);
				if (bufs.at(tapeid).notNil,{
					bufs.at(tapeid).free;
				});
				bufs.put(tapeid,buf);
				// turn on the main fx again
				syns.at("fx").set(\amp,1);
				recording=false;
				// update the buffer
			}));
			NodeWatcher.register(syns.at("record"++tape));

		});

	}

	gui {
		arg height=400,width=600,spacing=20,padding=20;
		var w,a;
		var lastHeight=height;
		var lastWidth=width;
		var lastNum=0;
		var changed=true;
		var debounce=0;
		if (win.notNil,{
			// return early
			^nil
		});
		AppClock.sched(0,{
			win = Window.new("ube",Rect(10,100,width,height)).front;
			w=win;
			w.view.background_(Color.new255(236,242,255));
			w.drawFunc = {
				var num=1;
				var x,availableHeight,h;
				windata.do{ arg v;
					if (v.notNil,{
						num=num+1;
					});
				};
				x=(w.bounds.width-(2*padding));
				availableHeight=((w.bounds.height-(padding*2))/num);
				h=(availableHeight-spacing);
				if (recording,{
					debounce=10;
				});
				if (lastWidth!=w.bounds.width,{
					debounce=10;
				});
				if (lastHeight!=w.bounds.height,{
					debounce=10;
				});
				if (lastNum!=num,{
					debounce=10;
				});
				lastNum=num;
				lastHeight=w.bounds.height;
				lastWidth=w.bounds.width;
				if (debounce==1,{
					var tapeid=nil;
					debounce=0;
					if (windata.size>0,{
						tapeid="tape"++windata[0][0].asInteger;
						tapeid=tapeid.asString;
					});
					if (tapeid.notNil,{
						tapeid="tape1";
						if (a.notNil,{
							a.close;
						});
						a = SoundFileView.new(w, Rect(padding,padding, x, h));
						bufs.at(tapeid).loadToFloatArray(0, -1, {|floatArray|
							AppClock.sched(0,{
								a.setData(floatArray*1.5,4096,0,1,bufs.at(tapeid).sampleRate);
								a.refresh;
							});
						});
						a.gridOn = false;
						a.timeCursorOn = false;
						a.drawsCenterLine  = false;
						a.drawsBoundingLines = false;
						a.peakColor=Color.new255(99,89,133,150);
						a.rmsColor=Color.new255(99,89,133,60);
						a.background_(Color.new255(236,242,255,0));
					});

				},{
					if (debounce>0,{
						debounce=debounce-1;
					});
				});
				windata.do{ arg v,j;
					var i=j+1;
					if (v.notNil,{
						var y=padding+(i*availableHeight)-80;
						var posStart=v[1];
						var posEnd=v[2];
						var posWidth=(v[2]-v[1]);
						var pos=v[3];
						var volume=v[4];
						var pan=v[5];
						var volume01=volume.ampdb.linlin(-96,12,0,1)+0.001;
						var cc=Color.new255(99,89,133,255*volume01);
						// var cc=Color.new255(96,150,180,255*volume01);
            // ("y: "++y).postln;
						// draw waveform area
						Pen.color = cc;
						Pen.addRect(
							Rect.new(posStart*x+(padding),y,posWidth*x, h)
						);
						Pen.perform(\fill);

						// draw playhead
						Pen.color = Color.white(0.5,0.5);
						Pen.addRect(
							Rect(pos*x+(padding)-2, y, 4, h)
						);
						Pen.perform(\fill);

						// draw pan symbol
						Pen.color = cc;
						Pen.addRect(
							Rect(pan*x+(padding)-8,y,16,h)
						);
						Pen.perform(\fill);

					});
				}
			};
		});

		AppClock.sched(0,{
			if (w.notNil,{
				if (w.isClosed.not,{
					w.refresh;
				});
			});
			0.04
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
		syns.keysValuesDo({ arg k, val;
			val.free;
		});
	}
}
