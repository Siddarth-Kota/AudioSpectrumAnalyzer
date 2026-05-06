-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2025.1 (win64) Build 6140274 Thu May 22 00:12:29 MDT 2025
-- Date        : Tue May  5 16:58:41 2026
-- Host        : pepe running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub {c:/Users/bobph/OneDrive/Desktop/Projects/0001 - Hardware Audio
--               Spectrum Analyzer/local_debug/vivado/spec.gen/sources_1/ip/xfft_0_1/xfft_0_stub.vhdl}
-- Design      : xfft_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tcsg324-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity xfft_0 is
  Port ( 
    aclk : in STD_LOGIC;
    aresetn : in STD_LOGIC;
    s_axis_config_tdata : in STD_LOGIC_VECTOR ( 7 downto 0 );
    s_axis_config_tvalid : in STD_LOGIC;
    s_axis_config_tready : out STD_LOGIC;
    s_axis_data_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axis_data_tvalid : in STD_LOGIC;
    s_axis_data_tready : out STD_LOGIC;
    s_axis_data_tlast : in STD_LOGIC;
    m_axis_data_tdata : out STD_LOGIC_VECTOR ( 63 downto 0 );
    m_axis_data_tvalid : out STD_LOGIC;
    m_axis_data_tready : in STD_LOGIC;
    m_axis_data_tlast : out STD_LOGIC;
    event_frame_started : out STD_LOGIC;
    event_tlast_unexpected : out STD_LOGIC;
    event_tlast_missing : out STD_LOGIC;
    event_status_channel_halt : out STD_LOGIC;
    event_data_in_channel_halt : out STD_LOGIC;
    event_data_out_channel_halt : out STD_LOGIC
  );

  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of xfft_0 : entity is "xfft_0,xfft_v9_1_14,{}";
  attribute core_generation_info : string;
  attribute core_generation_info of xfft_0 : entity is "xfft_0,xfft_v9_1_14,{x_ipProduct=Vivado 2025.1,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=xfft,x_ipVersion=9.1,x_ipCoreRevision=14,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,C_XDEVICEFAMILY=artix7,C_PART=xc7a100tcsg324-1,C_S_AXIS_CONFIG_TDATA_WIDTH=8,C_S_AXIS_DATA_TDATA_WIDTH=32,C_M_AXIS_DATA_TDATA_WIDTH=64,C_M_AXIS_DATA_TUSER_WIDTH=1,C_M_AXIS_STATUS_TDATA_WIDTH=1,C_THROTTLE_SCHEME=1,C_NSSR=1,C_CHANNELS=1,C_NFFT_MAX=10,C_ARCH=3,C_HAS_NFFT=0,C_USE_FLT_PT=0,C_INPUT_WIDTH=16,C_TWIDDLE_WIDTH=16,C_OUTPUT_WIDTH=27,C_HAS_SCALING=0,C_HAS_BFP=0,C_HAS_ROUNDING=1,C_HAS_ACLKEN=0,C_HAS_ARESETN=1,C_HAS_OVFLO=0,C_HAS_NATURAL_INPUT=1,C_HAS_NATURAL_OUTPUT=1,C_HAS_CYCLIC_PREFIX=0,C_HAS_XK_INDEX=0,C_DATA_MEM_TYPE=1,C_TWIDDLE_MEM_TYPE=1,C_BRAM_STAGES=3,C_REORDER_MEM_TYPE=1,C_USE_HYBRID_RAM=0,C_OPTIMIZE_GOAL=0,C_CMPY_TYPE=1,C_BFLY_TYPE=0,C_SYSTOLICFFT_INV=0,C_IS_BLOCKING_RUNTIME_CONF=0}";
  attribute downgradeipidentifiedwarnings : string;
  attribute downgradeipidentifiedwarnings of xfft_0 : entity is "yes";
end xfft_0;

