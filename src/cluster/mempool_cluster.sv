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

module mempool_cluster #(
    parameter int NumTiles = 256
  ) (
    // Clock and reset
    input  logic                clk_i ,
    input  logic                rst_ni ,
    // Clock enable
    input  logic                clock_en_i ,
    input  logic                test_en_i ,
    // Scan chain
    input  logic                scan_enable_i ,
    input  logic                scan_data_i ,
    output logic                scan_data_o ,
    // Boot address
    input  logic [ 31:0]        boot_addr_i ,
    // Debug interface
    input  logic                debug_req_i ,
    // CPU control signals
    input  logic [NumTiles-1:0] fetch_enable_i,
    output logic [NumTiles-1:0] core_busy_o
  );

  /***********
   *  TILES  *
   ***********/

  // Data interface

  logic  [NumTiles-1:0][BankingFactor-1:0] tcdm_master_req ;
  logic  [NumTiles-1:0][BankingFactor-1:0] tcdm_master_gnt ;
  logic  [NumTiles-1:0][BankingFactor-1:0] tcdm_master_rvalid;
  addr_t [NumTiles-1:0][BankingFactor-1:0] tcdm_master_addr ;
  data_t [NumTiles-1:0][BankingFactor-1:0] tcdm_master_rdata ;
  logic  [NumTiles-1:0][BankingFactor-1:0] tcdm_master_wen ;
  data_t [NumTiles-1:0][BankingFactor-1:0] tcdm_master_wdata ;
  be_t   [NumTiles-1:0][BankingFactor-1:0] tcdm_master_be ;

  logic       [NumTiles-1:0][BankingFactor-1:0] tcdm_slave_req ;
  logic       [NumTiles-1:0][BankingFactor-1:0] tcdm_slave_gnt ;
  tcdm_addr_t [NumTiles-1:0][BankingFactor-1:0] tcdm_slave_addr ;
  data_t      [NumTiles-1:0][BankingFactor-1:0] tcdm_slave_rdata ;
  logic       [NumTiles-1:0][BankingFactor-1:0] tcdm_slave_wen ;
  data_t      [NumTiles-1:0][BankingFactor-1:0] tcdm_slave_wdata ;
  be_t        [NumTiles-1:0][BankingFactor-1:0] tcdm_slave_be ;

  for (genvar t = 0; unsigned'(t) < NumTiles; t++) begin: gen_tiles

    logic core_data_req   ;
    addr_t core_data_addr ;
    logic core_data_wen   ;
    data_t core_data_wdata;
    be_t core_data_be     ;
    logic core_data_gnt   ;
    logic core_data_vld   ;
    data_t core_data_rdata;

    logic       [BankingFactor-1:0] mem_req   ;
    tcdm_addr_t [BankingFactor-1:0] mem_addr  ;
    logic       [BankingFactor-1:0] mem_wen   ;
    data_t      [BankingFactor-1:0] mem_wdata ;
    be_t        [BankingFactor-1:0] mem_be    ;
    data_t      [BankingFactor-1:0] mem_rdata ;
    logic       [BankingFactor-1:0] mem_vld   ;

    tile tile (
      .clk_i            ( clk_i            ),
      .rst_ni           ( rst_ni           ),
      .clock_en_i       ( clock_en_i       ),
      .test_en_i        ( test_en_i        ),
      .boot_addr_i      ( boot_addr_i      ),
      .scan_enable_i    ( 1'b0             ),
      .scan_data_i      ( 1'b0             ),
      .scan_data_o      (                  ),
      // Extract Tile ID from the genvar
      .tile_id_i        ( t[9:0]           ),
      // Core data interface
      .core_data_req_o  ( core_data_req    ),
      .core_data_addr_o ( core_data_addr   ),
      .core_data_wen_o  ( core_data_wen    ),
      .core_data_wdata_o( core_data_wdata  ),
      .core_data_be_o   ( core_data_be     ),
      .core_data_gnt_i  ( core_data_gnt    ),
      .core_data_vld_i  ( core_data_vld    ),
      .core_data_rdata_i( core_data_rdata  ),
      // TCDM banks interface
      .mem_req_i        ( mem_req          ),
      .mem_addr_i       ( mem_addr         ),
      .mem_wen_i        ( mem_wen          ),
      .mem_wdata_i      ( mem_wdata        ),
      .mem_be_i         ( mem_be           ),
      .mem_rdata_o      ( mem_rdata        ),
      .mem_vld_o        ( mem_vld          ),
      // Debug interface
      .debug_req_i      ( debug_req_i      ),
      // CPU control signals
      .fetch_enable_i   ( fetch_enable_i[t]),
      .core_busy_o      ( core_busy_o[t]   )
    );

    tile_xbar local_xbar (
      .clk_i              (clk_i                ),
      .rst_ni             (rst_ni               ),
      // Core data interface
      .core_data_req_i    (core_data_req        ),
      .core_data_addr_i   (core_data_addr       ),
      .core_data_wen_i    (core_data_wen        ),
      .core_data_wdata_i  (core_data_wdata      ),
      .core_data_be_i     (core_data_be         ),
      .core_data_gnt_o    (core_data_gnt        ),
      .core_data_vld_o    (core_data_vld        ),
      .core_data_rdata_o  (core_data_rdata      ),
      // TCDM banks interface
      .mem_req_o          (mem_req              ),
      .mem_addr_o         (mem_addr             ),
      .mem_wen_o          (mem_wen              ),
      .mem_wdata_o        (mem_wdata            ),
      .mem_be_o           (mem_be               ),
      .mem_rdata_i        (mem_rdata            ),
      // TCDM Interconnect master interface
      .tcdm_master_req_o  (tcdm_master_req[t]   ),
      .tcdm_master_addr_o (tcdm_master_addr[t]  ),
      .tcdm_master_wen_o  (tcdm_master_wen[t]   ),
      .tcdm_master_wdata_o(tcdm_master_wdata[t] ),
      .tcdm_master_be_o   (tcdm_master_be[t]    ),
      .tcdm_master_gnt_i  (tcdm_master_gnt[t]   ),
      .tcdm_master_vld_i  (tcdm_master_rvalid[t]),
      .tcdm_master_rdata_i(tcdm_master_rdata[t] ),
      // Interface with the TCDM interconnect
      .tcdm_slave_req_i   (tcdm_slave_req[t]    ),
      .tcdm_slave_addr_i  (tcdm_slave_addr[t]   ),
      .tcdm_slave_wen_i   (tcdm_slave_wen[t]    ),
      .tcdm_slave_wdata_i (tcdm_slave_wdata[t]  ),
      .tcdm_slave_be_i    (tcdm_slave_be[t]     ),
      .tcdm_slave_gnt_o   (tcdm_slave_gnt[t]    ),
      .tcdm_slave_rdata_o (tcdm_slave_rdata[t]  )
    );

  end : gen_tiles

  /***********************
   *  TCDM INTERCONNECT  *
   ***********************/

  logic  [BankingFactor-1:0][NumTiles-1:0] tcdm_master_int_req ;
  logic  [BankingFactor-1:0][NumTiles-1:0] tcdm_master_int_gnt ;
  logic  [BankingFactor-1:0][NumTiles-1:0] tcdm_master_int_rvalid;
  addr_t [BankingFactor-1:0][NumTiles-1:0] tcdm_master_int_addr ;
  data_t [BankingFactor-1:0][NumTiles-1:0] tcdm_master_int_rdata ;
  logic  [BankingFactor-1:0][NumTiles-1:0] tcdm_master_int_wen ;
  data_t [BankingFactor-1:0][NumTiles-1:0] tcdm_master_int_wdata ;
  be_t   [BankingFactor-1:0][NumTiles-1:0] tcdm_master_int_be ;

  logic       [BankingFactor-1:0][NumTiles-1:0] tcdm_slave_int_req ;
  logic       [BankingFactor-1:0][NumTiles-1:0] tcdm_slave_int_gnt ;
  tcdm_addr_t [BankingFactor-1:0][NumTiles-1:0] tcdm_slave_int_addr ;
  data_t      [BankingFactor-1:0][NumTiles-1:0] tcdm_slave_int_rdata ;
  logic       [BankingFactor-1:0][NumTiles-1:0] tcdm_slave_int_wen ;
  data_t      [BankingFactor-1:0][NumTiles-1:0] tcdm_slave_int_wdata ;
  be_t        [BankingFactor-1:0][NumTiles-1:0] tcdm_slave_int_be ;

  // Transpose requests
  always_comb begin
    for (int t = 0; t < NumTiles; t++) begin
      for (int b = 0; b < BankingFactor; b++) begin
        // Master ports
        tcdm_master_int_req  [b][t] = tcdm_master_req       [t][b];
        tcdm_master_gnt      [t][b] = tcdm_master_int_gnt   [b][t];
        tcdm_master_rvalid   [t][b] = tcdm_master_int_rvalid[b][t];
        tcdm_master_int_addr [b][t] = tcdm_master_addr      [t][b];
        tcdm_master_rdata    [t][b] = tcdm_master_int_rdata [b][t];
        tcdm_master_int_wen  [b][t] = tcdm_master_wen       [t][b];
        tcdm_master_int_wdata[b][t] = tcdm_master_wdata     [t][b];
        tcdm_master_int_be   [b][t] = tcdm_master_be        [t][b];

        // Slave ports
        tcdm_slave_req      [t][b] = tcdm_slave_int_req  [b][t];
        tcdm_slave_int_gnt  [b][t] = tcdm_slave_gnt      [t][b];
        tcdm_slave_addr     [t][b] = tcdm_slave_int_addr [b][t];
        tcdm_slave_int_rdata[b][t] = tcdm_slave_rdata    [t][b];
        tcdm_slave_wen      [t][b] = tcdm_slave_int_wen  [b][t];
        tcdm_slave_wdata    [t][b] = tcdm_slave_int_wdata[b][t];
        tcdm_slave_be       [t][b] = tcdm_slave_int_be   [b][t];
      end
    end
  end

  generate
    for (genvar b = 0; b < BankingFactor; b++) begin: gen_intercos

      // Interconnect
      tcdm_interconnect #(
        .NumIn       (NumTiles                    ),
        .NumOut      (NumTiles                    ),
        .AddrWidth   (AddrWidth                   ),
        .DataWidth   (DataWidth                   ),
        .AddrMemWidth(TCDMAddrMemWidth            ),
        .NumPar      (1                           ),
        .WriteRespOn (1'b0                        ),
        .Topology    (tcdm_interconnect_pkg::BFLY4)
      ) interco (
        .clk_i  (clk_i                    ),
        .rst_ni (rst_ni                   ),
        .req_i  (tcdm_master_int_req[b]   ),
        .add_i  (tcdm_master_int_addr[b]  ),
        .wen_i  (tcdm_master_int_wen[b]   ),
        .wdata_i(tcdm_master_int_wdata[b] ),
        .be_i   (tcdm_master_int_be[b]    ),
        .gnt_o  (tcdm_master_int_gnt[b]   ),
        .vld_o  (tcdm_master_int_rvalid[b]),
        .rdata_o(tcdm_master_int_rdata[b] ),
        .req_o  (tcdm_slave_int_req[b]    ),
        .gnt_i  (tcdm_slave_int_gnt[b]    ),
        .add_o  (tcdm_slave_int_addr[b]   ),
        .wen_o  (tcdm_slave_int_wen[b]    ),
        .wdata_o(tcdm_slave_int_wdata[b]  ),
        .be_o   (tcdm_slave_int_be[b]     ),
        .rdata_i(tcdm_slave_int_rdata[b]  )
      );

    end : gen_intercos
  endgenerate

  /****************
   *  ASSERTIONS  *
   ****************/
  
  // pragma translate_off
  initial begin
    core_cnt: assert (NumTiles <= 1024) else
      $fatal(1, "MemPool is currently limited to 1024 cores.");
  end
  // pragma translate_on
  
endmodule : mempool_cluster
