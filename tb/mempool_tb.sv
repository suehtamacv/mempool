// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

import uvm_pkg::*;
import mempool_pkg::*;

`include "uvm_macros.svh"

import "DPI-C" function void read_elf            (input string filename)                      ;
import "DPI-C" function byte get_section         (output longint address, output longint len) ;
import "DPI-C" context function byte read_section(input longint address, inout byte buffer[]) ;

module mempool_tb;

  timeunit      1ns;
  timeprecision 1ps;

  /****************
   *  LOCALPARAM  *
   ****************/

  localparam ClockPeriod = 1000;
  localparam NumTiles    = 256;

  static uvm_cmdline_processor uvcl = uvm_cmdline_processor::get_inst();

  /********************************
   *  CLOCK AND RESET GENERATION  *
   ********************************/

  logic clk ;
  logic rst_n;

  // Toggling the clock
  always #(ClockPeriod/2) clk = !clk;

  // Controlling the reset
  initial begin
    clk   = 1'b0;
    rst_n = 1'b0;

    repeat (5)
      #(ClockPeriod);

    rst_n = 1'b1;
  end

  /*********
   *  DUT  *
   *********/

  logic [NumTiles-1:0] fetch_enable;

  mempool_cluster #(
    .NumTiles(NumTiles)
  ) dut (
    .clk_i         ( clk           ),
    .rst_ni        ( rst_n         ),
    .clock_en_i    ( 1'b1          ),
    .test_en_i     ( 1'b1          ),
    .scan_enable_i ( 1'b0          ),
    .scan_data_i   ( 1'b0          ),
    .scan_data_o   (               ),
    .boot_addr_i   ( 32'h8000_0000 ),
    .debug_req_i   ( 1'b0          ),
    .fetch_enable_i( fetch_enable  ),
    .core_busy_o   (               )
  );

  /***************************
   *  MEMORY INITIALIZATION  *
   ***************************/

  generate
    logic [NumTiles:0] trigger_mem_init = 1'b1;

    for (genvar t = 0; t < NumTiles; t++) begin: gen_mem_init
      initial begin: mem_init
        // Deactivate fetch enable
        fetch_enable[t] = '0;
        wait(rst_n);

        // Synch memory initialization
        wait(trigger_mem_init[t]);

        // Initialize memories
        begin
          automatic logic [3:0][7:0] mem_row;
          byte buffer     [   ];
          longint address, length;
          string binary;

          void'(uvcl.get_arg_value("+PRELOAD=", binary));
          if (binary != "") begin

            // Read ELF
            `uvm_info("Core Test", $sformatf("Reading ELF: %s", binary), UVM_LOW);
            void'(read_elf(binary));

            while (get_section(address, length)) begin
              // Read sections
              automatic int nwords = (length + 3)/4;

              `uvm_info("Core Test", $sformatf("Loading address %x, length %x", address, length), UVM_LOW);

              buffer = new[nwords * 4];
              void'(read_section(address, buffer));

              // Initializing memories
              for (int w = 0; w < nwords; w++) begin
                mem_row = '0;
                for (int b = 0; b < 4; b++)
                  mem_row[b] = buffer[w * 4 + b];

                dut.gen_tiles[t].tile.inst_bank.ram[tcdm_addr_t'((address >> 2) + w)] = mem_row;
              end
            end
          end
        end

        // Trigger another initialization
        trigger_mem_init[t+1] = 1'b1;

        // Reactivate fetch enable
        fetch_enable[t] = '1;
      end
    end
  endgenerate

endmodule : mempool_tb
