// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

import mempool_pkg::*;

module tile_xbar (
  // Clock and reset
  input  logic                           clk_i              ,
  input  logic                           rst_ni             ,
  // Tile ID
  input  logic       [              9:0] tile_id_i          ,
  // Core data interface from the tile
  input  logic                           core_data_req_i    ,
  input  addr_t                          core_data_addr_i   ,
  input  logic                           core_data_wen_i    ,
  input  data_t                          core_data_wdata_i  ,
  input  be_t                            core_data_be_i     ,
  output logic                           core_data_gnt_o    ,
  output logic                           core_data_vld_o    ,
  output data_t                          core_data_rdata_o  ,
  // TCDM banks interface to the tile
  output logic       [BankingFactor-1:0] mem_req_o          ,
  output tcdm_addr_t [BankingFactor-1:0] mem_addr_o         ,
  output logic       [BankingFactor-1:0] mem_wen_o          ,
  output data_t      [BankingFactor-1:0] mem_wdata_o        ,
  output be_t        [BankingFactor-1:0] mem_be_o           ,
  input  data_t      [BankingFactor-1:0] mem_rdata_i        ,
  // TCDM Interconnect master interface
  output logic       [BankingFactor-1:0] tcdm_master_req_o  ,
  output addr_t      [BankingFactor-1:0] tcdm_master_addr_o ,
  output logic       [BankingFactor-1:0] tcdm_master_wen_o  ,
  output data_t      [BankingFactor-1:0] tcdm_master_wdata_o,
  output be_t        [BankingFactor-1:0] tcdm_master_be_o   ,
  input  logic       [BankingFactor-1:0] tcdm_master_gnt_i  ,
  input  logic       [BankingFactor-1:0] tcdm_master_vld_i  ,
  input  data_t      [BankingFactor-1:0] tcdm_master_rdata_i,
  // Interface with the TCDM interconnect
  input  logic       [BankingFactor-1:0] tcdm_slave_req_i   ,
  input  tcdm_addr_t [BankingFactor-1:0] tcdm_slave_addr_i  ,
  input  logic       [BankingFactor-1:0] tcdm_slave_wen_i   ,
  input  data_t      [BankingFactor-1:0] tcdm_slave_wdata_i ,
  input  be_t        [BankingFactor-1:0] tcdm_slave_be_i    ,
  output logic       [BankingFactor-1:0] tcdm_slave_gnt_o   ,
  output data_t      [BankingFactor-1:0] tcdm_slave_rdata_o
);

  /*******************
   *  CORE DATA MUX  *
   *******************/

  always_comb begin: core_mux
    // Default values
    core_data_gnt_o     = |tcdm_master_gnt_i;

    tcdm_master_req_o   = '0;
    tcdm_master_addr_o  = '0;
    tcdm_master_wen_o   = '0;
    tcdm_master_wdata_o = '0;
    tcdm_master_be_o    = '0;

    // TODO: Would check here if the address is in the sequential region
    // Check if the bank IDs correspond to the tile ID

    // Generate a TCDM request
    begin
    // Decide which master port will receive the request
      automatic int bank = BankingFactor == 1 ? 0 : core_data_addr_i[ByteOffset +: $clog2(BankingFactor)];
      tcdm_master_req_o[bank] = core_data_req_i;

      tcdm_master_addr_o  = {BankingFactor{core_data_addr_i}};
      tcdm_master_wen_o   = {BankingFactor{core_data_wen_i}};
      tcdm_master_wdata_o = {BankingFactor{core_data_wdata_i}};
      tcdm_master_be_o    = {BankingFactor{core_data_be_i}};
    end
  end : core_mux

  // Demux TCDM responses

  rr_arb_tree #(
    .NumIn   (BankingFactor),
    .ExtPrio (1'b1         ),
    .DataType(data_t       )
  ) i_tcdm_master_arb_tree (
    .clk_i                       ,
    .rst_ni                      ,
    .flush_i(1'b0               ),
    .rr_i   ('0                 ),
    .req_i  (tcdm_master_vld_i  ),
    .gnt_o  (/* UNUSED */       ),
    .data_i (tcdm_master_rdata_i),
    .req_o  (core_data_vld_o    ),
    .gnt_i  (1'b1               ),
    .data_o (core_data_rdata_o  ),
    .idx_o  (/* UNUSED */       )
  );

  // pragma translate_off
  assume property (@(posedge clk_i) $onehot0(tcdm_master_vld_i))
    else $fatal(1, "[TILE] Race condition. RI5CY core received more than one simultaneous RVALID.");

  assume property (@(posedge clk_i) $onehot0(tcdm_master_gnt_i))
    else $fatal(1, "[TILE] Race condition. RI5CY core received more than one simultaneous GNT.");
  // pragma translate_on

  /***************
   *  TCDM XBAR  *
   ***************/

  addr_t [BankingFactor-1:0] tcdm_slave_int_addr;
  generate
    for (genvar bank = 0; bank < BankingFactor; bank++) begin: gen_tcdm_slave_int_addr
      assign tcdm_slave_int_addr[bank] = tcdm_slave_addr_i[bank] << ByteOffset;
    end
  endgenerate

  // Connect ports directly
  assign mem_req_o          = tcdm_slave_req_i;
  assign mem_addr_o         = tcdm_slave_int_addr;
  assign mem_wen_o          = tcdm_slave_wen_i;
  assign mem_wdata_o        = tcdm_slave_wdata_i;
  assign mem_be_o           = tcdm_slave_be_i;
  assign tcdm_slave_rdata_o = mem_rdata_i;
  assign tcdm_slave_gnt_o   = tcdm_slave_req_i;

endmodule : tile_xbar
