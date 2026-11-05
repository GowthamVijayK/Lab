// =============================================================================
// image_buffer.v
// Group 18 - Image memories                Owner: Thotakura Gowtham Vijay Kasyap
//
// Parameterized image buffer (default 64x64; integrated SoC uses 256x256) in Block RAM, with two ports
// (contract sections 3.1 and 5.2):
//
//   CPU port   : 32-bit words with byte enables, slave port of the
//                interconnect. s_addr is the byte offset; bits ADDR_BITS-1:2 select
//                the word. Read data is registered (one-cycle latency).
//   Pixel port : one byte per access for the accelerator. Read data is
//                valid the cycle after px_en (one-cycle latency).
//
// Storage is 2^(ADDR_BITS-2) words x 32 bits. Pixel p lives in word p/4, byte lane p%4
// (little-endian, contract 5.1). Both ports are written with byte enables,
// which matches the Xilinx true-dual-port byte-write BRAM template.
//
// Protection: while lock = 1 (accelerator BUSY) the CPU port reports
// s_ready = 0, so a CPU access waits and cannot change or read the image.
// The two ports must never write the same word in the same cycle; the lock
// guarantees this in the system.
// =============================================================================
`timescale 1ns / 1ps

module image_buffer #(
    parameter ADDR_BITS = 12,               // 12: 64x64; 16: 256x256
    parameter INIT_FILE = ""                 // hex file, one 32-bit word per line
) (
    input  wire        clk,
    input  wire        lock,

    // CPU slave port
    input  wire        s_req,
    input  wire        s_we,
    input  wire [ADDR_BITS-1:0] s_addr,
    input  wire [3:0]  s_be,
    input  wire [31:0] s_wdata,
    output wire        s_ready,
    output reg  [31:0] s_rdata,

    // Accelerator pixel port
    input  wire        px_en,
    input  wire        px_we,
    input  wire [ADDR_BITS-1:0] px_addr,
    input  wire [7:0]  px_wdata,
    output wire [7:0]  px_rdata
);

    localparam WORDS = 1 << (ADDR_BITS-2);

    (* ram_style = "block" *) reg [31:0] memory [0:WORDS-1];

    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            memory[i] = 32'd0;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    // ---- CPU port (port A) ---------------------------------------------------
    assign s_ready = !lock;

    wire       cpu_access = s_req && !lock;
    wire [ADDR_BITS-3:0] cpu_word   = s_addr[ADDR_BITS-1:2];

    always @(posedge clk) begin
        if (cpu_access) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (s_we && s_be[i])
                    memory[cpu_word][i*8 +: 8] <= s_wdata[i*8 +: 8];
            end
            s_rdata <= memory[cpu_word];      // read-first
        end
    end

    // ---- Pixel port (port B) ---------------------------------------------------
    wire [ADDR_BITS-3:0] px_word = px_addr[ADDR_BITS-1:2];
    wire [1:0] px_lane = px_addr[1:0];

    reg  [31:0] px_word_data;
    reg  [1:0]  px_lane_q;

    always @(posedge clk) begin
        if (px_en) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (px_we && (px_lane == i))
                    memory[px_word][i*8 +: 8] <= px_wdata;
            end
            px_word_data <= memory[px_word];
            px_lane_q    <= px_lane;
        end
    end

    // The byte lane is selected after the BRAM output register.
    assign px_rdata = px_word_data[px_lane_q*8 +: 8];

endmodule
