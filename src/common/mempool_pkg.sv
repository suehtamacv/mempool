// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

package mempool_pkg;

  /*************
   *  MEMPOOL  *
   *************/

  localparam BankingFactor = 4;

  /***********************
   *  MEMORY PARAMETERS  *
   ***********************/

  localparam AddrWidth  = 32            ;
  localparam DataWidth  = 32            ;
  localparam BeWidth    = DataWidth / 8 ;
  localparam ByteOffset = $clog2(BeWidth);

  localparam TCDMSizePerCore  = 16 * 1024 ; // [B]
  localparam TCDMAddrMemWidth = $clog2(TCDMSizePerCore / BankingFactor);

  typedef logic [       AddrWidth-1:0] addr_t     ;
  typedef logic [       DataWidth-1:0] data_t     ;
  typedef logic [         BeWidth-1:0] be_t       ;
  typedef logic [TCDMAddrMemWidth-1:0] tcdm_addr_t;

  /*****************
   *  ADDRESS MAP  *
   *****************/

  typedef enum logic {
    ADDRESS_TCDM
  } address_map_t;

/*localparam addr_t MemPoolAddrStart [0:0] = '{
 32'h0000_0000 // TCDM
 };

 localparam addr_t MemPoolAddrEnd [0:0] = '{
 32'h0000_0000 + TCDMSize - 1 // TCDM
 };

 localparam TCDMSeqRegionStart = MemPoolAddrStart[ADDRESS_TCDM]                               ;
 localparam TCDMSeqRegionEnd   = MemPoolAddrStart[ADDRESS_TCDM] + TCDMSize / BankingFactor - 1;
 localparam TCDMSeqRegionSize  = TCDMSize / BankingFactor                                     ;*/

endpackage : mempool_pkg
