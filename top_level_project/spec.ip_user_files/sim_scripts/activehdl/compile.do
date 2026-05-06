transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib activehdl/xpm
vlib activehdl/axis_infrastructure_v1_1_1
vlib activehdl/axis_data_fifo_v2_0_17
vlib activehdl/xil_defaultlib

vmap xpm activehdl/xpm
vmap axis_infrastructure_v1_1_1 activehdl/axis_infrastructure_v1_1_1
vmap axis_data_fifo_v2_0_17 activehdl/axis_data_fifo_v2_0_17
vmap xil_defaultlib activehdl/xil_defaultlib

vlog -work xpm  -sv2k12 "+incdir+../../../../../../../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" "+incdir+../../ipstatic" "+incdir+../../ipstatic/hdl" -l xpm -l axis_infrastructure_v1_1_1 -l axis_data_fifo_v2_0_17 -l xil_defaultlib \
"C:/Xilinx/2025.1/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/Xilinx/2025.1/Vivado/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"C:/Xilinx/2025.1/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  \
"C:/Xilinx/2025.1/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work axis_infrastructure_v1_1_1  -v2k5 "+incdir+../../../../../../../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" "+incdir+../../ipstatic" "+incdir+../../ipstatic/hdl" -l xpm -l axis_infrastructure_v1_1_1 -l axis_data_fifo_v2_0_17 -l xil_defaultlib \
"../../ipstatic/hdl/axis_infrastructure_v1_1_vl_rfs.v" \

vlog -work axis_data_fifo_v2_0_17  -v2k5 "+incdir+../../../../../../../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" "+incdir+../../ipstatic" "+incdir+../../ipstatic/hdl" -l xpm -l axis_infrastructure_v1_1_1 -l axis_data_fifo_v2_0_17 -l xil_defaultlib \
"../../ipstatic/hdl/axis_data_fifo_v2_0_vl_rfs.v" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../../../../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" "+incdir+../../ipstatic" "+incdir+../../ipstatic/hdl" -l xpm -l axis_infrastructure_v1_1_1 -l axis_data_fifo_v2_0_17 -l xil_defaultlib \
"../../../spec.gen/sources_1/ip/axis_data_fifo_0/sim/axis_data_fifo_0.v" \
"../../../spec.gen/sources_1/ip/clk_wiz_0/clk_wiz_0_clk_wiz.v" \
"../../../spec.gen/sources_1/ip/clk_wiz_0/clk_wiz_0.v" \
"../../../../verilog/src/Window.v" \
"../../../../verilog/src/cic.v" \
"../../../../verilog/src/fir.v" \
"../../../../verilog/src/mic.v" \
"../../../../verilog/src/top.v" \

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../../../../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" "+incdir+../../ipstatic" "+incdir+../../ipstatic/hdl" -l xpm -l axis_infrastructure_v1_1_1 -l axis_data_fifo_v2_0_17 -l xil_defaultlib \
"../../../../verilog/sim/top_tb.sv" \

vlog -work xil_defaultlib \
"glbl.v"

