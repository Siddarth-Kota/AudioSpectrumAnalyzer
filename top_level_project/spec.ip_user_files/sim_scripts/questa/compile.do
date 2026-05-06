vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xpm
vlib questa_lib/msim/axis_infrastructure_v1_1_1
vlib questa_lib/msim/axis_data_fifo_v2_0_17
vlib questa_lib/msim/xil_defaultlib

vmap xpm questa_lib/msim/xpm
vmap axis_infrastructure_v1_1_1 questa_lib/msim/axis_infrastructure_v1_1_1
vmap axis_data_fifo_v2_0_17 questa_lib/msim/axis_data_fifo_v2_0_17
vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vlog -work xpm  -incr -mfcu  -sv "+incdir+../../../../../../../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" "+incdir+../../ipstatic" "+incdir+../../ipstatic/hdl" \
"C:/Xilinx/2025.1/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/Xilinx/2025.1/Vivado/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"C:/Xilinx/2025.1/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm  -93  \
"C:/Xilinx/2025.1/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work axis_infrastructure_v1_1_1  -incr -mfcu  "+incdir+../../../../../../../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" "+incdir+../../ipstatic" "+incdir+../../ipstatic/hdl" \
"../../ipstatic/hdl/axis_infrastructure_v1_1_vl_rfs.v" \

vlog -work axis_data_fifo_v2_0_17  -incr -mfcu  "+incdir+../../../../../../../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" "+incdir+../../ipstatic" "+incdir+../../ipstatic/hdl" \
"../../ipstatic/hdl/axis_data_fifo_v2_0_vl_rfs.v" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../../../../../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" "+incdir+../../ipstatic" "+incdir+../../ipstatic/hdl" \
"../../../spec.gen/sources_1/ip/axis_data_fifo_0/sim/axis_data_fifo_0.v" \
"../../../spec.gen/sources_1/ip/clk_wiz_0/clk_wiz_0_clk_wiz.v" \
"../../../spec.gen/sources_1/ip/clk_wiz_0/clk_wiz_0.v" \
"../../../../verilog/src/Window.v" \
"../../../../verilog/src/cic.v" \
"../../../../verilog/src/fir.v" \
"../../../../verilog/src/mic.v" \
"../../../../verilog/src/top.v" \

vlog -work xil_defaultlib  -incr -mfcu  -sv "+incdir+../../../../../../../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" "+incdir+../../ipstatic" "+incdir+../../ipstatic/hdl" \
"../../../../verilog/sim/top_tb.sv" \

vlog -work xil_defaultlib \
"glbl.v"

