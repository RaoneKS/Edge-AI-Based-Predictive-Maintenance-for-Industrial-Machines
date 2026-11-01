# DE10-Standard — Systolic CNN implementation

This is a separate Quartus project for the systolic-connected CNN path verified by
`tb/tb_cnn_inference_top.sv`. The older `de10_standard_hw` project remains a
separate time-multiplexed demonstration engine; it is not the systolic top.

## Board operation

Target: Terasic DE10-Standard, Cyclone V SoC, device `5CSXFC6D6F31C6`.

- `KEY[0]`: active-low reset.
- `SW[1]`: 0 selects the committed normal sample; 1 selects the committed outer-race sample.
- Toggle `SW[0]` from low to high to launch an inference. Return it low before the next launch.
- `LEDR[0]`: heartbeat.
- `LEDR[1]`: inference busy.
- `LEDR[2]`: done latched.
- `LEDR[4:3]`: predicted class (0 normal, 1 inner, 2 ball, 3 outer).
- `LEDR[5]`: selected sample mode.
- `LEDR[6]`: sticky systolic overflow indicator.
- `LEDR[9:7]`: board-controller state.

The wrapper uses the two demo windows emitted by
`verification/scripts/prepare_de10_model_data.py`; it streams one selected
256-sample window through `cnn_inference_top`. The four class logits are
available internally for SignalTap/debug but are not routed to board pins.

## Build and timing

From the repository root:

```bash
bash quartus/de10_systolic_cnn/run_quartus.sh
```

Set `QUARTUS_SH`, `QUARTUS_STA`, or `PYTHON_BIN` to override automatic
discovery. The script prepares model ROMs, runs the full Quartus compile
(analysis/synthesis, fit, assembler), then runs TimeQuest in slow and fast
models. Reports are written under:

```text
quartus/de10_systolic_cnn/output_files/acceptance_logs/
quartus/de10_systolic_cnn/output_files/sta_reports/
```

Inspect `clocks_slow.txt` for the recognized 20 ns `CLOCK_50`, both
`check_timing` reports for unconstrained paths, `setup_slow.txt` for worst
setup slack, and `hold_fast.txt` for worst hold slack. Successful command
exit alone is not sufficient to claim that timing meets 50 MHz: verify the
clock and nonnegative relevant setup/hold slack in those reports.

No compile, fit, timing, programming, or physical-board result is claimed until
the scripts are run and the generated reports are reviewed.
