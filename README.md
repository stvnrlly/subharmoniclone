# subharmoniclone

A synth for Monome Norns based on the Moog Subharmonicon.

Move between the pages with E1.

Attach a Grid 128 for more control.

## Page 1: Oscillators & rhythms

Move with E2, adjust with E3.

On the left-ish side, there are dials for the oscillator groups:
- a frequency dial for the main oscillator, which moves that groups base note up the scale
- a subdivision dial for each suboscillator, from 1/1 through 1/16

One the right-ish side, the 4 rhythm divisions, each moving from 1/1 to 1/16.

## Page 2: Sequences

Move with E2, adjust with E3. Press K2 to mute the highlighted step.

Hold K1 while adjusting E3 to randomize the current sequence.

Sequence 1 is on top, sequence 2 below.

## Page 3: Routing

Select a left-hand source with E2, a destination with E3. Press K3 to toggle the connection.

## Beyond

See the params menu for way more options, including panning, filters, quantization, and more.

## Grid

The top 4 rows control oscillators 1-3 and sequence 1. The bottom 4 rows control oscillators 4-6 and sequence 6.

Rows 4 and 8 control the page, which correspond to the pages on the Norns UI: oscillators, sequences, and routing. 

The rightmost key of those rows 4 and 8 is the alt key.

### Oscillators

<img width="529" alt="grid p 1" src="https://user-images.githubusercontent.com/4156602/177902492-64d91a23-a3da-4ba3-a0b9-c4fa29c79067.png">

- Row 1 controls the root note
- Row 2 controls the first subdivision
- Row 3 controls the second subdivision
- Hold alt to adjust oscillator levels

### Sequences

<img width="529" alt="grid p 2" src="https://user-images.githubusercontent.com/4156602/177902534-d699e9d2-8887-45ab-9d7f-338cd6ccdc2d.png">

Sequence pitches are arranged left to right.

Pressing the top row increases that step's pitch. While holding the alt key, it randomly increases all pitches.

Pressing the second row decreases that step's pitch. While holding the alt key, it randomly decreases all pitches.

The third row shows the current step. While holding the alt key, pressing a step will adjust the sequence length.

The two buttons near the alt key switch between forward and backward sequence progression.

### Routing

<img width="529" alt="grid p 3" src="https://user-images.githubusercontent.com/4156602/177902572-d8bd751d-9e8a-4e21-a785-2f7a01f477cc.png">

The three groups are oscillators, sequences, and rhythms.

Holding one will show valid routes. Pressing an option will connect or disconnect that route.

## Install

In maiden, run:
```
;install https://github.com/stvnrlly/subharmoniclone
```

## Public domain

This work is dedicated to the public domain. Copyright is waived under a
[CC0-1.0 license](LICENSE.md).
