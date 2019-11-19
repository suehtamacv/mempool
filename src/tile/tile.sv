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

module tile (
    // Clock and reset
    input  logic                           clk_i ,
    input  logic                           rst_ni ,
    // Clock enable
    input  logic                           clock_en_i ,
    input  logic                           test_en_i ,
    // Scan chain
    input  logic                           scan_enable_i ,
    input  logic                           scan_data_i ,
    output logic                           scan_data_o ,
    // Boot address
    input  logic       [ 31:0]             boot_addr_i ,
    // Tile ID
    input  logic       [ 9:0]              tile_id_i ,
    // Debug interface
    input  logic                           debug_req_i ,
    // Core data interface
    output logic       [BankingFactor-1:0] tcdm_master_req_o ,
    output addr_t      [BankingFactor-1:0] tcdm_master_addr_o ,
    output logic       [BankingFactor-1:0] tcdm_master_wen_o ,
    output data_t      [BankingFactor-1:0] tcdm_master_wdata_o,
    output be_t        [BankingFactor-1:0] tcdm_master_be_o ,
    input  logic       [BankingFactor-1:0] tcdm_master_gnt_i ,
    input  logic       [BankingFactor-1:0] tcdm_master_vld_i ,
    input  data_t      [BankingFactor-1:0] tcdm_master_rdata_i,
    // TCDM banks interface
    input  logic       [BankingFactor-1:0] mem_req_i ,
    input  tcdm_addr_t [BankingFactor-1:0] mem_addr_i ,
    input  logic       [BankingFactor-1:0] mem_wen_i ,
    input  data_t      [BankingFactor-1:0] mem_wdata_i ,
    input  be_t        [BankingFactor-1:0] mem_be_i ,
    output data_t      [BankingFactor-1:0] mem_rdata_o ,
    // CPU control signals
    input  logic                           fetch_enable_i ,
    output logic                           core_busy_o
  );

  /***********
   *  CORES  *
   ***********/

  // Instruction interface

  logic  core_inst_req ;
  logic  core_inst_gnt ;
  logic  core_inst_rvalid;
  addr_t core_inst_addr ;
  data_t core_inst_rdata ;

  // Data Interface
  logic  core_data_req ;
  logic  core_data_gnt ;
  logic  core_data_vld ;
  logic  core_data_wen ;
  be_t   core_data_be ;
  addr_t core_data_addr ;
  data_t core_data_wdata;
  data_t core_data_rdata;

  riscv_core riscv_core (
    .clk_i                ( clk_i            ),
    .rst_ni               ( rst_ni           ),
    .clock_en_i           ( clock_en_i       ),
    .test_en_i            ( test_en_i        ),
    .fregfile_disable_i   ( 1'b0             ),
    .boot_addr_i          ( boot_addr_i      ),
    // Extract Core and Cluster ID from the tile_id
    .core_id_i            ( tile_id_i[3:0]   ),
    .cluster_id_i         ( tile_id_i[9:4]   ),
    // Instruction interface
    .instr_req_o          ( core_inst_req    ),
    .instr_gnt_i          ( core_inst_gnt    ),
    .instr_rvalid_i       ( core_inst_rvalid ),
    .instr_addr_o         ( core_inst_addr   ),
    .instr_rdata_i        ( core_inst_rdata  ),
    // Data interface
    .data_req_o           ( core_data_req    ),
    .data_gnt_i           ( core_data_gnt    ),
    .data_rvalid_i        ( core_data_vld    ),
    .data_we_o            ( core_data_wen    ),
    .data_be_o            ( core_data_be     ),
    .data_addr_o          ( core_data_addr   ),
    .data_wdata_o         ( core_data_wdata  ),
    .data_rdata_i         ( core_data_rdata  ),
    // APU Interface
    // Currently tied to zero
    .apu_master_req_o     (                  ),
    .apu_master_ready_o   (                  ),
    .apu_master_gnt_i     ( '0               ),
    .apu_master_operands_o(                  ),
    .apu_master_op_o      (                  ),
    .apu_master_type_o    (                  ),
    .apu_master_flags_o   (                  ),
    .apu_master_valid_i   ( '0               ),
    .apu_master_result_i  ( '0               ),
    .apu_master_flags_i   ( '0               ),
    // Interruptions
    // Currently tied to zero
    .irq_i                ( '0               ),
    .irq_id_i             ( '0               ),
    .irq_ack_o            (                  ),
    .irq_id_o             (                  ),
    .irq_sec_i            ( '0               ),
    .sec_lvl_o            (                  ),
    // Debug interface
    .debug_req_i          ( debug_req_i      ),
    // CPU control signals
    .fetch_enable_i       ( fetch_enable_i   ),
    .core_busy_o          ( core_busy_o      ),
    .ext_perf_counters_i  ( '0               )
  );

  /***************************
   *  INSTRUCTION INTERFACE  *
   ***************************/

  // NOTE:
  // For now, each core has its private instruction bank,
  // which is initialized by the testbench at #0.

  // Always ready
  assign core_inst_gnt = core_inst_req;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      core_inst_rvalid <= 1'b0;
    end else begin
      core_inst_rvalid <= core_inst_gnt;
    end
  end

  // TODO: Reusing TCDM Address Width
  sram #(
    .DATA_WIDTH(DataWidth                    ),
    .NUM_WORDS (2**TCDMAddrMemWidth / BeWidth)
  ) inst_bank (
    .clk_i  (clk_i                                        ),
    .req_i  (core_inst_req                                ),
    .we_i   (1'b0                                         ),
    .addr_i (core_inst_addr[TCDMAddrMemWidth-1:ByteOffset]),
    .wdata_i('0                                           ),
    .be_i   ('0                                           ),
    .rdata_o(core_inst_rdata                              )
  );

  /**********
   *  TCDM  *
   **********/

  // Master interface

  logic [BankingFactor-1:0] tcdm_master_req;
  logic [BankingFactor-1:0] tcdm_master_gnt;

  always_comb begin: core_mux
    // Multiplex request depending on the address of the request
    automatic int unsigned bank = BankingFactor == 1 ? 0 : core_data_addr[ByteOffset +: $clog2(BankingFactor)];
    tcdm_master_req             = '0;
    tcdm_master_req[bank]       = core_data_req;

    // Or-reduce the grants
    core_data_gnt               = |tcdm_master_gnt;
  end

  generate
    for (genvar b = 0; b < BankingFactor; b++) begin: gen_spill_registers

      // Cut the requests to outside the tile
      spill_register #(logic[$bits(addr_t)+1+$bits(be_t)+$bits(data_t)-1:0]) i_spill_register (
        .clk_i  (clk_i                                                                                     ),
        .rst_ni (rst_ni                                                                                    ),
        .valid_i(tcdm_master_req[b]                                                                        ),
        .ready_o(tcdm_master_gnt[b]                                                                        ),
        .data_i ({core_data_addr, core_data_wen, core_data_be, core_data_wdata}                            ),
        .valid_o(tcdm_master_req_o[b]                                                                      ),
        .ready_i(tcdm_master_gnt_i[b]                                                                      ),
        .data_o ({tcdm_master_addr_o[b], tcdm_master_wen_o[b], tcdm_master_be_o[b], tcdm_master_wdata_o[b]})
      );

    end
  endgenerate

  rr_arb_tree #(
    .NumIn   (BankingFactor),
    .DataType(data_t       )
  ) i_tcdm_master_arb_tree (
    .clk_i  (clk_i              ),
    .rst_ni (rst_ni             ),
    .flush_i(1'b0               ),
    .rr_i   ('0                 ),
    .req_i  (tcdm_master_vld_i  ),
    .gnt_o  (/* UNUSED */       ),
    .data_i (tcdm_master_rdata_i),
    .req_o  (core_data_vld      ),
    .gnt_i  (1'b1               ),
    .data_o (core_data_rdata    ),
    .idx_o  (/* UNUSED */       )
  );

  // Slave interface

  generate
    for (genvar bank = 0; bank < unsigned'(BankingFactor); bank++) begin: gen_banks

      data_t mem_be_int;
      for (genvar be_byte = 0; be_byte < BeWidth; be_byte++) begin: gen_mem_be
        assign mem_be_int[8*be_byte+:8] = {8{mem_be_i[bank][be_byte]}};
      end : gen_mem_be

      sram #(
        .DATA_WIDTH(DataWidth                    ),
        .NUM_WORDS (2**TCDMAddrMemWidth / BeWidth)
      ) mem_bank (
        .clk_i  (clk_i                                          ) ,
        .req_i  (mem_req_i[bank]                                ),
        .we_i   (mem_wen_i[bank]                                ),
        .addr_i (mem_addr_i[bank][TCDMAddrMemWidth-1:ByteOffset]),
        .wdata_i(mem_wdata_i[bank]                              ),
        .be_i   (mem_be_int                                     ),
        .rdata_o(mem_rdata_o[bank]                              )
      );

    end : gen_banks
  endgenerate

endmodule : tile
