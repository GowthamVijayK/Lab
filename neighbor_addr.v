// Legacy neighborhood-address primitive retained for regression/reuse.
// The production streaming controller reads sequential addresses instead.
// =============================================================================
// neighbor_addr.v
// Group 18 - Pixel addressing              Owner: Thotakura Gowtham Vijay Kasyap
//
// For the pixel at (row, col) of a 2^COORD_BITS square image:
//   is_border : row or column is 0 or 2^COORD_BITS-1 (contract 5.1)
//   addr      : pixel index of window tap 0..8
//
//      tap 0 (r-1,c-1)  tap 1 (r-1,c)  tap 2 (r-1,c+1)
//      tap 3 (r,  c-1)  tap 4 (r,  c)  tap 5 (r,  c+1)
//      tap 6 (r+1,c-1)  tap 7 (r+1,c)  tap 8 (r+1,c+1)
//
// The index is {row', col'} (COORD_BITS + COORD_BITS bits).
// For border pixels the neighbours are outside the image; the controller
// never uses them (it copies the pixel instead). Combinational.
// =============================================================================
`timescale 1ns / 1ps

module neighbor_addr #(
    parameter COORD_BITS = 6
) (
    input  wire [COORD_BITS-1:0]  row,
    input  wire [COORD_BITS-1:0]  col,
    input  wire [3:0]  tap,
    output wire        is_border,
    output wire [2*COORD_BITS-1:0] addr
);

    assign is_border = (row == {COORD_BITS{1'b0}}) || (row == {COORD_BITS{1'b1}}) ||
                       (col == {COORD_BITS{1'b0}}) || (col == {COORD_BITS{1'b1}});

    // Row offset -1, 0, +1 for taps 0-2, 3-5, 6-8.
    reg [COORD_BITS-1:0] tap_row;
    // Column offset -1, 0, +1 for taps 0/3/6, 1/4/7, 2/5/8.
    reg [COORD_BITS-1:0] tap_col;

    always @* begin
        case (tap)
            4'd0, 4'd1, 4'd2: tap_row = row - 1'b1;
            4'd6, 4'd7, 4'd8: tap_row = row + 1'b1;
            default:          tap_row = row;
        endcase

        case (tap)
            4'd0, 4'd3, 4'd6: tap_col = col - 1'b1;
            4'd2, 4'd5, 4'd8: tap_col = col + 1'b1;
            default:          tap_col = col;
        endcase
    end

    assign addr = {tap_row, tap_col};

endmodule
