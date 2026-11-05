// Two synchronous previous-row memories and a sliding 3x3 window.
// One valid input token per clock; valid gaps are supported, no output ready.
// The downstream arithmetic/output BRAM must accept every valid window.
// frame_start flushes control; RAM contents need no reset. Warm-up masks
// unread rows, so stale RAM from a reset/previous frame cannot reach results.
//
// Raster token t produces centre t-WIDTH-1. Shift-register values cross a
// row boundary, but such windows correspond ONLY to copied left/right
// borders; their arithmetic is discarded. Every interior window stays in
// its own three image rows. The centre byte remains correct at all borders.
// Supply PIXELS real bytes followed by WIDTH+1 zero tokens. Exactly PIXELS
// windows emerge, in increasing address order. RAM-read and window registers
// are two stages; six arithmetic registers follow in filter_datapath.
`timescale 1ns/1ps
module stream_window #(
    parameter COORD_BITS = 8
) (
    input wire clk, rst_n, frame_start,
    input wire pixel_valid,
    input wire [7:0] pixel_data,
    output reg window_valid,
    output reg [71:0] window_pixels,
    output reg window_border,
    output reg [7:0] window_center,
    output reg [2*COORD_BITS-1:0] window_addr
);
    localparam WIDTH = 1 << COORD_BITS;
    localparam PIXELS = 1 << (2*COORD_BITS);
    // Read-first row 1; row 2 writes the preceding row-1 read a clock later.
    // Separate synchronous read/write addresses permit simple dual-port RAM.
    (* ram_style = "block" *) reg [7:0] row1 [0:WIDTH-1];
    (* ram_style = "block" *) reg [7:0] row2 [0:WIDTH-1];
    reg [7:0] row1_q, row2_q;
    reg [2*COORD_BITS:0] token, token_q;
    reg valid_q;
    reg [7:0] pixel_q;
    wire accept = pixel_valid && (token < PIXELS+WIDTH+1);
    // One synchronous process per memory, with explicit read/write enables.
    // This retains read-first behavior and the existing one-edge RAM latency.
    // The RAM arrays/output registers have no asynchronous reset.
    wire row_read_en = rst_n && !frame_start && accept;
    wire row2_write_en = rst_n && !frame_start && valid_q;
    always @(posedge clk) begin
        if (row_read_en) begin
            row1_q <= row1[token[COORD_BITS-1:0]];
            row1[token[COORD_BITS-1:0]] <= pixel_data;
        end
    end
    always @(posedge clk) begin
        if (row2_write_en)
            row2[token_q[COORD_BITS-1:0]] <= row1_q;
        if (row_read_en)
            row2_q <= row2[token[COORD_BITS-1:0]];
    end
    wire [7:0] top_byte = (token_q >= 2*WIDTH) ? row2_q : 8'd0;
    wire [7:0] mid_byte = (token_q >= WIDTH) ? row1_q : 8'd0;
    reg [7:0] top_1, top_2, mid_1, mid_2, bot_1, bot_2;
    wire [2*COORD_BITS:0] centre = token_q - (WIDTH+1);
    wire [COORD_BITS-1:0] centre_row = centre[2*COORD_BITS-1:COORD_BITS];
    wire [COORD_BITS-1:0] centre_col = centre[COORD_BITS-1:0];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            token <= 0; token_q <= 0; valid_q <= 0; pixel_q <= 0;
            window_valid <= 0; window_pixels <= 0; window_border <= 0;
            window_center <= 0; window_addr <= 0;
            top_1 <= 0; top_2 <= 0; mid_1 <= 0; mid_2 <= 0; bot_1 <= 0; bot_2 <= 0;
        end else if (frame_start) begin
            token <= 0; token_q <= 0; valid_q <= 0; window_valid <= 0;
            top_1 <= 0; top_2 <= 0; mid_1 <= 0; mid_2 <= 0; bot_1 <= 0; bot_2 <= 0;
        end else begin
            valid_q <= accept;
            if (accept) begin
                token_q <= token; pixel_q <= pixel_data; token <= token + 1'b1;
            end
            window_valid <= valid_q && (token_q >= WIDTH+1) && (centre < PIXELS);
            if (valid_q) begin
                top_2 <= top_1; top_1 <= top_byte;
                mid_2 <= mid_1; mid_1 <= mid_byte;
                bot_2 <= bot_1; bot_1 <= pixel_q;
                window_pixels <= {pixel_q, bot_1, bot_2, mid_byte, mid_1, mid_2,
                                  top_byte, top_1, top_2};
                window_center <= mid_1;
                window_addr <= centre[2*COORD_BITS-1:0];
                window_border <= (centre_row == 0) || (&centre_row) ||
                                 (centre_col == 0) || (&centre_col);
            end
        end
    end
endmodule
