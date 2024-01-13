
(
s.waitForBoot {
	var sender;
	OSCdef.freeAll;

	sender = NetAddr.new("127.0.0.1", 1001); // create the NetAddr to send to TouchDesigner

	SynthDef(\osc_out, {
		//code taken from blender example: "https://scsynth.org/t/sending-osc-messages-from-sc-to-blender/4825/4"
		var mousex = MouseX.kr(0,1);
		var mousey = MouseY.kr(0,1);
		var mousepress = MouseButton.kr(minval:0,maxval:1,lag:0);

		SendReply.kr(Impulse.kr(10), '/tdsend', [mousex, mousey, mousepress ]);
	}).add;

	s.sync;

	Synth(\osc_out); // start the synth

	//osc definition for sending a message
	OSCdef(\send_msg, {
		| msg, time, addr, recvPort |
		//NOTE: msg[3] is mouse x, msg[4] is mouse y, msg[5] is mouse pressed
		msg.debug("msg");
		//touch bar
		// sender.sendMsg("/bar_location", msg[3]);
		// sender.sendMsg("/bar_pressure", msg[4]);
		// sender.sendMsg("/bar_pressed", msg[5]);

		//touch ring
		// sender.sendMsg("/ring_location", msg[3]);
		// sender.sendMsg("/ring_pressure", msg[4]);
		// sender.sendMsg("/ring_pressed", msg[5]);

		//max30102 sensor
		sender.sendMsg("/max30102_bpm", msg[3].linlin(0,1,60,140));
		sender.sendMsg("/max30102_pressed", msg[5]);
		// sender.sendMsg("/recording", msg[5]);

	}, '/tdsend');

};
)

