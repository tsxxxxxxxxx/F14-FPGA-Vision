# Only physical asynchronous pushbutton inputs to the first synchronizer FF.
# Do not false-path internal synchronizer stages or any camera/DDR data path.
set_false_path -from [get_ports {key_data[*]}] -to [get_pins {u_display_mode/keys_meta[*]~FF|D}]

# Instrumentation only: registered Gray frame counter -> first display-clock FF.
# The clocks are unrelated; ordinary phase-based setup analysis is not valid.
# Bound transfer delay to 5 ns, below the constrained 6 ns source clock period.
# This is NOT a false path. cg1 -> cg2 remains a normal timed pixel-clock path.
# No image data, FIFO, DDR control, or second synchronizer stage is relaxed.
# Source clock collection also covers the MSB shared with cam_count by synthesis.
set_max_delay -from [get_clocks {csi_rxc_i}] -to [get_pins {u_metrics/cg1[*]~FF|D}] 5
set_min_delay -from [get_clocks {csi_rxc_i}] -to [get_pins {u_metrics/cg1[*]~FF|D}] 0
