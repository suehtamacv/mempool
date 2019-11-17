// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module mempool_tb;

  timeunit      1ns;
  timeprecision 1ps;

  /****************
   *  LOCALPARAM  *
   ****************/

  localparam DataAddrMemWidth = 12  ;
  localparam InstAddrMemWidth = 12  ;
  localparam ClockPeriod      = 1000;

  /********************************
  *  CLOCK AND RESET GENERATION  *
  ********************************/

  logic clk  ;
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

  mempool_cluster dut (
    .clk_i         (clk  ),
    .rst_ni        (rst_n),
    .clock_en_i    (1'b1 ),
    .test_en_i     (1'b1 ),
    .scan_enable_i (1'b0 ),
    .scan_data_i   (1'b0 ),
    .scan_data_o   (     ),
    .boot_addr_i   (32'b0),
    .debug_req_i   (1'b0 ),
    .fetch_enable_i('1   ),
    .core_busy_o   (     )
  );

endmodule : mempool_tb
