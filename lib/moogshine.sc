// SC class exercise 3: third (and final) adaptation
// 8-voice polyphony + smoothing

Moogshine {

	classvar <voiceKeys;

	var <globalParams;
	var <voiceParams;
	var <voiceGroup;
	var <singleVoices;

	*initClass {
		voiceKeys = [ \1, \2, \3, \4, \5, \6, \7, \8 ];
		StartUp.add {
			var s = Server.default;

			s.waitForBoot {

				SynthDef("Moogshine", {
					arg out = 0, stopGate = 1,
					freq, cutoff, resonance, cutoff_env,
					attack, release,
					amp, noise_amp, pan,
					freq_slew, amp_slew, noise_slew, pan_slew;

					var slewed_freq = freq.lag3(freq_slew);
					var pulse = Pulse.ar(freq: slewed_freq);
					var saw = Saw.ar(freq: slewed_freq);
					// var sub = Pulse.ar(freq: slewed_freq/sub_div);
					var noise = WhiteNoise.ar(mul: noise_amp.lag3(noise_slew));
					var mix = Mix.ar([pulse,saw,noise]);

					var envelope = EnvGen.kr(
						envelope: Env.perc(attackTime: attack, releaseTime: release, level: 1),
						gate: stopGate,
						doneAction: 2
					);
					// NEW: integrate slew using '.lag3'
					var filter = MoogFF.ar(
						in: mix,
						freq: Select.kr(cutoff_env > 0, [cutoff, cutoff * envelope]),
						gain: resonance
					);
					// NEW: integrate slew using '.lag3'
					var signal = Pan2.ar(filter*envelope,pan.lag3(pan_slew));
					// NEW: bring 'amp' to final output calculation + integrate slew using '.lag3'
					Out.ar(out, signal * amp.lag3(amp_slew));
				}).add;
			}
		}
	}

	*new {
		^super.new.init;
	}

	init {

		var s = Server.default;

		voiceGroup = Group.new(s);

		// NEW: create a 'globalParams' Dictionary to hold the parameters common to each voice
		globalParams = Dictionary.newFrom([
			\freq, 400,
			// \sub_div, 2,
			\noise_amp, 0.1,
			\cutoff, 8000,
			\cutoff_env, 1,
			\resonance, 3,
			\attack, 0,
			\release, 0.4,
			\amp, 0.5,
			\pan, 0,
			\freq_slew, 0.0,
			\amp_slew, 0.05,
			\noise_slew, 0.05,
			\pan_slew, 0.5;
		]);

		// NEW: create a 'singleVoices' Dictionary to control each voice individually
		singleVoices = Dictionary.new;
		// NEW: 'voiceParams' will hold parameters for our individual voices
		voiceParams = Dictionary.new;
		// NEW: for each of the 'voiceKeys'...
		voiceKeys.do({ arg voiceKey;
			// NEW: create a 'singleVoices' entry in the 'voiceGroup'...
			singleVoices[voiceKey] = Group.new(voiceGroup);
			// NEW: and add unique copies of the globalParams to each voice
			voiceParams[voiceKey] = Dictionary.newFrom(globalParams);
		});
	}

	// NEW: helper function to manage voices
	playVoice { arg voiceKey, freq;
		// NEW: if this voice is already playing, gracefully release it
		singleVoices[voiceKey].set(\stopGate, -1.05); // -1.05 is 'forced release' with 50ms (0.05s) cutoff time
		// NEW: set '\freq' parameter for this voice to incoming 'freq' value
		voiceParams[voiceKey][\freq] = freq;
		// NEW: make sure to index each of our tables with our 'voiceKey'
		Synth.new("Moogshine", [\freq, freq] ++ voiceParams[voiceKey].getPairs, singleVoices[voiceKey]);
	}

	trigger { arg voiceKey, freq;
		// NEW: if the voice is 'all'...
		if( voiceKey == 'all',{
		// NEW: then do the following for all of the voiceKeys:
			voiceKeys.do({ arg vK;
				// NEW: use 'this.' to call functions specific to this instance
				this.playVoice(vK, freq);
			});
		}, // NEW: else, if the voice is not 'all':
		{
			// NEW: play the specified voice
			this.playVoice(voiceKey, freq);
		});
	}

	adjustVoice { arg voiceKey, paramKey, paramValue;
		singleVoices[voiceKey].set(paramKey, paramValue);
		voiceParams[voiceKey][paramKey] = paramValue
	}

	setParam { arg voiceKey, paramKey, paramValue;
		// NEW: if the voiceKey is 'all'...
		if( voiceKey == 'all',{
			// NEW: then do the following for all of the voiceKeys:
			voiceKeys.do({ arg vK;
				this.adjustVoice(vK, paramKey, paramValue);
			});
		}, // NEW: else, if the voiceKey is not 'all':
		{
			// NEW: send changes to the correct 'singleVoices' index,
			// which will immediately affect the 'voiceKey' synth
			this.adjustVoice(voiceKey, paramKey, paramValue);
		});
	}

	// NEW: since each 'singleVoices' is a sub-Group of 'voiceGroup',
	//   we can simply pass a '\stopGate' to the 'voiceGroup' Group.
	// IMPORTANT SO OUR SYNTHS DON'T RUN PAST THE SCRIPT'S LIFE
	freeAllNotes {
		voiceGroup.set(\stopGate, -1.05);
	}

	free {
		// IMPORTANT
		voiceGroup.free;
	}

}