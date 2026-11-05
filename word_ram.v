// =============================================================================
// word_ram.v
// Group 18 - Memories                      Owner: Thotakura Gowtham Vijay Kasyap
//
// Single-port synchronous RAM with byte enables and the slave-port interface
// of contract section 3.1. Used at integration for:
//   - DMEM   (32 KiB, C data and stack)       WORDS = 8192
//   - IMG_SW (64 KiB production output image) WORDS = 16384
//   - IMEM   (32 KiB, instruction port; s_we tied to 0, INIT_FILE = program)
//
// s_addr is a byte offset; the word is s_addr[ADDR_BITS-1:2].
// Never waits (s_ready = 1). Read data is registered: valid the cycle after
// the request. The array is not reset; it starts from INIT_FILE or zero.
// =============================================================================
`timescale 1ns / 1ps

module word_ram #(
    parameter WORDS     = 1024,
    parameter INIT_FILE = ""
) (
    input  wire                       clk,
    input  wire                       s_req,
    input  wire                       s_we,
    input  wire [$clog2(WORDS)+1:0]   s_addr,
    input  wire [3:0]                 s_be,
    input  wire [31:0]                s_wdata,
    output wire                       s_ready,
    output reg  [31:0]                s_rdata
);

    localparam WORD_BITS = $clog2(WORDS);

    (* ram_style = "block" *) reg [31:0] memory [0:WORDS-1];

    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            memory[i] = 32'd0;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    assign s_ready = 1'b1;

    wire [WORD_BITS-1:0] word = s_addr[WORD_BITS+1:2];

    always @(posedge clk) begin
        if (s_req) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (s_we && s_be[i])
                    memory[word][i*8 +: 8] <= s_wdata[i*8 +: 8];
            end
            s_rdata <= memory[word];
        end
    end

endmodule
