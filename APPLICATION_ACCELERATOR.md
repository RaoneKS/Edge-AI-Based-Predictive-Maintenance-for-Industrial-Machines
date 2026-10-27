# Application Accelerator Verification

## Source of truth

The deployed fixed-model CNN arithmetic is defined by:

- `ml/hardware_reference.py`
- `ml/artifacts/accelerator_manifest.json`
- exported INT8 weights/biases under `ml/artifacts/`
- `quartus/de10_standard_hw/model_data/`

The board-level RTL is `quartus/de10_standard_hw/bearing_cnn_demo.sv`, with the DE10-Standard board wrapper in `quartus/de10_standard_hw/de10_standard_hw_top.sv`.

## CNN datapath

```text
256-sample INT8 window
        |
        v
Conv1: 1 -> 8, K=5, same padding
        |   8 output MAC lanes in parallel
        v
ReLU + >>8 + INT8 saturation
        |
        v
MaxPool1D(2)
        |
        v
Conv2: 8 -> 8, K=3, same padding
        |   K=24 flattened as channel-major × tap
        |   3 blocks × 8 input lanes
        |   64 products per block cycle
        v
ReLU + >>8 + INT8 saturation
        |
        v
GAP over 128 samples
        |   signed truncation toward zero /128
        v
8-element INT8 feature vector
        |
        v
8 x 8 classifier MAC
        |
        v
>>5 + INT8 saturation
        |
        v
Argmax(logits[0:3])
```

The board application uses a 64-MAC parallel datapath; it is separate from the reusable generic tiled accelerator baseline.

## Exact exported-model verification

The exact integer deployment reference was evaluated over the recording-level test holdout:

| Class | Correct | Total |
|---|---:|---:|
| normal | 128 | 128 |
| inner | 124 | 128 |
| ball | 83 | 128 |
| outer | 127 | 128 |
| **Total** | **462** | **512** |

**Exact exported INT8 reference accuracy: 90.234375% (462/512).**

This is the exact software deployment-reference result on the stated holdout. It is not a claim that the two-vector board demonstration measures full-dataset hardware accuracy. The older `89.453125%` value came from the training script's rounded requantization path rather than the exact deployed shift-only reference.

## Demo-vector golden results

The exported board demo reference gives:

| Mode | Expected logits | Predicted class |
|---|---|---:|
| normal | `[39, 2, -36, -51]` | 0 |
| outer bearing fault | `[-33, 3, 9, 15]` | 3 |

The SystemVerilog testbench checks both the logits and predicted class. The recorded simulation output was:

```text
PASS select_outer=0 class=0 cycles=8969
PASS select_outer=1 class=3 cycles=8969
BEARING_CNN_DEMO_TEST PASSED
```

Run the simulation from the directory used for the model-data relative paths:

```bash
cd quartus/de10_standard_hw
iverilog -g2012 -o /tmp/tb_bearing_cnn_demo -s tb_bearing_cnn_demo \
  bearing_cnn_demo.sv ../../tb/tb_bearing_cnn_demo.sv
vvp /tmp/tb_bearing_cnn_demo
```

## DE10-Standard implementation status

The design was compiled with **Quartus Prime Lite 25.1** for the Cyclone V SoC device `5CSXFC6D6F31C6`. The compiled `.sof` was programmed to the FPGA JTAG device (device index 2 in the detected chain).

**Latest recorded full compilation:** successful, 0 errors and 12 warnings. The report marked setup and hold timing as fully constrained.

| Metric | Recorded result |
|---|---:|
| Adaptive Logic Modules (ALMs) | 3,764 (about 9%) |
| Registers | 5,798 |
| M10K blocks | 14 (about 3%) |
| DSP blocks | 65 (about 58%) |
| Setup slack, slow 85 °C corner | +3.272 ns |
| Hold slack, slow 85 °C corner | +0.217 ns |
| Minimum hold slack across reported corners | +0.118 ns |

The board clock constraint is 50 MHz (20 ns). The asynchronous reset and switches have explicit timing exceptions, and the LED outputs are excluded from external setup/hold analysis because they are human-visible indicators rather than synchronous data outputs. Synchronizer identification is enabled for metastability analysis; the reported MTBF is a Quartus tool estimate, not a guarantee.

### Physical demonstration observed on the board

The user reported programming the latest `.sof` and manually checking both demo modes:

- **Normal mode:** heartbeat LED blinking, done LED on, class LEDs off (class 0).
- **Outer-fault mode:** heartbeat LED blinking, done LED on, class bits indicate class 3, and the mode LED is on.

These checks confirm the two demonstration cases and LED decoding on the physical board. They do **not** establish real-time sensor acquisition, a live vibration stream, or end-to-end dataset accuracy on the FPGA. The current demo selects stored input data through a switch.

## Rebuild

The build script regenerates model ROM data before running Quartus. It accepts `QUARTUS_SH` to select a specific Quartus installation and otherwise attempts to discover an installed executable.

```bash
cd quartus/de10_standard_hw
QUARTUS_SH="$HOME/intelFPGA/25.1lite/quartus/bin/quartus_sh" ./run_quartus.sh
```

The Quartus install path above matches the environment used for the recorded validation; change it to the installed path on another machine. Review the current compilation report and warnings after every rebuild, because resource and timing values can change with source, constraints, device, or tool-version changes.