architecture stub of xfft_0 is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "aclk,aresetn,s_axis_config_tdata[7:0],s_axis_config_tvalid,s_axis_config_tready,s_axis_data_tdata[31:0],s_axis_data_tvalid,s_axis_data_tready,s_axis_data_tlast,m_axis_data_tdata[63:0],m_axis_data_tvalid,m_axis_data_tready,m_axis_data_tlast,event_frame_started,event_tlast_unexpected,event_tlast_missing,event_status_channel_halt,event_data_in_channel_halt,event_data_out_channel_halt";
  attribute x_interface_info : string;
  attribute x_interface_info of aclk : signal is "xilinx.com:signal:clock:1.0 aclk_intf CLK";
  attribute x_interface_mode : string;
  attribute x_interface_mode of aclk : signal is "slave aclk_intf";
  attribute x_interface_parameter : string;
  attribute x_interface_parameter of aclk : signal is "XIL_INTERFACENAME aclk_intf, ASSOCIATED_BUSIF S_AXIS_CONFIG:M_AXIS_DATA:M_AXIS_STATUS:S_AXIS_DATA, ASSOCIATED_RESET aresetn, ASSOCIATED_CLKEN aclken, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, INSERT_VIP 0";
  attribute x_interface_info of aresetn : signal is "xilinx.com:signal:reset:1.0 aresetn_intf RST";
  attribute x_interface_mode of aresetn : signal is "slave aresetn_intf";
  attribute x_interface_parameter of aresetn : signal is "XIL_INTERFACENAME aresetn_intf, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  attribute x_interface_info of s_axis_config_tdata : signal is "xilinx.com:interface:axis:1.0 S_AXIS_CONFIG TDATA";
  attribute x_interface_mode of s_axis_config_tdata : signal is "slave S_AXIS_CONFIG";
  attribute x_interface_parameter of s_axis_config_tdata : signal is "XIL_INTERFACENAME S_AXIS_CONFIG, TDATA_NUM_BYTES 1, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  attribute x_interface_info of s_axis_config_tvalid : signal is "xilinx.com:interface:axis:1.0 S_AXIS_CONFIG TVALID";
  attribute x_interface_info of s_axis_config_tready : signal is "xilinx.com:interface:axis:1.0 S_AXIS_CONFIG TREADY";
  attribute x_interface_info of s_axis_data_tdata : signal is "xilinx.com:interface:axis:1.0 S_AXIS_DATA TDATA";
  attribute x_interface_mode of s_axis_data_tdata : signal is "slave S_AXIS_DATA";
  attribute x_interface_parameter of s_axis_data_tdata : signal is "XIL_INTERFACENAME S_AXIS_DATA, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  attribute x_interface_info of s_axis_data_tvalid : signal is "xilinx.com:interface:axis:1.0 S_AXIS_DATA TVALID";
  attribute x_interface_info of s_axis_data_tready : signal is "xilinx.com:interface:axis:1.0 S_AXIS_DATA TREADY";
  attribute x_interface_info of s_axis_data_tlast : signal is "xilinx.com:interface:axis:1.0 S_AXIS_DATA TLAST";
  attribute x_interface_info of m_axis_data_tdata : signal is "xilinx.com:interface:axis:1.0 M_AXIS_DATA TDATA";
  attribute x_interface_mode of m_axis_data_tdata : signal is "master M_AXIS_DATA";
  attribute x_interface_parameter of m_axis_data_tdata : signal is "XIL_INTERFACENAME M_AXIS_DATA, TDATA_NUM_BYTES 8, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  attribute x_interface_info of m_axis_data_tvalid : signal is "xilinx.com:interface:axis:1.0 M_AXIS_DATA TVALID";
  attribute x_interface_info of m_axis_data_tready : signal is "xilinx.com:interface:axis:1.0 M_AXIS_DATA TREADY";
  attribute x_interface_info of m_axis_data_tlast : signal is "xilinx.com:interface:axis:1.0 M_AXIS_DATA TLAST";
  attribute x_interface_info of event_frame_started : signal is "xilinx.com:signal:interrupt:1.0 event_frame_started_intf INTERRUPT";
  attribute x_interface_mode of event_frame_started : signal is "master event_frame_started_intf";
  attribute x_interface_parameter of event_frame_started : signal is "XIL_INTERFACENAME event_frame_started_intf, SENSITIVITY EDGE_RISING, PortWidth 1";
  attribute x_interface_info of event_tlast_unexpected : signal is "xilinx.com:signal:interrupt:1.0 event_tlast_unexpected_intf INTERRUPT";
  attribute x_interface_mode of event_tlast_unexpected : signal is "master event_tlast_unexpected_intf";
  attribute x_interface_parameter of event_tlast_unexpected : signal is "XIL_INTERFACENAME event_tlast_unexpected_intf, SENSITIVITY EDGE_RISING, PortWidth 1";
  attribute x_interface_info of event_tlast_missing : signal is "xilinx.com:signal:interrupt:1.0 event_tlast_missing_intf INTERRUPT";
  attribute x_interface_mode of event_tlast_missing : signal is "master event_tlast_missing_intf";
  attribute x_interface_parameter of event_tlast_missing : signal is "XIL_INTERFACENAME event_tlast_missing_intf, SENSITIVITY EDGE_RISING, PortWidth 1";
  attribute x_interface_info of event_status_channel_halt : signal is "xilinx.com:signal:interrupt:1.0 event_status_channel_halt_intf INTERRUPT";
  attribute x_interface_mode of event_status_channel_halt : signal is "master event_status_channel_halt_intf";
  attribute x_interface_parameter of event_status_channel_halt : signal is "XIL_INTERFACENAME event_status_channel_halt_intf, SENSITIVITY EDGE_RISING, PortWidth 1";
  attribute x_interface_info of event_data_in_channel_halt : signal is "xilinx.com:signal:interrupt:1.0 event_data_in_channel_halt_intf INTERRUPT";
  attribute x_interface_mode of event_data_in_channel_halt : signal is "master event_data_in_channel_halt_intf";
  attribute x_interface_parameter of event_data_in_channel_halt : signal is "XIL_INTERFACENAME event_data_in_channel_halt_intf, SENSITIVITY EDGE_RISING, PortWidth 1";
  attribute x_interface_info of event_data_out_channel_halt : signal is "xilinx.com:signal:interrupt:1.0 event_data_out_channel_halt_intf INTERRUPT";
  attribute x_interface_mode of event_data_out_channel_halt : signal is "master event_data_out_channel_halt_intf";
  attribute x_interface_parameter of event_data_out_channel_halt : signal is "XIL_INTERFACENAME event_data_out_channel_halt_intf, SENSITIVITY EDGE_RISING, PortWidth 1";
  attribute x_core_info : string;
  attribute x_core_info of stub : architecture is "xfft_v9_1_14,Vivado 2025.1";
begin
end;
