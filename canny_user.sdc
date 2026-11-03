# New H button only, to its first synchronizer. F13 constraints are unchanged.
set_false_path -from [get_ports {lcd_g7_0_i[6]}] -to [get_pins {u_canny_button/meta~FF|D}]

# Single-bit handshakes and Gray FIFO pointers only. Payloads are stable before
# synchronized publication. Bound physical propagation, not downstream logic.
# All second/later synchronizer stages remain normally timed.
# FIFO payload storage is published only after Gray-pointer synchronization.
# These bounded bundled-data paths have at least two destination clocks of
# settling time. Do not apply these constraints to arbitrary image datapaths.
# Capture payload uses true dual-clock RAM with a destination-clock read port.
# Only the display FIFO uses bundled FF data crossing.
set_max_delay -from [get_pins {*u_canny/display_fifo/mem*~FF|CLK}] -to [get_clocks {clk_pixel_2x}] 6
set_min_delay -from [get_pins {*u_canny/display_fifo/mem*~FF|CLK}] -to [get_clocks {clk_pixel_2x}] 0
set_max_delay -from [get_clocks {clk_pixel_2x}] -to [get_pins {*u_canny/cbq[0]~FF|D *u_canny/dm[*]~FF|D *u_canny/eq[0]~FF|D *u_canny/cdq[0]~FF|D *u_canny/paq[0]~FF|D *u_canny/epochq[0]~FF|D *u_canny/capture_fifo/wm[*]~FF|D *u_canny/display_fifo/rm[*]~FF|D}] 5
set_min_delay -from [get_clocks {clk_pixel_2x}] -to [get_pins {*u_canny/cbq[0]~FF|D *u_canny/dm[*]~FF|D *u_canny/eq[0]~FF|D *u_canny/cdq[0]~FF|D *u_canny/paq[0]~FF|D *u_canny/epochq[0]~FF|D *u_canny/capture_fifo/wm[*]~FF|D *u_canny/display_fifo/rm[*]~FF|D}] 0
set_max_delay -from [get_clocks {clk_sys}] -to [get_pins {*u_canny/pbq[0]~FF|D *u_canny/cq[0]~FF|D *u_canny/pq[0]~FF|D *u_canny/rq[0]~FF|D *u_canny/readyq[0]~FF|D *u_canny/sm[*]~FF|D *u_canny/capture_fifo/rm[*]~FF|D *u_canny/display_fifo/wm[*]~FF|D}] 5
set_min_delay -from [get_clocks {clk_sys}] -to [get_pins {*u_canny/pbq[0]~FF|D *u_canny/cq[0]~FF|D *u_canny/pq[0]~FF|D *u_canny/rq[0]~FF|D *u_canny/readyq[0]~FF|D *u_canny/sm[*]~FF|D *u_canny/capture_fifo/rm[*]~FF|D *u_canny/display_fifo/wm[*]~FF|D}] 0
